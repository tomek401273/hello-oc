# Historia rozmowy: wdrożenie hello-logic na OpenShift

Eksport rozmowy z Claude Code (2026-11-18). Polecenia uruchamiane przez asystenta
podano w skrócie, razem z najważniejszymi wynikami.

---

## 1. Jak zainstalować `oc`

**Pytanie:** jak zainstalować oc command

**Odpowiedź:**

Na Linuksie najprościej pobrać gotową binarkę z serwera mirror OpenShift:

```bash
# 1. Pobierz archiwum (x86_64)
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz

# 2. Rozpakuj
tar -xzf openshift-client-linux.tar.gz

# 3. Przenieś do katalogu z PATH (tam trafia też kubectl)
sudo mv oc kubectl /usr/local/bin/

# 4. Sprawdź, czy działa
oc version --client
```

Uwagi:
- **Inna architektura:** na ARM pobierz `openshift-client-linux-arm64.tar.gz` (architekturę sprawdzisz przez `uname -m`).
- **Konkretna wersja:** zamień `stable` w adresie na np. `stable-4.16`. Najlepiej, żeby wersja klienta zgadzała się z wersją klastra.
- **Bez sudo:** wrzuć binarkę do `~/.local/bin` i upewnij się, że ten katalog jest w `PATH`.
- **Z konsoli klastra:** ikona **?** → **Command Line Tools**. Tam jest `oc` w wersji dopasowanej do klastra.
- **Uzupełnianie poleceń (opcjonalnie):**
  ```bash
  oc completion bash | sudo tee /etc/bash_completion.d/oc > /dev/null
  ```

Logowanie do klastra:

```bash
oc login --token=<token> --server=https://api.<klaster>:6443
```

Gotowe polecenie z tokenem: konsola → nazwa użytkownika → **Copy login command**.

---

## 2. Wdrożenie projektu na OpenShift

**Pytanie:** Mam oc ustawione, chciałbym wrzucić ten projekt na OpenShift i sprawdzić, jak działa. Co mam zrobić?

**Co sprawdził asystent:**
- Projekt to aplikacja Spring Boot z wieloetapowym `Dockerfile` (UBI9 OpenJDK 17) i manifestem `openshift/deployment.yaml` (Deployment, Service, Route).
- Użytkownik jest zalogowany do **Developer Sandbox**:
  - serwer: `https://api.rm3.7wse.p1.openshiftapps.com:6443`
  - projekt: `tomek371240-dev`
- Problem: w Sandboxie nie da się utworzyć projektu `hello-logic`, a `deployment.yaml` wskazywał obraz z namespace'u `hello-logic`.

**Co zrobiono (sposób 2 z README: build z Dockerfile na klastrze):**

```bash
# 1. Konfiguracja builda z Dockerfile (tylko raz)
oc new-build --binary --name=hello-logic --strategy=docker

# 2. Wysłanie kodu i zbudowanie obrazu na klastrze
oc start-build hello-logic --from-dir=. --follow
# -> BUILD SUCCESS, Push successful

# 3. Wdrożenie z podmienionym namespace'em obrazu
NS=$(oc project -q)
sed "s#/hello-logic/hello-logic:latest#/$NS/hello-logic:latest#" openshift/deployment.yaml | oc apply -f -
oc rollout status deployment/hello-logic
```

Pierwsze zapytania dostały stronę „Application is not available”, bo router nie zaczął
jeszcze obsługiwać nowej trasy. Przy kolejnej próbie odpowiedź była poprawna.

**Wynik:**
- URL: https://hello-logic-tomek371240-dev.apps.rm3.7wse.p1.openshiftapps.com/
- `GET /` zwraca `hello logic, logic, logic!`
- `/actuator/health` zwraca `{"status":"UP","groups":["liveness","readiness"]}`
- Pod w stanie `Running`, bez restartów.

**Gdy zmienisz kod:**

```bash
oc start-build hello-logic --from-dir=. --follow
oc rollout restart deployment/hello-logic
```

**Przydatne polecenia:**

```bash
oc get pods                       # stan podów
oc logs -f deployment/hello-logic # logi aplikacji
oc delete all -l app=hello-logic; oc delete all -l build=hello-logic  # usunięcie wszystkiego
```

---

## 3. Podmiana obrazu w `deployment.yaml`

**Prośba:** Podmień w deployment yaml

**Zmiana** w `openshift/deployment.yaml`:

```yaml
image: image-registry.openshift-image-registry.svc:5000/tomek371240-dev/hello-logic:latest
```

`oc apply -f openshift/deployment.yaml` zwrócił `unchanged`, czyli plik zgadza się z tym,
co działa na klastrze, a wdrożenie nie potrzebuje już `sed`.

---

## 4. Poprawka README i commit

**Prośba:** popraw też README i zrób commit

**Zmiany w README:**
- **Logowanie:** zamiast `oc new-project hello-logic` jest `oc login --token=... --server=...` oraz wyjaśnienie, skąd wziąć to polecenie.
- **Namespace:** wyjaśnienie, że manifest wskazuje na `tomek371240-dev` (Sandbox), a na własnym klastrze trzeba podmienić pole `image`.
- **Sposób 2:** oznaczony jako zalecany, z poleceniami do aktualizacji po zmianie kodu.
- **Nowa sekcja „Przydatne polecenia”.**
- **Usunięta linia `# hello-oc`** wisząca na końcu pliku.

**Commit:** `41cc5a9` (Point deployment image to Developer Sandbox namespace and update README),
wykonany bezpośrednio na `main`.

---

## 5. GitHub Actions: automatyczne wdrożenie po commicie (sposób 2)

**Prośba:** Chcę robić wdrożenia na klaster, kiedy zrobię commita. Połączyć GitHub Actions z OpenShiftem sposobem nr 2. Krok po kroku.

Asystent sprawdził uprawnienia: w Sandboxie można tworzyć ServiceAccount, RoleBinding i Secret
(serwer OpenShift 4.22).

### Jak to działa

Po `git push` na `main` GitHub Actions:
1. loguje się do OpenShift;
2. uruchamia `oc start-build --from-dir=.`, czyli build z Dockerfile na klastrze;
3. robi `oc apply` i `rollout restart`;
4. sprawdza `/actuator/health`.

### Plik `.github/workflows/deploy.yml`

```yaml
name: Deploy to OpenShift

on:
  push:
    branches: [main]
  workflow_dispatch:

# Nie uruchamiaj dwóch wdrożeń naraz — nowszy push czeka na starszy.
concurrency:
  group: openshift-deploy
  cancel-in-progress: false

env:
  APP_NAME: hello-logic
  OC_URL: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install oc
        run: |
          curl -sSL "$OC_URL" | tar -xz -C /usr/local/bin oc
          oc version --client

      - name: Log in to OpenShift
        run: |
          oc login --token="${{ secrets.OPENSHIFT_TOKEN }}" \
                   --server="${{ secrets.OPENSHIFT_SERVER }}"
          oc project "${{ secrets.OPENSHIFT_NAMESPACE }}"

      # Sposób 2: build z Dockerfile na klastrze (BuildConfig typu docker, binary input)
      - name: Ensure BuildConfig exists
        run: |
          oc get bc/$APP_NAME >/dev/null 2>&1 || \
            oc new-build --binary --name=$APP_NAME --strategy=docker

      - name: Build image on cluster
        run: oc start-build $APP_NAME --from-dir=. --follow --wait

      - name: Deploy
        run: |
          oc apply -f openshift/deployment.yaml
          oc rollout restart deployment/$APP_NAME
          oc rollout status deployment/$APP_NAME --timeout=300s

      - name: Smoke test
        run: |
          HOST=$(oc get route $APP_NAME -o jsonpath='{.spec.host}')
          for i in $(seq 1 12); do
            BODY=$(curl -s "https://$HOST/actuator/health" || true)
            echo "$BODY" | grep -q '"status":"UP"' && { echo "OK: $BODY"; curl -s "https://$HOST/"; exit 0; }
            sleep 5
          done
          echo "Aplikacja nie odpowiada poprawnie: $BODY"; exit 1
```

### Krok 1: konto techniczne (ServiceAccount) na klastrze

Token z `oc login` wygasa, więc GitHub potrzebuje własnego konta z tokenem, który nie wygasa:

```bash
oc create serviceaccount github-actions
oc policy add-role-to-user edit -z github-actions

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: github-actions-token
  annotations:
    kubernetes.io/service-account.name: github-actions
type: kubernetes.io/service-account-token
EOF

# odczyt tokenu (do kroku 2)
oc get secret github-actions-token -o jsonpath='{.data.token}' | base64 -d; echo
```

### Krok 2: sekrety w GitHubie

Repo `tomek401273/hello-oc` → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Nazwa | Wartość |
|---|---|
| `OPENSHIFT_SERVER` | `https://api.rm3.7wse.p1.openshiftapps.com:6443` |
| `OPENSHIFT_TOKEN` | token z kroku 1 |
| `OPENSHIFT_NAMESPACE` | `tomek371240-dev` |

Tokenu nie wklejaj nigdzie poza sekretami GitHuba.

### Krok 3: commit i push

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Actions deploy to OpenShift"
git push origin main
```

### Krok 4: sprawdzenie

Zakładka **Actions** → przebieg „Deploy to OpenShift”. Krok **Smoke test** powinien wypisać
`OK: {"status":"UP"...}` i `hello logic, logic, logic!`. Workflow można też uruchomić ręcznie
przyciskiem **Run workflow**.

### Na co uważać w Developer Sandbox
- **Ważność konta:** Sandbox wygasa po ok. 30 dniach. Po odnowieniu adres API może się zmienić, a token przestanie działać. Wtedy powtórz kroki 1 i 2.
- **Usypianie:** po dłuższym braku ruchu aplikacja może zostać przeskalowana do 0. Kolejne wdrożenie albo `oc scale deployment/hello-logic --replicas=1` ją podniesie.

---

## 6. Skąd adres `https://api.rm3.7wse.p1.openshiftapps.com:6443`

**Pytanie:** Czemu ten adres?

**Odpowiedź:** to adres **API klastra**, czyli ten sam serwer, do którego jest zalogowany lokalny `oc`:

```bash
oc whoami --show-server
# https://api.rm3.7wse.p1.openshiftapps.com:6443
```

Składniki adresu:
- **`api.`**: OpenShift wystawia API pod nazwą zaczynającą się od `api.`.
- **`rm3.7wse.p1.openshiftapps.com`**: domena konkretnego klastra Developer Sandbox.
- **`:6443`**: standardowy port API Kubernetesa/OpenShift.

| Adres | Do czego służy |
|---|---|
| `https://api.rm3.7wse.p1.openshiftapps.com:6443` | **API klastra**. Łączą się z nim `oc` i GitHub Actions. |
| `https://hello-logic-tomek371240-dev.apps.rm3.7wse.p1.openshiftapps.com/` | **Aplikacja** (Route). Otwierasz ją w przeglądarce. |

GitHub Actions steruje klastrem tak samo jak `oc` z terminala, dlatego `OPENSHIFT_SERVER`
to adres API. Po założeniu Sandboxa od nowa sprawdź adres ponownie przez `oc whoami --show-server`.

---

## 7. Błąd push: brak uprawnienia `workflow`

**Błąd:**

```
! [remote rejected] main -> main (refusing to allow an OAuth App to create or update workflow `.github/workflows/deploy.yml` without `workflow` scope)
```

**Przyczyna:** `git` loguje się przez GitHub CLI (`gh auth git-credential`), a token konta
`tomek401273` miał tylko uprawnienia `gist`, `read:org`, `repo`. Do zmiany plików w
`.github/workflows/` potrzebne jest uprawnienie `workflow`.

**Rozwiązanie:**

```bash
gh auth refresh -h github.com -s workflow   # zatwierdź kod w przeglądarce
gh auth status                              # Token scopes: ... 'workflow'
git push origin main
```

Push wysyła commity `41cc5a9` (README + `deployment.yaml`) i `ae60f31` (workflow).

---

## 8. Błąd w GitHub Actions: niepoprawny URL serwera

**Błąd:**

```
error: Not a valid URL: parse "https://%20https:%2F%2Fapi.rm3.7wse.p1.openshiftapps.com:6443": invalid port ...
```

**Przyczyna:** sekret `OPENSHIFT_SERVER` miał na początku **spację** (`%20`). `oc` nie rozpoznał
wartości jako adresu i dokleił własne `https://`.

**Rozwiązanie:** ustawić sekret dokładnie na `https://api.rm3.7wse.p1.openshiftapps.com:6443`,
bez spacji i nowej linii. Przez stronę: **Settings** → **Secrets and variables** → **Actions** → edycja.
Albo z terminala:

```bash
gh secret set OPENSHIFT_SERVER -R tomek401273/hello-oc --body "https://api.rm3.7wse.p1.openshiftapps.com:6443"
```

Na pewno czyste nadpisanie pozostałych sekretów:

```bash
gh secret set OPENSHIFT_NAMESPACE -R tomek401273/hello-oc --body "tomek371240-dev"
oc get secret github-actions-token -o jsonpath='{.data.token}' | base64 -d | gh secret set OPENSHIFT_TOKEN -R tomek401273/hello-oc
```

Potem **Actions** → **Re-run all jobs**.
