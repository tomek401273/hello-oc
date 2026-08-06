# hello-logic

Przykładowa aplikacja Spring Boot. Endpoint `GET /` zwraca:

```
hello logic, logic, logic!
```

## Uruchomienie lokalne

```bash
mvn spring-boot:run
curl http://localhost:8080/
```

## Wdrożenie na OpenShift

Zaloguj się i utwórz projekt:

```bash
oc login <adres-klastra>
oc new-project hello-logic
```

### Sposób 1 (najprostszy): S2I — OpenShift buduje sam z kodu źródłowego

Nie wymaga Dockerfile ani lokalnego Dockera. Z katalogu projektu:

```bash
oc new-build java:openjdk-17-ubi8 --name=hello-logic --binary
oc start-build hello-logic --from-dir=. --follow
oc new-app hello-logic
oc create route edge --service=hello-logic
```

### Sposób 2: build z Dockerfile na klastrze

```bash
oc new-build --binary --name=hello-logic --strategy=docker
oc start-build hello-logic --from-dir=. --follow
oc apply -f openshift/deployment.yaml
```

### Sposób 3: build lokalny (podman/docker) + push do rejestru

```bash
podman build -t <rejestr>/<namespace>/hello-logic:latest .
podman push <rejestr>/<namespace>/hello-logic:latest
# podmień pole image w openshift/deployment.yaml na powyższy adres
oc apply -f openshift/deployment.yaml
```

## Test po wdrożeniu

```bash
curl https://$(oc get route hello-logic -o jsonpath='{.spec.host}')/
# -> hello logic, logic, logic!
```

## Health checks

Aplikacja wystawia sondy dla OpenShift (skonfigurowane w `openshift/deployment.yaml`):

- liveness: `/actuator/health/liveness`
- readiness: `/actuator/health/readiness`
# hello-oc
