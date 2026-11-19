# GitHub Actions + OpenShift: automatyczne wdrożenie po każdym pushu

Instrukcja, jak połączyć repozytorium na GitHubie z klastrem OpenShift (Developer Sandbox),
żeby każdy `git push` na `main` sam budował i wdrażał aplikację.

Przy każdym kroku jest wyjaśnienie **po co** się go robi. Nie tylko *co* wpisać, ale *dlaczego*.

---

## Najpierw obraz całości: o co tu chodzi?

Wyobraź sobie, że OpenShift to **fabryka**, a GitHub Actions to **kurier**.

- Do tej pory sam jeździłeś do fabryki: wpisywałeś w terminalu `oc start-build`, `oc apply`
  i fabryka budowała i uruchamiała Twoją aplikację.
- Teraz chcemy, żeby po każdym commicie **kurier (GitHub Actions)** sam zawiózł kod do
  fabryki i wydał te same polecenia za Ciebie.

Żeby kurier mógł to zrobić, potrzebuje trzech rzeczy:

| Czego potrzebuje kurier | Co to jest u nas | Krok |
|---|---|---|
| **Przepustki** do fabryki | ServiceAccount + token | Krok 1 |
| **Adresu i przepustki zapisanych w bezpiecznym miejscu** | Sekrety w GitHubie | Krok 2 |
| **Listy zadań**: co ma zrobić po przyjeździe | Plik `.github/workflows/deploy.yml` | Krok 3 |

Cały przepływ:

```
 Ty                GitHub                    GitHub Actions (runner)              OpenShift
  │  git push        │                                │                                │
  ├────────────────► │  "jest nowy commit na main"    │                                │
  │                  ├──────────────────────────────► │                                │
  │                  │                                │ oc login (token z sekretów)    │
  │                  │                                ├──────────────────────────────► │
  │                  │                                │ oc start-build --from-dir=.    │
  │                  │                                ├──────────────────────────────► │ buduje obraz
  │                  │                                │                                │ z Dockerfile
  │                  │                                │ oc apply + rollout restart     │
  │                  │                                ├──────────────────────────────► │ uruchamia
  │                  │                                │                                │ nowy pod
  │                  │                                │ curl /actuator/health          │
  │                  │                                ├──────────────────────────────► │ "UP"
  │                  │ ✅ zielony przebieg             │                                │
```

### Dlaczego „sposób 2” (build z Dockerfile na klastrze)?

Obraz kontenera buduje **OpenShift**, a nie GitHub. Kurier przywozi do fabryki tylko
**surowce** (kod źródłowy), a fabryka sama robi z nich gotowy produkt (obraz) według
**przepisu** (`Dockerfile`).

Plusy:
- **Nie trzeba zewnętrznego rejestru obrazów** (Docker Hub, Quay). Obraz trafia od razu
  do wewnętrznego rejestru OpenShift, tuż obok miejsca, gdzie będzie uruchomiony.
- **Ten sam przepis lokalnie i w CI.** Dokładnie to samo wpisywałeś ręcznie w terminalu,
  więc jeśli działało ręcznie, zadziała i w automacie.
- **GitHub nie potrzebuje Dockera.** Runner tylko wysyła pliki i wydaje polecenia.

---

## Krok 0: co musisz mieć na start

- Zainstalowany `oc` i zalogowanie do klastra (`oc whoami` pokazuje Twoją nazwę).
- Projekt z działającym `Dockerfile` i `openshift/deployment.yaml`.
- Repozytorium na GitHubie.

> **Po co?** Automat robi dokładnie to, co Ty robisz ręcznie. Najpierw upewnij się, że
> ręcznie wszystko działa (`oc start-build ...`, `oc apply ...`). Inaczej przy błędzie nie
> wiadomo, czy psuje się aplikacja, czy automat.

---

## Krok 1: konto techniczne dla GitHuba (ServiceAccount + token)

```bash
# 1a. Konto techniczne
oc create serviceaccount github-actions

# 1b. Uprawnienia: może edytować zasoby w TYM projekcie
oc policy add-role-to-user edit -z github-actions

# 1c. Długoterminowy token dla tego konta
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: github-actions-token
  annotations:
    kubernetes.io/service-account.name: github-actions
type: kubernetes.io/service-account-token
EOF

# 1d. Odczytaj token (skopiuj wynik do kroku 2)
oc get secret github-actions-token -o jsonpath='{.data.token}' | base64 -d; echo
```

### Po co to wszystko?

**Dlaczego nie użyć mojego tokenu z `oc login`?**
Twój token to **Twoja osobista przepustka** i do tego **tymczasowa**: wygasa po kilku
godzinach albo dniach. Gdybyś dał ją GitHubowi:
- jutro wdrożenia przestałyby działać, bo przepustka wygasła;
- GitHub miałby **wszystkie Twoje uprawnienia**, więcej niż potrzebuje.

**1a: `serviceaccount`** to „pracownik” w fabryce, który nie jest człowiekiem. Konto
**tylko dla automatu**. Od razu widać, co zrobił automat, a co Ty, i można je w każdej chwili
usunąć bez ruszania Twojego konta.

**1b: rola `edit`** określa, do których pomieszczeń przepustka otwiera drzwi. `edit` pozwala
budować obrazy i zmieniać Deploymenty, Service'y i Route'y, ale **tylko w Twoim projekcie**
i bez zarządzania uprawnieniami innych. To **zasada najmniejszych uprawnień**: dajemy tyle,
ile trzeba, i nic więcej.
> `-z github-actions` to skrót od „ServiceAccount o nazwie github-actions w bieżącym projekcie”.

**1c: Secret typu `service-account-token`** to **stała przepustka** dla tego pracownika.
Kubernetes sam wypełnia ten Secret tokenem, który **nie wygasa**, dopóki Secret istnieje.
Dlatego automat zadziała również za tydzień.

**1d: `base64 -d`**: Kubernetes przechowuje wartości w Secretach zakodowane w base64
(to kodowanie, nie szyfrowanie). Dekodujemy, żeby dostać właściwy token do wklejenia.

> ⚠️ Token to klucz do Twojego projektu. Nie wklejaj go do kodu, README, commitów ani czatów.
> Jego jedyne miejsce to sekrety GitHuba (krok 2).

---

## Krok 2: sekrety w GitHubie

Repo na GitHubie → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

| Nazwa | Wartość | Skąd ją wziąć |
|---|---|---|
| `OPENSHIFT_SERVER` | `https://api.rm3.7wse.p1.openshiftapps.com:6443` | `oc whoami --show-server` |
| `OPENSHIFT_TOKEN` | token z kroku 1d | krok 1d |
| `OPENSHIFT_NAMESPACE` | `tomek371240-dev` | `oc project -q` |

Albo z terminala, przez `gh`, co jest bezpieczniejsze, bo nic nie kopiujesz ręcznie:

```bash
gh secret set OPENSHIFT_SERVER    --body "$(oc whoami --show-server)"
gh secret set OPENSHIFT_NAMESPACE --body "$(oc project -q)"
oc get secret github-actions-token -o jsonpath='{.data.token}' | base64 -d | gh secret set OPENSHIFT_TOKEN
```

### Po co?

**Dlaczego sekrety, a nie wpisać wartości w plik workflow?**
Plik workflow jest **w repozytorium**, więc widzi go każdy, kto ma dostęp do kodu (a w
publicznym repo cały internet). Sekrety to **sejf**: GitHub przechowuje je zaszyfrowane,
podaje je tylko do działającego workflow i **zamazuje je w logach** (widać `***`).

**Dlaczego adres `api....:6443`, a nie adres aplikacji?**
Klaster ma dwa rodzaje adresów:

| Adres | Analogia | Kto go używa |
|---|---|---|
| `https://api.<klaster>:6443` | **biuro zarządu** fabryki, gdzie wydaje się polecenia | `oc`, GitHub Actions |
| `https://hello-logic-...apps.<klaster>/` | **sklep**, gdzie klient odbiera produkt | przeglądarka, użytkownicy |

Kurier ma **wydawać polecenia** (build, deploy), więc jedzie do biura zarządu, czyli na
adres API. `:6443` to standardowy port API Kubernetesa/OpenShift.

**Dlaczego namespace jako osobny sekret?**
Żeby workflow nie był „przyspawany” do jednego projektu. W innym Sandboxie albo na innym
klastrze zmieniasz tylko sekret, a pliku nie ruszasz.

> ⚠️ **Pułapka, na którą trafiliśmy:** przy wklejaniu wartości łatwo złapać **spację lub
> nową linię**. Wtedy pojawia się błąd w stylu
> `Not a valid URL: parse "https://%20https:..."` (`%20` to spacja).
> Rozwiązanie: wpisz wartość jeszcze raz, bez spacji, albo użyj poleceń `gh secret set` powyżej.

---

## Krok 3: plik workflow `.github/workflows/deploy.yml`

To **lista zadań kuriera**. GitHub automatycznie wykonuje każdy plik `.yml` z katalogu
`.github/workflows/`.

```yaml
name: Deploy to OpenShift

on:
  push:
    branches: [main]
  workflow_dispatch:

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

### Po co każda część?

#### `on:` → **kiedy** kurier ma ruszyć
- `push: branches: [main]`: po każdym pushu na `main`. **Po co?** Żeby `main` zawsze
  odpowiadał temu, co działa na klastrze. Pushe na inne gałęzie nie wdrażają, więc możesz
  spokojnie eksperymentować na gałęziach.
- `workflow_dispatch`: przycisk **Run workflow** w zakładce Actions. **Po co?** Żeby móc
  wdrożyć ponownie bez sztucznego commita, np. gdy Sandbox uśpił aplikację.

#### `concurrency:` → **jeden kurier naraz**
**Po co?** Jeśli zrobisz dwa pushe szybko po sobie, dwa wdrożenia działałyby równocześnie
i mogłyby sobie przeszkadzać (dwa buildy, dwa rollouty). Tak drugi czeka, aż pierwszy skończy.

#### `env:` → **zmienne pomocnicze**
**Po co?** Nazwa aplikacji jest w jednym miejscu. Gdy ją zmienisz, zmieniasz jedną linię,
a nie pięć.

#### `runs-on: ubuntu-latest` → **samochód kuriera**
GitHub daje świeżą, czystą maszynę z Ubuntu na każdy przebieg i niszczy ją po zakończeniu.
**Dlatego** każdy krok musi przygotować sobie wszystko od zera (pobrać kod, zainstalować `oc`).

#### Krok `Checkout` → **zabierz paczkę**
Maszyna startuje pusta, bez Twojego kodu. `actions/checkout` pobiera repozytorium.
**Po co?** Bez tego nie ma czego wysłać do builda.

#### Krok `Install oc` → **daj kurierowi kluczyki**
Na maszynie GitHuba nie ma `oc`, więc pobieramy go z oficjalnego mirrora Red Hat.
**Po co?** Wszystkie następne kroki to polecenia `oc`, te same, które wpisywałeś ręcznie.

#### Krok `Log in to OpenShift` → **pokaż przepustkę na bramce**
`oc login` z tokenem i adresem z sekretów, a potem `oc project` wybiera właściwy projekt.
**Po co?** Bez logowania klaster odrzuci każde polecenie. Bez `oc project` polecenia mogłyby
trafić do złego projektu.

#### Krok `Ensure BuildConfig exists` → **upewnij się, że linia produkcyjna istnieje**
`BuildConfig` to **przepis na build** zapisany w klastrze („buduj z Dockerfile, wynik zapisz
jako obraz `hello-logic:latest`”).
- `oc get bc/...`: sprawdza, czy przepis już jest.
- `|| oc new-build ...`: **tylko jeśli go nie ma**, tworzy go.

**Po co ta konstrukcja?** Żeby workflow był **idempotentny**, czyli dawał ten sam efekt
niezależnie od tego, czy uruchamiasz go po raz pierwszy, czy setny. Pierwszy przebieg
tworzy linię produkcyjną, kolejne jej używają. Bez sprawdzenia drugi przebieg wywaliłby się
na błędzie „already exists”.

#### Krok `Build image on cluster` → **wyprodukuj nowy obraz**
`oc start-build --from-dir=.` pakuje bieżący katalog (kod z commita) i wysyła go do klastra.
OpenShift buduje obraz z `Dockerfile` i zapisuje go w wewnętrznym rejestrze.
- `--follow`: logi buildu lecą na żywo do logów GitHub Actions. **Po co?** Jeśli build się
  wysypie (np. błąd kompilacji), widzisz przyczynę bezpośrednio w GitHubie.
- `--wait`: krok kończy się błędem, jeśli build się nie uda. **Po co?** Żeby nie wdrażać
  niczego, gdy obraz się nie zbudował.

#### Krok `Deploy` → **wymień towar na półce**
- `oc apply -f openshift/deployment.yaml`: ustawia klaster tak, jak opisuje plik (Deployment,
  Service, Route). **Po co?** Plik w repo jest **źródłem prawdy**. Jeśli zmienisz w nim np.
  pamięć albo sondy, zmiana trafi na klaster razem z kodem. Gdy nic się nie zmieniło,
  `apply` niczego nie psuje (`unchanged`).
- `oc rollout restart`: **Po co, skoro obraz się zmienił?** Deployment wskazuje na tag
  `:latest`. Nazwa obrazu się nie zmienia, więc Kubernetes „nie zauważa”, że pod tym tagiem
  jest nowa wersja. `restart` każe mu uruchomić nowe pody, które pobiorą świeży obraz.
- `oc rollout status`: czeka, aż nowe pody wstaną i przejdą **readiness probe**.
  **Po co?** Żeby przebieg był zielony dopiero wtedy, gdy nowa wersja naprawdę działa, a nie
  wtedy, gdy tylko „wysłano polecenie”. Jeśli pod się nie podniesie w 5 minut, krok kończy się
  błędem i od razu to widzisz.

#### Krok `Smoke test` → **sprawdź, czy klient może odebrać produkt**
Pobiera adres Route i odpytuje `/actuator/health` (do 12 razy co 5 sekund), aż dostanie
`"status":"UP"`.
**Po co, skoro `rollout status` już sprawdził pody?** `rollout status` sprawdza aplikację
**od środka klastra**. Smoke test sprawdza **od zewnątrz**, tak jak użytkownik: przez Route,
router i HTTPS. Łapie problemy, których rollout nie widzi, np. źle skonfigurowaną Route.
**Dlaczego kilka prób?** Router potrzebuje chwili, żeby zauważyć nowe pody. Zaraz po
wdrożeniu może przez kilka sekund pokazywać „Application is not available”. To widzieliśmy
przy pierwszym ręcznym wdrożeniu.

---

## Krok 4: wypchnięcie workflow na GitHuba

```bash
git add .github/workflows/deploy.yml
git commit -m "Add GitHub Actions deploy to OpenShift"
git push origin main
```

> ⚠️ **Pułapka, na którą trafiliśmy:**
> `refusing to allow an OAuth App to create or update workflow ... without workflow scope`
>
> **Dlaczego?** GitHub traktuje pliki workflow specjalnie, bo workflow może dostać się do
> sekretów. Żeby je dodać lub zmienić, token, którym pushujesz, musi mieć osobne uprawnienie
> `workflow`. Zwykłe `repo` nie wystarczy.
>
> **Rozwiązanie** (gdy git loguje się przez GitHub CLI):
> ```bash
> gh auth refresh -h github.com -s workflow   # zatwierdź kod w przeglądarce
> gh auth status                              # powinno być: 'workflow' w Token scopes
> git push origin main
> ```

---

## Krok 5: sprawdzenie

1. GitHub → zakładka **Actions** → przebieg **Deploy to OpenShift**.
2. Wszystkie kroki powinny być zielone. W **Smoke test** zobaczysz:
   ```
   OK: {"status":"UP","groups":["liveness","readiness"]}
   hello logic, logic, logic!
   ```
3. Od teraz: **zmieniasz kod → `git push` → po kilku minutach nowa wersja działa na klastrze.**

**Po co sprawdzać pierwszy przebieg uważnie?** Pierwszy przebieg testuje całe połączenie:
token, adres, uprawnienia i build. Jeśli zadziała raz, kolejne przebiegi zwykle też zadziałają,
bo robią dokładnie to samo.

---

## Gdy coś nie działa: szybka diagnoza

| Objaw w logach | Co to znaczy | Co zrobić |
|---|---|---|
| `Not a valid URL: parse "https://%20..."` | spacja w sekrecie `OPENSHIFT_SERVER` | wpisz sekret ponownie, bez spacji |
| `error: You must be logged in` / `Unauthorized` | zły, wygasły lub usunięty token | powtórz krok 1d i zaktualizuj `OPENSHIFT_TOKEN` |
| `Forbidden ... cannot create ...` | ServiceAccount nie ma roli `edit` | `oc policy add-role-to-user edit -z github-actions` |
| `project ... not found` | zły `OPENSHIFT_NAMESPACE` | sprawdź `oc project -q` i popraw sekret |
| build się wysypuje | błąd w kodzie lub `Dockerfile` | logi są w kroku *Build image on cluster*; sprawdź lokalnie `mvn package` |
| `rollout status` timeout | pod nie wstaje (np. błąd startu, zła sonda) | `oc get pods`, `oc logs deployment/hello-logic` |
| `Application is not available` w smoke teście | Route nie widzi podów | `oc get endpoints hello-logic`, sprawdź selektory w `deployment.yaml` |

---

## Developer Sandbox: o czym pamiętać

- **Sandbox wygasa po ok. 30 dniach.** Po odnowieniu możesz trafić na inny klaster, czyli
  inny adres API i nowy token. Wtedy powtórz **krok 1** i **krok 2**. Workflow się nie zmienia.
- **Usypianie:** po dłuższym braku ruchu Sandbox skaluje aplikację do 0. Uruchom workflow
  przyciskiem **Run workflow** albo wpisz `oc scale deployment/hello-logic --replicas=1`.
- **Brak `oc new-project`:** w Sandboxie masz jeden projekt `<użytkownik>-dev`. Dlatego pole
  `image` w `openshift/deployment.yaml` wskazuje na
  `image-registry.openshift-image-registry.svc:5000/tomek371240-dev/hello-logic:latest`.

---

## Podsumowanie w jednym zdaniu na krok

1. **ServiceAccount + token:** stała przepustka do klastra tylko dla automatu, z minimalnymi uprawnieniami.
2. **Sekrety w GitHubie:** adres i przepustka w sejfie, a nie w kodzie.
3. **Workflow:** lista zadań kuriera: pobierz kod, zaloguj się, zbuduj obraz na klastrze, wdroż, sprawdź.
4. **Push z uprawnieniem `workflow`:** GitHub chroni pliki workflow, bo mają dostęp do sekretów.
5. **Pierwszy przebieg:** test całego połączenia. Potem każdy push wdraża się sam.
