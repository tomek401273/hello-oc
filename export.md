❯ jak zainstalować oc command

Na Linuksie najprościej pobrać gotową binarkę z serwera mirror OpenShift:

# 1. Pobierz archiwum (x86_64)
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz

# 2. Rozpakuj
tar -xzf openshift-client-linux.tar.gz

# 3. Przenieś do katalogu z PATH (tam trafia też kubectl)
sudo mv oc kubectl /usr/local/bin/

# 4. Sprawdź, czy działa
oc version --client

Uwagi:
- Inna architektura: na ARM pobierz openshift-client-linux-arm64.tar.gz. Architekturę sprawdzisz poleceniem uname -m.
- Konkretna wersja: jeśli chcesz wersję zgodną z klastrem, zamień stable w adresie na np. stable-4.16. Najlepiej, żeby wersja klienta zgadzała się z wersją klastra.
- Bez sudo: możesz wrzucić binarkę do ~/.local/bin i upewnić się, że ten katalog jest w PATH.
- Z konsoli klastra: w web console kliknij ikonę ? (prawy górny róg), potem Command
  Line Tools. Tam jest linko Twojego klastra.
- Uzupełnianie poleceń (opcjonalnie):
  oc completion bash | sudo t> /dev/null

Potem zaloguj się do klastr
oc login --token=<token> --server=https://api.<klaster>:6443
Gotowe polecenie z tokenem żytkownika → Copy login
command.

Jeśli chcesz, mogę od razu zainstalować oc na tej maszynie.

Baked for 8s · done środa, 21:10

❯ Dora mam oc usstawione chciałbym wrzucić ten projekt na openshfit i sprawdzić jak
działa co mam zrobić?

Najpierw sprawdzę, co jest gowany do klastra.

Ran 2 shell commands

Projekt tomek371240-dev ma le hello-logic nie da się
utworzyć w Sandbox, więc podmienię namespace w deployment.yaml i buduję obraz na
klastrze. · summary

Ran 1 shell command

Obraz jest zbudowany. Terazonym namespace'em:

Ran 1 shell command                                                                                    Wdrożenie przeszło, ale rou not available”, pewnieprzez opóźnienie propagacji nowej trasy. Sprawdzę pody i endpointy, a potem ponowię próbę. · summary

Ran 1 shell command

Ran 1 shell command

Aplikacja działa na OpenShi
https://hello-logic-tomek371240-dev.apps.rm3.7wse.p1.openshiftapps.com/

Sprawdziłem ją curl-em:
- GET / zwraca hello logic,
- /actuator/health zwraca {"status":"UP","groups":["liveness","readiness"]}
- Pod jest w stanie Running

Pierwsze zapytania zaraz poplication is not available”.
To było tylko opóźnienie, zanim router zaczął obsługiwać nową trasę, i przy
kolejnej próbie odpowiedź b

Co zrobiłem (sposób 2 z REAastrze)

# 1. Konfiguracja builda z
oc new-build --binary --name=hello-logic --strategy=docker

# 2. Wysłanie kodu i zbudowanie obrazu na klastrze
oc start-build hello-logic

# 3. Wdrożenie Deployment +nym namespace'em obrazu
NS=$(oc project -q)
sed "s#/hello-logic/hello-llatest#"
openshift/deployment.yaml | oc apply -f -

deployment.yaml wskazuje obraz z namespace'u hello-logic. W Sandboxie nie można
utworzyć takiego projektu, , więc przy wdrażaniu
podmieniłem namespace przez sed. Pliku w repo nie zmieniałem.

Gdy zmienisz kod

oc start-build hello-logic --from-dir=. --follow
oc rollout restart deployme

Przydatne polecenia

oc get pods
oc logs -f deployment/hello-logic # logi aplikacji
oc delete all -l app=hello-=hello-logic  # usunięcie
wszystkiego

Mogę na stałe poprawić deployment.yaml, żeby oc apply działał bez sed, np. przez
trigger na ImageStream, któ po każdym buildzie.

Cooked for 2m 49s · done śr

recap: The hello-logic app  Sandbox and responds
correctly at
https://hello-logic-tomek37nshiftapps.com/. Next,
decide whether I should fix deployment.yaml so `oc apply` works without the
namespace swap. (turn off r

❯ Podmień w deployment yaml

● Bash(sed -i 's#svc:5000/helvc:5000/tomek371240-dev/hell
o-logic:latest#' openshift/deployment.yaml && grep -n "image:"
openshift/deployme…)
21:          image: image-registry.openshift-image-registry.svc:5000/tomek37
1240-dev/hello-logic:lat
deployment.apps/hello-logic unchanged
… +4 lines
Updated openshift/deployment.yaml +1 -1
- name: hel
# Przy budowaniu przez BuildConfig/S2I obraz wskazuje na we
wnetrzny rejestr Op
# Jesli budujesz lokalnie i wypychasz do innego rejestru -
podmien ponizsza wa
image: image-registry.openshift-image-registry.svc:5000/hel
lo-logic/hello-logi
image: image-registry.openshift-image-registry.svc:5000/tom
ek371240-dev/hello-
ports:
- conta
resources:
(files that changed whilmmand or by another
process; a convenience view, not a review or audit of the command)

Podmienione. W openshift/deployment.yaml:21 obraz wskazuje teraz na Twój namespace:

image:
image-registry.openshift-im1240-dev/hello-logic:latest

Uruchomiłem oc apply -f opeałem unchanged. To znaczy,
że plik zgadza się z tym, co już działa na klastrze, a wdrożenie nie potrzebuje już
sed.

Zmiana nie jest jeszcze zacst oc new-project
hello-logic, a w Sandboxie tego polecenia nie da się wykonać, więc mogę też poprawić
tę instrukcję.

Worked for 9s · done środa,

❯ popraw też README i zrób co

Read 1 file

● Update(README.md)
Added 9 lines, removed 3 lines

## Wdrożenie na OpenShift

Zaloguj się i utwórz projekt:
Zaloguj się (polecea użytkownika → **Cop
y login command**):

```bash
oc login <adres-kla
oc new-project hello-logic
oc login --token=<tstra>
oc project -q   # aktualny projekt (namespace)
```

Manifest `openshiftony na namespace Deve
loper Sandbox
`tomek371240-dev`. owych projektów — wdr
ażasz do
istniejącego `<użyttrze możesz utworzyć
projekt
(`oc new-project heń namespace w polu `i
mage`
w `openshift/deploy

### Sposób 1 (najprje sam z kodu źródłow
ego

Nie wymaga Dockerfile ani lokalnego Dockera. Z katalogu projektu:

● Update(README.md)
Added 10 lines, removed
oc create route edge --service=hello-logic
```

### Sposób 2: build
### Sposób 2 (zalecany): build z Dockerfile na klastrze

```bash
oc new-build --binaegy=docker
oc new-build --binary --name=hello-logic --strategy=docker   # tylko
za pierwszym razem
oc start-build hello-logic --from-dir=. --follow
oc apply -f openshi
oc rollout status deployment/hello-logic
```

Po zmianie kodu:

```bash
oc start-build hello-logic --from-dir=. --follow
oc rollout restart
```

### Sposób 3: build lokalny (podman/docker) + push do rejestru

```bash

● Update(README.md)
Added 9 lines, removed 1

- liveness: `/actua
- readiness: `/actuator/health/readiness`
# hello-oc

## Przydatne polece

```bash
oc get pods                        # stan podów
oc logs -f deploymecji
oc delete all -l app=hello-logic   # usunięcie Deployment/Service/Rou
te
oc delete all -l build=hello-logic # usunięcie BuildConfig/ImageStrea
m
```

Ran 1 shell command

README jest poprawione, a obie zmiany są w commicie 41cc5a9 („Point deployment image
to Developer Sandbox namespwo robocze jest czyste.
Commit trafił prosto na main, bez osobnej gałęzi. Jeśli wolisz go mieć na gałęzi,
mogę go przenieść.

Co zmieniło się w README:
- Logowanie: zamiast oc new-project hello-logic jest teraz oc login --token=...
  --server=.... Dopisałem t konsoli.
- Namespace: jest wyjaśnienie, że manifest wskazuje na tomek371240-dev, bo w
  Sandboxie nie można tworzym klastrze trzeba podmienić
  namespace w polu image.
- Sposób 2: oznaczyłem go jnia do aktualizacji po
  zmianie kodu (start-build i rollout restart).
- Nowa sekcja „Przydatne poie zasobów.
- Usunięta linia # hello-oc: wisiała na końcu pliku jako osobny nagłówek.

Nic jeszcze nie jest wypchnięte na GitHub (origin, czyli tomek401273/hello-oc).
Jeśli chcesz, zrobię git pu

Cooked for 21s · done środa

❯ Chcę robić wdrozenia na clucę połączyć github action z
opehsifterm. I to sposobem numer 2. Pwiedz mi jak krok po kroku.

Ran 1 shell command · 1 failed

Sprawdziłem uprawnienia: w Sandboxie możesz tworzyć ServiceAccount, RoleBinding i
Secret, a to wystarczy do tlik workflow.

● Write(.github/workflows/dep
Wrote 58 lines to .github/workflows/deploy.yml
name: Deploy to Open

on:
push:
branches: [main]
workflow_dispatch:

# Nie uruchamiaj dwóch wdrożeń naraz — nowszy push czeka na starszy.
concurrency:
group: openshift-deploy
… +48 lines

Przygotowałem plik workflow. Na klastrze ani na
GitHubie jeszcze nic nie zmieniałem, więc poniższe kroki robisz sam.

Jak to działa

Robisz git push na main, a GitHub Actions wykonuje kolejno:
1. loguje się do OpenShift;
2. uruchamia oc start-build --from-dir=., czyli build z Dockerfile na klastrze
   (sposób 2);
3. robi oc apply i rollout restart;
4. na koniec sprawdza /actu

Krok 1: konto techniczne (S

Token z oc login wygasa, wi konta z tokenem, który nie
wygasa:

# konto dla GitHub Actions z prawem edycji w Twoim projekcie
oc create serviceaccount gi
oc policy add-role-to-user edit -z github-actions

# długoterminowy token (Secret powiązany z kontem)
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
name: github-actions-toke
annotations:
kubernetes.io/service-a
type: kubernetes.io/service-account-token
EOF

# odczyt tokenu (skopiuj wy
oc get secret github-actions-token -o jsonpath='{.data.token}' | base64 -d; echo

Krok 2: sekrety w GitHubie

Na GitHubie otwórz repo tomek401273/hello-oc → Settings → Secrets and variables →
Actions → New repository se

┌─────────────────────┬───────────────────┐
│        Nazwa        │                    Wartość                     │
├─────────────────────┼───────────────────┤
│ OPENSHIFT_SERVER    │ https://api.rm3.7wse.p1.openshiftapps.com:6443 │
├─────────────────────┼───────────────────┤
│ OPENSHIFT_TOKEN     │ token z kroku 1                                │
├─────────────────────┼───────────────────┤
│ OPENSHIFT_NAMESPACE │ tomek371240-dev                                │
└─────────────────────┴───────────────────┘

Tokenu nie wklejaj nigdzie o kodu ani commitów.

Krok 3: commit i push workf

git add .github/workflows/d
git commit -m "Add GitHub Actions deploy to OpenShift"
git push origin main

Krok 4: sprawdzenie

Na GitHubie otwórz zakładkęo OpenShift”. Krok Smoke
test powinien wypisać OK: {"status":"UP"...} i hello logic, logic, logic!. Od tej
chwili każdy push na main wesz też uruchomić ręcznie
przyciskiem Run workflow (workflow_dispatch).

Na co uważać w Developer Sandbox

- Ważność konta: Sandbox wygasa po ok. 30 dniach. Po odnowieniu adres API może się
  zmienić, a token przestanki 1 i 2.
- Usypianie: po dłuższym braku ruchu Sandbox może przeskalować aplikację do 0.
  Kolejne wdrożenie albo oc --replicas=1 ją podniesie.

Jeśli chcesz, mogę od razu  także zrobić commit i push
z kroku 3. Sekrety w kroku 2 musisz dodać sam, bo robi się to w ustawieniach repo na
GitHubie.

Baked for 36s · done środa,

❯ Czemu ten adres  https://apom:6443

Bo to adres API Twojego klao którego jest teraz
zalogowany Twój lokalny oc. Wziąłem go z wyniku polecenia na początku rozmowy:

oc whoami --show-server
# https://api.rm3.7wse.p1.o

Sam możesz go też odczytać  polecenia Copy login
command w konsoli (parametr --server=).

Z czego składa się ten adres

- api.: OpenShift wystawia API pod nazwą zaczynającą się od api..
- rm3.7wse.p1.openshiftappstra Developer Sandbox, na
  którym masz konto.
- :6443: standardowy port A

Czym różni się od adresu ap

To dwa różne adresy:

Adres: https://api.rm3.7wse
Do czego służy: API klastra. Łączą się z nim oc i GitHub Actions, żeby wydawać
polecenia (build, deploy)
────────────────────────────────────────
Adres: https://hello-logic-.p1.openshiftapps.com/
Do czego służy: Twoja aplikacja (Route). Otwierasz ją w przeglądarce.

GitHub Actions musi sterować klastrem tak samo jak Ty z terminala, dlatego w
sekrecie OPENSHIFT_SERVER ps aplikacji.

Jeśli Sandbox wygaśnie i zafić na inny klaster. Wtedy
sprawdź adres ponownie przez oc whoami --show-server i zaktualizuj sekret.

Crunched for 7s · done 21:38

❯ To https://github.com/tomek401273/hello-oc.git
! [remote rejected] main -OAuth App to create or
update workflow .github/workflows/deploy.yml without workflow scope)
error: failed to push some omek401273/hello-oc.git'

Ran 1 shell command

GitHub odrzucił push, bo tolnia, nie ma uprawnienia
workflow. Taki token może zmieniać zwykłe pliki, ale nie pliki w .github/workflows/,
które GitHub chroni osobnym

Sprawdziłem Twoją konfiguraHub CLI (gh auth
git-credential), a token konta tomek401273 ma tylko uprawnienia gist, read:org i
repo.

Jak to naprawić

1. Dodaj uprawnienie workfl
   gh auth refresh -h github.com -s workflow
   Pokaże się jednorazowy kglądarce, wklej kod i
   zatwierdź.
2. Sprawdź, czy workflow poń:
   gh auth status
# Token scopes: 'gist', 're
3. Wypchnij ponownie:
   git push origin main

Polecenie z kroku 1 jest inuchomić sam. Możesz je
wpisać tutaj jako ! gh auth refresh -h github.com -s workflow, a wynik pojawi się w
tej rozmowie.

Push wyśle dwa commity, którigin:
- 41cc5a9: poprawka README i deployment.yaml;
- ae60f31: workflow GitHub

Workflow uruchomi się od raś jeszcze sekretów
(OPENSHIFT_SERVER, OPENSHIFT_TOKEN, OPENSHIFT_NAMESPACE), pierwszy przebieg zakończy
się błędem na kroku logowanrety i uruchomić go
ponownie przyciskiem Re-run w zakładce Actions.

Sautéed for 12s · done 21:40

❯ Mam błąd taki

Run oc login --token="***" \
error: Not a valid URL: par
"https://%20https:%2F%2Fapi.rm3.7wse.p1.openshiftapps.com:6443": invalid port
":%2F%2Fapi.rm3.7wse.p1.opest.
Error: Process completed with exit code 1.

Sekret OPENSHIFT_SERVER ma na początku spację (%20 w komunikacie to spacja). Pewnie
wkleiła się razem z adresem

Wartość zaczyna się od  httwięc oc nie rozpoznaje jej
jako adresu. Dokleja na początek własne https:// i powstaje coś takiego:
https://%20https://api.rm3.3

Jak naprawić

Opcja A, przez stronę: otwóand variables → Actions.
Przy OPENSHIFT_SERVER kliknij ołówek i wpisz dokładnie tę wartość, bez spacji i bez
nowej linii na końcu:
https://api.rm3.7wse.p1.openshiftapps.com:6443

Opcja B, z terminala przez gh (masz go zalogowanego):
gh secret set OPENSHIFT_SER-body"https://api.rm3.7wse.p1.openshiftapps.com:6443"

Potem w zakładce Actions kliknij Re-run all jobs.
Pozostałe dwa sekrety mogłyemem. Przy OPENSHIFT_TOKENspacja albo nowa linia da bSHIFT_NAMESPACE błąd projectnot found. Jeśli wolisz je j gh:gh secret set OPENSHIFT_NAMc --body "tomek371240-dev"oc get secret github-actionoken}' | base64 -d | gh
secret set OPENSHIFT_TOKEN -R tomek401273/hello-oc                              
Mogę też zmienić workflow tak, żeby sam obcinał spacje i nowe linie z sekretów. Wtedy ten błąd się nie powt                                                                                Brewed for 11s · done 21:44

recap: Konfigurujesz automa przez GitHub Actions przykażdym pushu, ale pierwszy przebieg padł przez spację w sekrecie OPENSHIFT_SERVER.
Popraw ten sekret na „httpspps.com:6443” i uruchom
workflow ponownie przez Re-fig)

❯ Zrób export całej historii