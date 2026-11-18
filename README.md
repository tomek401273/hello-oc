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

Zaloguj się (polecenie z tokenem: konsola → nazwa użytkownika → **Copy login command**):

```bash
oc login --token=<token> --server=<adres-api-klastra>
oc project -q   # aktualny projekt (namespace)
```

Manifest `openshift/deployment.yaml` jest ustawiony na namespace Developer Sandbox
`tomek371240-dev`. W Sandbox nie można tworzyć nowych projektów — wdrażasz do
istniejącego `<użytkownik>-dev`. Na własnym klastrze możesz utworzyć projekt
(`oc new-project hello-logic`), ale wtedy podmień namespace w polu `image`
w `openshift/deployment.yaml`.

### Sposób 1 (najprostszy): S2I — OpenShift buduje sam z kodu źródłowego

Nie wymaga Dockerfile ani lokalnego Dockera. Z katalogu projektu:

```bash
oc new-build java:openjdk-17-ubi8 --name=hello-logic --binary
oc start-build hello-logic --from-dir=. --follow
oc new-app hello-logic
oc create route edge --service=hello-logic
```

### Sposób 2 (zalecany): build z Dockerfile na klastrze

```bash
oc new-build --binary --name=hello-logic --strategy=docker   # tylko za pierwszym razem
oc start-build hello-logic --from-dir=. --follow
oc apply -f openshift/deployment.yaml
oc rollout status deployment/hello-logic
```

Po zmianie kodu:

```bash
oc start-build hello-logic --from-dir=. --follow
oc rollout restart deployment/hello-logic
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

## Przydatne polecenia

```bash
oc get pods                        # stan podów
oc logs -f deployment/hello-logic  # logi aplikacji
oc delete all -l app=hello-logic   # usunięcie Deployment/Service/Route
oc delete all -l build=hello-logic # usunięcie BuildConfig/ImageStream
```
