# Deploy automático da API (Fly.io) via CI

A partir desta configuração, **a API é publicada automaticamente** no Fly a cada
merge na `main`, logo após o CI passar (build + testes). O front (web) já era
publicado automaticamente pelo Netlify; agora o back acompanha.

Isso resolve o problema que causou o bug "PBI-33 continuava quebrado": antes, o
merge atualizava só o front (Netlify), e a API no Fly dependia de um
`flyctl deploy` manual — fácil de esquecer.

## Como funciona (`.github/workflows/ci.yml`)

- Jobs `backend` e `frontend`: build + testes (como antes).
- Job novo `deploy-api`:
  - só roda **depois** de `backend` e `frontend` passarem (`needs`);
  - só em **push na `main`** (`if: github.event_name == 'push' && github.ref == 'refs/heads/main'`) — nunca em Pull Request, nunca com teste vermelho;
  - roda `flyctl deploy --remote-only` na pasta `backend` (usa o `backend/Dockerfile` e o `backend/fly.toml`);
  - o build da imagem acontece no builder remoto do Fly (`--remote-only`), não precisa de Docker no runner;
  - `concurrency: deploy-api` com `cancel-in-progress: false` para um deploy nunca ser cortado no meio.

## O QUE VOCÊ PRECISA FAZER UMA VEZ: criar o secret FLY_API_TOKEN

O workflow lê `secrets.FLY_API_TOKEN`. Sem esse secret, o job de deploy falha
(mas o build/testes continuam valendo). Passos:

1. Gerar um token de deploy no Fly (na máquina com o `flyctl` logado):
   ```
   flyctl tokens create deploy --app diario-treino-api
   ```
   Copie o token inteiro que ele imprime (começa com `FlyV1 ...`).

   > Observação: use um token **de deploy** (escopo do app), não o token pessoal
   > da conta. Assim ele só pode publicar este app.

2. No GitHub, criar o secret do repositório:
   - Repo → **Settings** → **Secrets and variables** → **Actions** →
     **New repository secret**.
   - Name: `FLY_API_TOKEN`
   - Secret: cole o token do passo 1.
   - Salvar.

3. Pronto. No próximo merge na `main`, o deploy roda sozinho. Acompanhe em
   **Actions** (job "Deploy API (Fly.io)") ou com `flyctl status --app diario-treino-api`.

## Como testar sem esperar um merge

- Faça o merge deste PR na `main`. Como o merge é um push na `main`, o próprio
  merge já dispara o primeiro deploy automático. Confira em Actions.
- Se falhar por falta do secret, crie o `FLY_API_TOKEN` (acima) e re-rode o job
  em Actions ("Re-run jobs").

## Segurança

- O token fica **só** no secret do GitHub, nunca no código. Rotacione-o se
  vazar: `flyctl tokens revoke <id>` e gere outro.
- O deploy nunca roda em PR (inclusive de forks), só em push na `main` já
  revisado e com CI verde.
- Migrations: a API aplica as pendentes no startup em produção
  (`MigracoesStartup`), então o deploy já deixa o banco em dia.
