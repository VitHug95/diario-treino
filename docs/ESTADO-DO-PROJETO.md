# Estado do projeto — Diário de Treino

Documento de passagem: tudo que já foi feito até aqui (telas, front, back e
publicação). Base: histórico Git (`main`), código em `app/` e `backend/`, e o
`BACKLOG.md`.

Data do levantamento: 14/10/2026 (atualizado após progresso completo, tela
inicial e carga do catálogo).

---

## 1. Visão geral

- **App:** registrar treinos (inclusive dias depois) e acompanhar a evolução por
  exercício. Modo atleta primeiro; estrutura pronta para o modo educador.
- **Stack back-end:** .NET 10, Minimal APIs, EF Core + Npgsql, FluentValidation,
  Serilog. Monólito em camadas (`Domain → Application → Infrastructure/Api`).
- **Stack front-end:** Flutter (web), Riverpod, go_router, Dio, firebase_auth,
  fl_chart. Organização feature-first (`core/features/shared/theme`).
- **Identidade:** Firebase Auth (token). **Autorização:** no Postgres via
  `IControleAcesso`. **Banco:** Postgres (Neon em produção).

---

## 2. Publicação (PBI-04) — NO AR

| Camada | Serviço | Endereço | Observações |
|---|---|---|---|
| API | Fly.io | `https://diario-treino-api.fly.dev` | container Docker, região `gru`, HTTPS, health em `/health` |
| Front web | Netlify | `https://diario-treino.netlify.app` | build do Flutter 3.29.3, deploy automático do GitHub |
| Banco | Neon (Postgres) | — | connection string só em segredo do Fly |
| Auth | Firebase | projeto `diario-treino-c21b6` | domínio do Netlify autorizado |

**Validado em produção:**
- `/health` e `/health/ready` respondendo 200 (conexão com o Neon confirmada).
- Migrations aplicadas automaticamente no startup da API em produção.
- CORS liberado só para o domínio do Netlify (`Cors__OrigensPermitidas__0`).
- Fluxo real testado no navegador: login → criar ficha → registrar treino.

**Arquivos de deploy:**
- `backend/Dockerfile` (multi-stage .NET 10; publish sem `--no-restore`).
- `backend/fly.toml` (porta 8080, `auto_stop_machines`, health `/health`).
- `netlify.toml` na raiz + `app/netlify.toml` (instalam o Flutter e buildam o web).
- `backend/src/DiarioTreino.Api/Infraestrutura/MigracoesStartup.cs`.

**Segredos no Fly:** `ConnectionStrings__DiarioTreino`, `Firebase__ProjectId`,
`Cors__OrigensPermitidas__0`.

**Pendências conhecidas da PBI-04 (não bloqueiam o uso):**
- ~~Deploy automático da API no CI~~ — FEITO: job `deploy-api` no `ci.yml` publica a API no Fly a cada merge na `main` (após o CI passar). Falta só criar o secret `FLY_API_TOKEN` no GitHub uma vez (ver `docs/DEPLOY-AUTOMATICO.md`).
- Domínio próprio (hoje usa os subdomínios grátis `*.fly.dev` / `*.netlify.app`).
- Backup do banco (PBI-05) ainda não feito.
- Ruído de log cosmético na API (`libgssapi_krb5.so.2`) — não afeta a conexão.
- Resetar a senha do role do Neon (foi digitada em texto no chat durante o setup).

---

## 3. PBIs concluídas

Pela ordem do backlog. "✅" = na `main` e publicado.

| PBI | Título | Status | Camada |
|---|---|---|---|
| PBI-01 | Estrutura da solução back-end | ✅ | back |
| PBI-02 | Estrutura do app Flutter | ✅ | front |
| PBI-03 | Banco e migrations iniciais | ✅ | banco |
| PBI-04 | Publicação em produção | ✅ (com pendências menores da seção 2) | infra |
| PBI-06 | Autenticação na API (Firebase) | ✅ | back |
| PBI-07 | Controle de acesso centralizado | ✅ | back |
| PBI-08 | Login e cadastro no app | ✅ | front |
| PBI-10 | Buscar exercício no catálogo | ✅ | back + front |
| PBI-11 | Criar exercício próprio | ✅ | back + front |
| — | Design system (temas A/B, tipografia, navegação) | ✅ | front |
| PBI-12 | Criar fichas de treino | ✅ | back + front |
| PBI-13 | Montar exercícios da ficha | ✅ | back + front |
| PBI-14 | Definir alvos do exercício na ficha | ✅ | back + front |
| PBI-15 | Registrar sessão a partir da ficha | ✅ | back + front |
| PBI-16 | Editar séries durante o registro | ✅ | front |
| PBI-17 | Adicionar exercício fora da ficha | ✅ | front |
| PBI-18 | Ver, editar e excluir sessão | ✅ | back + front |
| PBI-20 | Gráfico de evolução por exercício | ✅ | back + front |
| PBI-21 | Observação no ponto do gráfico | ✅ | back + front |
| PBI-22 | Sessões do período (lista) | ✅ | back + front |
| PBI-23 | Tela inicial (fichas + rotação A→B→C) | ✅ | front |
| PBI-32 | UX do seletor + largura 600px no web | ✅ | front |
| PBI-33 | Bug sessão "salva" vazia | ✅ | front |
| — | Carga do catálogo: 89 exercícios globais | ✅ | banco |
| — | Deploy automático da API no CI (Fly) | ✅ | infra |
| PBI-26 | Teste E2E do fluxo principal | 🟡 parcial (fluxo via `flutter test`; Robot pendente) | teste |

**Ainda NÃO feitas:** PBI-05 (backup), PBI-09 (primeiro acesso), PBI-19 (treino
livre), PBI-24 (tema claro/escuro completo), PBI-25 (perfil/conta), PBI-26 (E2E
Robot completo), PBI-31 (filtro por membro / ADR-10), PBI-34 (métrica flexível no
registro), PBI-35 (cronograma semanal) e todo o incremento 2 (cardio: PBI-27 a
PBI-30).

---

## 4. Telas do app (front) — o que existe hoje

Caminhos em `app/lib/features/`.

### Autenticação (`auth/`)
- **`login_screen.dart`** — login com e-mail/senha e Google; "esqueci a senha".
- **`cadastro_screen.dart`** — cadastro com nome, e-mail e senha.
- **`auth_service.dart`** — estado de autenticação (Riverpod), chama `GET /me`.
- Após login, o go_router redireciona para a tela inicial.

### Início (`inicio/`)
- **`inicio_screen.dart`** — **implementado (PBI-23).** Saudação, botão de tema,
  faixa semanal (dias treinados), cartão "Próximo da sequência" com a ficha
  seguinte à última registrada (rotação A→B→C) e lista de fichas com a data da
  última vez; tocar abre o registro daquela ficha. `inicio_logica.dart` tem a
  lógica (proximaFicha, ultimaVezPorFicha, diasDaSemana) coberta por testes.

### Catálogo de exercícios (`catalogo/`)
- **`catalogo_screen.dart`** — busca por nome (debounce), filtro por modalidade
  (Todos/Força/Isometria/Cardio), selo "Meu", FAB "Novo", estado vazio sugere criar.
- **`selecionar_exercicio_screen.dart`** — seletor reaproveitado na montagem de
  ficha (retorna id) e no registro (retorna o exercício completo). **Estado vazio
  aqui NÃO oferece criar** (lacuna de UX já identificada).
- **`criar_exercicio_screen.dart`** — formulário completo: nome, grupo (texto
  livre), tipo (força/isometria/cardio), métricas de intensidade/volume sugeridas
  pelo tipo, prévia, validação de nome duplicado (409).

### Fichas (`fichas/`)
- **`fichas_screen.dart`** — plano ativo com fichas (criar, renomear, arquivar);
  botão "Registrar treino" por ficha; adicionar/reordenar/remover exercícios.
- **`editar_alvos_screen.dart`** — alvos do exercício na ficha (séries, carga/reps,
  descanso, resumo em frase).

### Sessão / registro (`sessao/`)
- **`registrar_sessao_screen.dart`** — registrar treino a partir da ficha; data
  (hoje por padrão, aceita passado, bloqueia futuro além de amanhã); séries
  pré-preenchidas pela última sessão ou pelos alvos; editar/adicionar/remover
  séries; adicionar exercício fora da ficha; observação do dia.
- **`detalhe_sessao_screen.dart`** — ver sessão (séries por exercício, plano ao
  lado, "não realizado"); editar; excluir com confirmação.

### Progresso (`progresso/`)
- **`progresso_screen.dart`** — **implementado (PBI-20/21/22).** Seletor de
  exercício (dropdown dos que têm histórico), gráfico de evolução `fl_chart`
  (força = maior carga + reps; isometria = tempo), pontos com observação
  destacados (toque mostra data/valor/nota e "Abrir sessão"), resumo do período
  e, abaixo, a lista de sessões do período com filtro 15/30/90 dias.
- **`progresso_models.dart` / `progresso_repository.dart`** — modelos e acesso à
  API de progresso (providers Riverpod). `fl_chart` fixado em 1.0.0 (a 1.1.0 não
  compila no Flutter 3.29.3).

### Navegação (`core/rotas/`)
- `app_router.dart` — go_router com casca de abas (Início / Fichas / Progresso) e
  redirecionamento por login. Catálogo e criação ficam empilhados sobre Início;
  registro de sessão empilhado sobre Fichas.
- `shell_navegacao.dart` — barra inferior com as 3 abas.

### Tema (`theme/`)
- `app_colors.dart`, `app_theme.dart`, `app_typography.dart`, `theme_tokens.dart`
  — design system (temas claro/escuro por tokens; cores nunca escritas direto no
  widget). Alternância de tema existe na Início; a tela de Perfil (PBI-25) e a
  persistência completa (PBI-24) ainda faltam.

---

## 5. Back-end — endpoints da API

Prefixo `/api/v1`, todos exigem token do Firebase (exceto health). Recurso de
outro usuário responde **404** (regra do `IControleAcesso`).

### Infra
- `GET /health` — liveness (não toca no banco).
- `GET /health/ready` — readiness (confirma conexão com o banco).

### Perfil (PBI-06)
- `GET /me` — perfil e papéis; cria o usuário no primeiro acesso (papel ATLETA).

### Catálogo (PBI-10, PBI-11)
- `GET /metricas` — métricas disponíveis.
- `GET /exercicios` — catálogo global + exercícios do usuário (busca + modalidade).
- `POST /exercicios` — cria exercício próprio.

### Planos e fichas (PBI-12, PBI-13, PBI-14)
- `GET /planos/ativo` — plano ativo com as fichas.
- `POST /planos` — cria plano ativo (idempotente).
- `POST /planos/{id}/treinos` — adiciona ficha ao plano.
- `GET /treinos/{id}` — detalhe da ficha com exercícios.
- `PUT /treinos/{id}` — renomeia/edita ficha.
- `DELETE /treinos/{id}` — arquiva ficha (histórico preservado).
- `POST /treinos/{id}/exercicios` — adiciona exercício à ficha.
- `PUT /treinos/{id}/exercicios/ordem` — reordena.
- `DELETE /treinos/{id}/exercicios/{treinoExercicioId}` — remove da ficha.
- `PUT /treinos/{id}/exercicios/{treinoExercicioId}/alvos` — define os alvos.

### Sessões (PBI-15, PBI-18, PBI-22)
- `GET /treinos/{id}/rascunho-sessao` — rascunho pré-preenchido para registrar.
- `POST /sessoes` — grava a sessão com as séries.
- `GET /sessoes/{id}` — detalhe da sessão.
- `PUT /sessoes/{id}` — edita a sessão.
- `DELETE /sessoes/{id}` — exclui a sessão.
- `GET /sessoes?de=&ate=` — sessões do período (lista da aba Progresso).

### Progresso (PBI-20, PBI-21)
- `GET /progresso/exercicios` — exercícios com histórico (seletor do gráfico).
- `GET /progresso/exercicios/{id}?de=&ate=` — série de evolução; cada ponto traz
  valor, reps (força), `sessaoId` e a observação do dia.

### Camadas (projetos .NET)
- `DiarioTreino.Domain` — entidades e regras, sem dependência de EF/HTTP/Firebase.
- `DiarioTreino.Application` — casos de uso e serviços (`ServicoPerfil`,
  `ServicoCatalogo`, `IControleAcesso`, etc.).
- `DiarioTreino.Infrastructure` — EF Core, repositórios, DbContext, migrations.
- `DiarioTreino.Api` — Minimal APIs, autenticação, middleware, Problem Details.

---

## 6. Banco de dados

- **ORM:** EF Core + Npgsql. **Produção:** Neon.
- **Migrations versionadas:**
  - `20261002204136_InitialCreate` — todas as tabelas do MER, constraints,
    índices, `CHECK`s e seed (métricas + catálogo global do protótipo).
  - `20261006183645_HabilitaUnaccent` — extensão `unaccent` (busca sem acento).
  - `20261014143254_CatalogoExerciciosCompleto` — carga de 89 exercícios globais
    (7 genéricos antigos ficam inativos, não apagados).
- **Aplicação:** automática no startup da API em produção
  (`Banco:AplicarMigracoesNoStartup`, liga sozinho em Production).
- **Membro/músculo:** o exercício é classificado por `membro_id` (obrigatório ao
  criar) e `musculo_id` opcional, com as tabelas `membro` (8) e `musculo` (15)
  do MER (PBI-31 / ADR-10, **concluído**). O antigo texto livre `grupo_muscular`
  foi removido na etapa 4 (`MembroMusculoEtapa4RemoveGrupo`).

---

## 7. Testes e CI

### Testes de front (`app/test/`)
`catalogo_screen_test`, `criar_exercicio_screen_test`, `editar_alvos_test`,
`fichas_screen_test`, `inicio_screen_test`, `login_screen_test`,
`sessao_edicao_test`.

### Testes de back (`backend/tests/`)
- **Integração** (Testcontainers + Postgres real): controle de acesso, esquema do
  banco, exercícios, exercícios da ficha, health, `/me`, planos, sessões (CRUD e
  registro).
- **Unitários:** acesso, catálogo, planejamento.

### CI (`.github/workflows/ci.yml`)
- Em todo push/PR na `main`: build .NET (sem warnings — `TreatWarningsAsErrors`),
  testes unitários e de integração; e no front: `flutter analyze`, `flutter test`,
  `flutter build web`.
- O CI publica a API no Fly automaticamente a cada merge na `main` (job
  `deploy-api`, requer o secret `FLY_API_TOKEN` — ver `docs/DEPLOY-AUTOMATICO.md`);
  o front tem deploy automático pelo Netlify ao mergear na `main`.

---

## 8. Convenções (resumo do steering)

- **Back:** namespace `DiarioTreino`; regra de dependência das camadas; erros em
  Problem Details; logs sem token nem observação da sessão; toda leitura/escrita de
  dado de atleta passa por `IControleAcesso` (404 para outro usuário).
- **Front:** feature-first; nenhuma cor escrita direto no widget (só tokens);
  acessibilidade (semantics + rótulos em campos e botões).
- **Definition of Done:** revisado e na `main`; CI verde; migration quando mudar o
  banco; endpoint novo com teste do caso 404; telas conferidas nos dois temas.

---

## 9. Resumo em uma frase

O MVP de registro de treino está **publicado e funcionando** (login → tela inicial
com rotação de fichas → registrar/editar/excluir sessão → progresso com gráfico de
evolução, observação no ponto e lista de sessões), com API no Fly, front no Netlify
e banco no Neon, e deploy automático no CI. O catálogo tem 89 exercícios globais.
Faltam, do incremento 1: primeiro acesso (PBI-09), treino livre (PBI-19),
perfil/conta (PBI-25), tema completo (PBI-24), E2E Robot (PBI-26), backup (PBI-05) e
filtro por membro (PBI-31). O incremento 2 (cardio) não começou.

---

## 10. Ponto de retomada

> ⚠️ **Histórico (12/10/2026).** O snapshot abaixo ficou para trás: PBI-33,
> PBI-22 (front), PBI-23A, deploy automático, **PBI-20, PBI-21 e a carga do
> catálogo (89 exercícios)** já foram feitos e mergeados depois dele. **Próximo
> passo atual: PBI-25 (Perfil e conta)** — ver dados, sair e excluir conta;
> decisões em aberto do "excluir conta" (apagar no Firebase via cliente vs Admin
> SDK; hard vs soft delete no Postgres) a confirmar com o PO. Mantido abaixo só
> como registro.

Atualizado ao fim da sessão de 12/10/2026.

### O que foi feito nesta leva
- **PBI-32** (criar exercício no seletor + largura 600px no web): mergeada na `main`.
- **PBI-23 parte B** (tela inicial lista fichas e inicia o registro): mergeada na `main`.
- **PBI-22 (back)** `GET /sessoes?de=&ate=` (listar sessões do período): **mergeada na `main`**, CI verde (testes de integração passaram no runner).
- **PBI-33** (bug) registrada no BACKLOG.

### Pendências de git
- Branch `docs/pbi-33-bug-salvar-treino` (só o registro do bug no BACKLOG) **ainda não mergeada**. PR:
  `https://github.com/VitHug95/diario-treino/pull/new/docs/pbi-33-bug-salvar-treino`

### Próximo passo (prioridade): corrigir a PBI-33
Bug: ao salvar o treino aparece "Treino registrado", mas a sessão é gravada **vazia**.
**Causa raiz confirmada no código:** exercício sem alvos (PBI-14) e sem histórico gera
rascunho sem séries (`ServicoSessao.MontarRascunhoAsync`), abre como "Não realizado"
(`ExercicioEdicao.doRascunho`: `realizado: e.series.isNotEmpty`), e a regra do back-end
não grava série de exercício sem séries → sessão vazia, mas com confirmação de sucesso.

Correção planejada (só front: `registrar_sessao_screen.dart` e `sessao_edicao.dart`):
1. Exercício sem séries sugeridas abre com **uma série em branco** para preencher (como já é feito em `ExercicioEdicao.foraDaFichaDoCatalogo`), em vez de só "Não realizado".
2. **Barrar o salvamento de sessão totalmente vazia** (nenhuma série em nenhum exercício), com aviso.
3. Confirmação "Treino registrado" só após o `201` de sucesso.
4. Testes: sessão com séries + leitura posterior; e tentativa de salvar sessão vazia.

### Sequência depois da PBI-33
1. **PBI-22 (front)** — lista de sessões do período na aba Progresso, consumindo o `GET /sessoes` já pronto.
2. **PBI-23 parte A** — "próximo da sequência" real + "data da última vez" de cada ficha (agora dá, com o histórico de sessões).
3. **PBI-31** — classificar exercícios por membro (F+A+B, em 4 etapas conforme o ADR-10/MER).

### Observação de infra (quando for conveniente)
O Netlify reaproveita cache de build agressivamente (`if [ ! -d "$HOME/flutter" ]` no `netlify.toml`), o que já fez o site servir versão antiga após merge. Workaround atual: "Clear cache and deploy site" no painel. Vale ajustar o build para ser confiável sem limpeza manual.

---

## 11. Follow-ups anotados (não bloqueiam, pegar quando der)

> A seção 10 acima é um snapshot de 12/10 e já ficou para trás (PBI-33, PBI-22
> front, PBI-23A, deploy automático e PBI-20 back já foram feitos depois dela).
> Esta seção 11 acumula os pequenos follow-ups combinados desde então.

- **Teste da virada de semana (faixa semanal da tela inicial):** a faixa de dias
  (`InicioLogica.diasDaSemana`) sempre mostra a semana corrente e "zera" os
  checks ao virar a semana — comportamento correto e desejado (confirmado com o
  PO). Hoje recalcula no rebuild da tela (não ao vivo à meia-noite de domingo, o
  que é aceitável). Falta um teste unitário específico passando uma data de
  referência de outra semana para `diasDaSemana` e confirmando que os checks da
  semana anterior não aparecem. A lógica já tem teste com data fixa; só não há o
  caso "troca de semana". Rápido de adicionar.
- **Cache do Netlify** (ver observação de infra acima).
- **E2E completo (PBI-26)**: hoje há um teste de fluxo via `flutter test`
  (`app/test/fluxo_registro_test.dart`); o Robot + Browser contra a stack real
  continua como meta, depende de decidir o modo de teste de autenticação.
