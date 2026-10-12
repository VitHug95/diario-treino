# Pendências para publicar (PBI-04) — handoff para a máquina com rede liberada

Documento de passagem. O objetivo é **publicar o Diário de Treino** para o
cliente testar o fluxo de registro de treino (Sprints 1–3 já prontas e na
`main`). Esta máquina atual tem Docker/rede bloqueados, então nada que dependa
de rede foi testado aqui — a validação real acontece na máquina liberada.

Data do handoff: ver `git log`. Branch deste documento: `feat/pbi-04-publicacao`.

---

## 1. Onde o projeto está

- **Sprints 1, 2 e 3 completas e mergeadas na `main`.** O app cobre: login
  (Firebase), catálogo de exercícios, criar exercício, fichas, alvos, registrar
  treino (com pré-preenchimento, editar séries, exercício fora da ficha) e
  ver/editar/excluir sessão.
- Último merge: PR #21 (PBI-18 front). `main` em dia com `origin/main`.
- **Falta publicar (PBI-04).** Nunca foi publicado; só roda local.

## 2. Bug encontrado e já corrigido (CORS)

Ao rodar o app no navegador, as telas que falam com a API davam
"Não foi possível carregar as fichas". Causa: **a API não tinha CORS**, então o
navegador bloqueava as chamadas do app web (origem diferente da API).

- **Correção já feita** em `backend/src/DiarioTreino.Api/Program.cs` e
  `appsettings.json` (chave `Cors:OrigensPermitidas`).
- Em desenvolvimento, a API libera qualquer `localhost`.
- Em produção, as origens vêm da variável de ambiente
  `Cors__OrigensPermitidas__0` (o domínio do front publicado).
- **Decisão a tomar:** esse fix pode virar um PR próprio (`fix/cors-api`) e ir
  para a `main` antes do PBI-04, ou seguir junto na branch de publicação. Ele é
  independente e resolve o bug mesmo sem publicar.

## 3. Por que não dá para testar nesta máquina

O app precisa de **API + Postgres** no ar ao mesmo tempo. O Postgres local sobe
por Docker (`backend/docker-compose.yml`, porta 5432), e o Docker está
bloqueado aqui (WSL quebrado + rede). Sem banco, a API responde mas falha ao
consultar. Por isso o caminho de teste do cliente é a **publicação** (Neon faz o
papel do banco), não o ambiente local.

## 4. Hospedagem escolhida

**Fly.io (API) + Netlify (front web) + Neon (banco Postgres).**

- Os **dados ficam no Neon** (banco gerenciado). Fly e Netlify são
  descartáveis/reconstruíveis sem perder dados.
- Plano free do Fly pode "adormecer" a API por inatividade: a 1ª chamada após
  ociosidade demora alguns segundos a dezenas de segundos para a API acordar.
  Isso é lentidão pontual, **não** perda de dados. Para eliminar: subir
  `min_machines_running = 1` no fly.toml (pode ter custo), ou plano pago baixo.
- Nome/domínio ainda provisório: usar os subdomínios grátis
  (`*.fly.dev`, `*.netlify.app`). Domínio próprio depois.

Arquivos de deploy já versionados nesta branch:
- `backend/Dockerfile` — imagem da API (.NET 10, multi-stage).
- `backend/fly.toml` — config do Fly (porta 8080, health check em `/health`).
- `app/netlify.toml` — build e publish do front (SPA redirect incluso).

## 5. Passo a passo na máquina liberada (precisa de rede/credenciais)

### 5.1 Neon (banco)
- [ ] Criar conta/projeto no Neon e um banco (ex.: `diariotreino`).
- [ ] Copiar a connection string. O Neon dá uma URL `postgres://user:senha@host/db?sslmode=require`.
      Converter para o formato que o Npgsql espera:
      `Host=HOST;Database=DB;Username=USER;Password=SENHA;SSL Mode=Require;Trust Server Certificate=true`

### 5.2 Fly (API)
- [ ] Instalar o `flyctl` e `fly auth login`.
- [ ] Na pasta `backend/`, ajustar `app` no `fly.toml` para um nome único.
- [ ] `fly launch --no-deploy` (ou `fly apps create <nome>`), confirmando a região `gru`.
- [ ] Definir os segredos (NÃO vão no git):
      ```
      fly secrets set ConnectionStrings__DiarioTreino="Host=...;Database=...;Username=...;Password=...;SSL Mode=Require;Trust Server Certificate=true"
      fly secrets set Cors__OrigensPermitidas__0="https://SEU-FRONT.netlify.app"
      fly secrets set Firebase__ProjectId="diario-treino-c21b6"
      ```
- [ ] `fly deploy` (usa o Dockerfile). No 1º start, a API aplica as migrations
      no Neon automaticamente (produção). Conferir nos logs: `fly logs`.
- [ ] Testar: `https://SEU-APP.fly.dev/health` deve responder 200.

### 5.3 Netlify (front)
- [ ] No `app/netlify.toml`, trocar a URL do `--dart-define=API_BASE_URL` pela
      URL real da API no Fly (`https://SEU-APP.fly.dev/api/v1`).
- [ ] O build do Netlify precisa do Flutter (a imagem padrão não traz). Opções:
      instalar o Flutter no `command` (git clone do SDK) ou usar um plugin/imagem
      com Flutter. Documentar a escolha ao configurar.
- [ ] Conectar o repo no Netlify com base `app/` e publicar. Anotar a URL
      `https://SEU-FRONT.netlify.app`.
- [ ] Confirmar que a URL do front bate com o `Cors__OrigensPermitidas__0` do Fly
      (senão o navegador bloqueia por CORS).

### 5.4 Firebase
- [ ] Firebase Console → Authentication → Settings → Authorized domains →
      adicionar `SEU-FRONT.netlify.app`. Sem isso o login quebra fora do localhost.

### 5.5 Teste local completo (opcional, agora dá — Docker liberado)
- [ ] `docker compose up -d` em `backend/` (sobe o Postgres local).
- [ ] `dotnet run --project backend/src/DiarioTreino.Api/DiarioTreino.Api.csproj`
- [ ] `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5289/api/v1`
      — com o CORS já corrigido, as fichas devem carregar.

## 6. O que o Kiro JÁ preparou nesta branch (código, sem rede)

- [x] **CORS** na API (`Program.cs` + `appsettings.json`). Build 0/0.
- [x] **Migrations no startup** em produção
      (`src/DiarioTreino.Api/Infraestrutura/MigracoesStartup.cs`, chamado no
      `Program.cs`). Controlado por `Banco:AplicarMigracoesNoStartup`
      (padrão: liga em Production). Build 0/0.
- [x] **Dockerfile** da API (`backend/Dockerfile`, multi-stage net10.0).
- [x] **fly.toml** (`backend/fly.toml`).
- [x] **netlify.toml** (`app/netlify.toml`).

Ainda em aberto (opcional para o 1º teste manual):
- [ ] Deploy automático no CI a cada merge na `main` (critério do PBI-04).

> ATENÇÃO: o **Dockerfile**, o **fly.toml** e a **aplicação de migrations** NÃO
> foram testados nesta máquina (Docker bloqueado). O primeiro teste real será no
> `fly deploy`. Prever ao menos uma rodada de ajuste (caminhos, porta, SDK).

## 7. Ordem sugerida na máquina liberada

1. `git pull` na `main` (e na branch `feat/pbi-04-publicacao` se o preparo do
   item 6 já tiver sido feito e pushado).
2. Decidir a hospedagem (item 4) e avisar o Kiro para gerar os arquivos de
   deploy certos, se ainda não existirem.
3. Criar o projeto no Neon; guardar a connection string.
4. Verificar o Docker funcionando: `docker compose up -d` em `backend/` sobe o
   Postgres local — bom para um teste local completo antes de publicar
   (agora com o CORS corrigido, o app web deve carregar as fichas).
5. Subir a API no host com as variáveis do item 5.
6. Publicar o front web com `--dart-define=API_BASE_URL=...`.
7. Liberar o domínio no Firebase (item 5).
8. Testar o fluxo no navegador: login → criar ficha → registrar treino → ver
   treino. Esse é o incremento para mandar ao cliente.

## 8. Critérios de aceite do PBI-04 (do BACKLOG)

- Domínio apontando para o host (ou subdomínio do host no teste).
- HTTPS (automático no host gerenciado; Caddy na VPS).
- API em container, separada de outros serviços.
- Banco de produção no Neon; connection string só em variável de ambiente.
- Deploy automático a cada merge na `main` (pode ficar para um segundo momento).
- Reinício da API se o `/health` falhar (o host gerenciado cobre; na VPS,
  healthcheck no compose).

## 9. Observações de segurança

- A connection string do Neon e qualquer segredo ficam **só nas variáveis de
  ambiente do host** — nunca commitados. O `firebase_options.dart` versionado é
  OK (credenciais web do Firebase são públicas por design).
- CORS em produção deve listar **apenas** o domínio do front, não liberar geral.
