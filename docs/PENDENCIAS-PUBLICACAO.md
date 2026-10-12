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

## 4. Decisões que você precisa cravar

1. **Hospedagem** (muda os arquivos de deploy):
   - **Host gerenciado** (recomendado para teste rápido): API em
     Render/Fly/Railway + front web em Netlify/Vercel/Cloudflare Pages.
     Subdomínio grátis do próprio host, sem precisar comprar domínio agora.
   - **VPS + Caddy** (o que o backlog previa): mais controle, mais setup
     (docker-compose de produção + Caddyfile + HTTPS automático).
2. **Nome/domínio**: ainda provisório. Para o teste, dá para usar o subdomínio
   grátis do host. Domínio próprio fica para depois.

## 5. O que você vai configurar na máquina liberada (precisa de rede/credenciais)

Nenhum destes dá para fazer na máquina bloqueada:

- [ ] **Neon**: criar o projeto Postgres, copiar a connection string.
      Formato esperado pela API (Npgsql):
      `Host=...;Port=5432;Database=...;Username=...;Password=...;SSL Mode=Require;Trust Server Certificate=true`
      (o Neon dá uma URL `postgres://...`; converter para o formato
      chave=valor acima, ou usar o formato que o Npgsql aceitar).
- [ ] **Host da API**: criar o serviço, subir a imagem Docker, e definir as
      variáveis de ambiente:
      - `ConnectionStrings__DiarioTreino` = (connection string do Neon)
      - `Cors__OrigensPermitidas__0` = (URL do front publicado, ex.:
        `https://diario-treino.netlify.app`)
      - `Firebase__ProjectId` = `diario-treino-c21b6` (já é o default, confirmar)
      - `ASPNETCORE_ENVIRONMENT` = `Production`
- [ ] **Host do front web**: publicar o build web, apontando a API:
      `flutter build web --release --dart-define=API_BASE_URL=https://SUA-API/api/v1`
- [ ] **Firebase Auth**: adicionar o domínio de produção do front em
      *Authentication → Settings → Authorized domains*. Sem isso o login quebra
      fora do localhost.
- [ ] **Migrations no Neon**: aplicar o schema do zero. Se a API aplicar
      migrations no startup (ver item 6), basta subir a API apontando pro Neon.
      Senão, rodar manualmente:
      `dotnet ef database update --project backend/src/DiarioTreino.Infrastructure --startup-project backend/src/DiarioTreino.Api`
      com a connection string do Neon na variável de ambiente.

## 6. O que o Kiro ainda vai preparar (código, sem rede) — PENDENTE

Estes itens são código e serão feitos na branch `feat/pbi-04-publicacao`.
**Ainda NÃO estão prontos** no momento deste handoff (dependem da escolha de
hospedagem no item 4):

- [ ] **Dockerfile** da API (.NET 10, multi-stage build).
- [ ] **Migrations no startup**: a API aplica as migrations pendentes ao subir
      (para o Neon nascer pronto sem passo manual). Alternativa: passo de deploy.
- [ ] Arquivo de deploy conforme a hospedagem:
      - gerenciado: `render.yaml` (ou equivalente do host escolhido);
      - VPS: `docker-compose.prod.yml` + `Caddyfile`.
- [ ] Pipeline de deploy no CI (deploy automático a cada merge na `main`,
      conforme o critério do PBI-04) — opcional para o primeiro teste manual.

> ATENÇÃO: o Dockerfile e a aplicação de migrations **não foram testados** nesta
> máquina (sem Docker). O primeiro teste real será no deploy. Prever ao menos
> uma rodada de ajuste.

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
