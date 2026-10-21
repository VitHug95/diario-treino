# E2E — fluxo principal (PBI-26)

Teste de ponta a ponta do caminho mais importante do app: **entrar, registrar um
treino e ver no gráfico**, contra uma **stack efêmera** isolada da produção:

- **Postgres** real (service container do CI).
- **API .NET** apontada para esse Postgres e para o **Firebase Auth Emulator**.
- **Firebase Auth Emulator** no lugar do Firebase real — nenhuma credencial de
  produção é usada e nenhum dado de produção é tocado.

## Onde mora o teste

O teste **não** fica mais aqui. Ele foi migrado de Robot Framework + Playwright
para **`integration_test` do Flutter**, em `app/integration_test/`:

- `app/integration_test/fluxo_pbi26_test.dart` — o fluxo entrar → registrar →
  ver no progresso.
- `app/test_driver/integration_test.dart` — driver do `flutter drive`.

### Por que a migração

O Flutter web usa **CanvasKit** (o renderer HTML foi removido no Flutter 3.29).
Com CanvasKit, os campos de texto são desenhados em canvas e o `<input>` da
árvore de semântica é um proxy que o framework recria/limpa — preencher por fora
(via DOM, como fazem Robot/Playwright) não alimenta o `TextEditingController` de
forma confiável. O `integration_test` dirige a **árvore de widgets**
(`tester.enterText`), então digita de verdade. É a ferramenta oficial do Flutter
para este tipo de teste.

O app entra já autenticado pelo atalho de login do boot (`main.dart`, só quando
`USE_AUTH_EMULATOR=true`), que provisiona um usuário de teste no emulador — o
teste não precisa digitar na tela de login.

## O que sobra nesta pasta

Só o `firebase.json`, que configura o **Firebase Auth Emulator** (porta 9099). O
passo "Subir o Auth Emulator" do job `e2e` roda `firebase emulators:start` a
partir daqui.

## Rodar no CI

O job `e2e` do `.github/workflows/ci.yml` sobe Postgres + emulador + API e roda o
`integration_test` com `flutter drive` + ChromeDriver (Chrome headless). Em
falha, publica os logs dos serviços (`api.log`, `emulator.log`,
`chromedriver.log`).

## Rodar localmente

Pré-requisitos: Docker, Node + `firebase-tools` + Java (emulador), .NET 10,
Flutter 3.29.3, Chrome + ChromeDriver.

```bash
# 1. Postgres
docker run -d --name e2e-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:17-alpine

# 2. Firebase Auth Emulator (a partir desta pasta e2e/, que tem o firebase.json)
cd e2e && firebase emulators:start --only auth --project demo-diario-treino &

# 3. API apontada ao Postgres e ao emulador
cd backend
CONNECTIONSTRINGS__DIARIOTREINO="Host=localhost;Port=5432;Database=diariotreino;Username=postgres;Password=postgres" \
BANCO__APLICARMIGRACOESNOSTARTUP=true \
FIREBASE__PROJECTID=demo-diario-treino \
FIREBASE__AUTHEMULATORHOST=localhost:9099 \
ASPNETCORE_URLS=http://localhost:8080 \
dotnet run --project src/DiarioTreino.Api &

# 4. ChromeDriver
chromedriver --port=4444 &

# 5. integration_test
cd app
cp lib/firebase_options.e2e.dart lib/firebase_options.dart   # só no ambiente de E2E
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/fluxo_pbi26_test.dart \
  -d web-server --browser-name=chrome --headless \
  --dart-define=API_BASE_URL=http://localhost:8080/api/v1 \
  --dart-define=TREINO_AO_VIVO=false \
  --dart-define=USE_AUTH_EMULATOR=true \
  --dart-define=AUTH_EMULATOR_HOST=localhost \
  --dart-define=AUTH_EMULATOR_PORT=9099
```
