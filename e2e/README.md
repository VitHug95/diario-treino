# E2E — fluxo principal (PBI-26)

Teste de ponta a ponta do caminho mais importante do app: **entrar, registrar um
treino e ver no gráfico**. Roda no navegador (Robot Framework + Browser library /
Playwright) contra uma **stack efêmera**, isolada da produção:

- **Postgres** real (service container do CI).
- **API .NET** apontada para esse Postgres e para o **Firebase Auth Emulator**.
- **Flutter web** buildado apontando para a API local e para o emulador.
- **Firebase Auth Emulator** no lugar do Firebase real — nenhuma credencial de
  produção é usada e nenhum dado de produção é tocado.

Por que o emulador: o login do app é `firebase_auth`, e a API valida o ID token
do Firebase. Para dirigir isso num navegador sem usar o projeto real, o padrão
de mercado é o **Firebase Local Emulator Suite**. A API aceita os tokens do
emulador quando `Firebase:AuthEmulatorHost` está definido (ver
`AutenticacaoFirebase`); em produção essa variável fica vazia e nada muda.

## Rodar no CI

O job `e2e` do `.github/workflows/ci.yml` sobe tudo e roda esta suíte a cada PR e
push na `main`. Em falha, publica os artefatos do Robot (`log.html`,
`report.html` e os screenshots) para inspeção.

## Rodar localmente

Pré-requisitos: Docker, Python 3.11+, Node (para o Playwright da Browser
library), .NET 10 e Flutter 3.29.3.

```bash
# 1. Postgres
docker run -d --name e2e-pg -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:17-alpine

# 2. Firebase Auth Emulator (precisa do firebase-tools e Java)
firebase emulators:start --only auth --project demo-diario-treino &

# 3. API apontada ao Postgres e ao emulador
cd backend
CONNECTIONSTRINGS__DIARIOTREINO="Host=localhost;Port=5432;Database=diariotreino;Username=postgres;Password=postgres" \
BANCO__APLICARMIGRACOESNOSTARTUP=true \
FIREBASE__PROJECTID=demo-diario-treino \
FIREBASE__AUTHEMULATORHOST=localhost:9099 \
ASPNETCORE_URLS=http://localhost:8080 \
dotnet run --project src/DiarioTreino.Api &

# 4. Front apontado à API local e ao emulador
cd app
cp lib/firebase_options.e2e.dart lib/firebase_options.dart   # só no ambiente de E2E
flutter build web --release \
  --dart-define=API_BASE_URL=http://localhost:8080/api/v1 \
  --dart-define=USE_AUTH_EMULATOR=true \
  --dart-define=AUTH_EMULATOR_HOST=localhost \
  --dart-define=AUTH_EMULATOR_PORT=9099
python -m http.server 8000 --directory build/web &

# 5. Robot
cd e2e
pip install -r requirements.txt
rfbrowser init           # baixa o navegador do Playwright
robot --variable BASE_URL:http://localhost:8000 --outputdir resultados suites/
```

## Estrutura

```
e2e/
  requirements.txt          dependências Python (robotframework + Browser)
  resources/
    comum.resource          keywords de alto nível do app (login, registrar, etc.)
  suites/
    fluxo_principal.robot    o caminho entrar -> registrar -> ver no gráfico
```
