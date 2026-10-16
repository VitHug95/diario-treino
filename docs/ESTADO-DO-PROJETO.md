# Estado do projeto — Diário de Treino

Documento de passagem: o que existe hoje (telas, front, back, banco e publicação) e o
que falta. O detalhe de cada entrega, PR por PR, está em
[HISTORICO-DE-ALTERACOES.md](HISTORICO-DE-ALTERACOES.md); o contrato da API, no
[MAS](MAS.md) (seção 12); as PBIs, no [BACKLOG](BACKLOG.md).

Data do levantamento: 16/10/2026, depois do PR #91 (PBI-72).

---

## 1. Visão geral

- **App:** registrar treinos (inclusive dias depois) e acompanhar a evolução por
  exercício. Modo atleta primeiro; estrutura pronta para o modo educador.
- **Back-end:** .NET 10, Minimal APIs, EF Core + Npgsql, FluentValidation, Serilog.
  Monólito em camadas (`Api → Application → Domain`, `Infrastructure → Application`).
- **Front-end:** Flutter (web), Riverpod, go_router, Dio, firebase_auth, fl_chart.
  Organização feature-first (`core/`, `features/`, `shared/`, `theme/`).
- **Identidade:** Firebase Auth (token). **Autorização:** no Postgres, sempre pelo
  `IControleAcesso` (recurso de outro usuário responde 404). **Banco:** Postgres
  (Neon em produção).

---

## 2. Publicação — no ar

| Camada | Serviço | Endereço | Observações |
|---|---|---|---|
| API | Fly.io | `https://diario-treino-api.fly.dev` | Docker, região `gru`, health em `/health` |
| Front web | Cloudflare (Workers Static Assets) | `https://diario-treino.vitorhugo-an.workers.dev` | build Flutter no CI, `wrangler deploy` |
| Banco | Neon (Postgres) | — | connection string só em segredo do Fly |
| Auth | Firebase | projeto `diario-treino-c21b6` | domínio do Cloudflare autorizado |

- Deploy automático a cada merge na `main`, depois do CI verde: jobs `deploy-api`
  (Fly) e `deploy-web` (Cloudflare). Ver [DEPLOY-AUTOMATICO.md](DEPLOY-AUTOMATICO.md).
- Migrations aplicadas no startup da API em produção.
- Até 15/10 o front ficava no Netlify; a migração para o Cloudflare está no ADR-09
  e em [POST-MORTEM-deploy-release2.md](POST-MORTEM-deploy-release2.md).
- Flag `TREINO_AO_VIVO`: ligada por padrão no build; o CI roda os testes com ela
  desligada (fluxo de registro de uma vez).

---

## 3. O que o atleta consegue fazer hoje

### Entrada e conta
- Login e cadastro (e-mail/senha e Google), "esqueci a senha".
- Perfil e conta: tema Sistema/Claro/Escuro, sair, excluir conta.

### Início (tela 23)
- **Conta nova** (sem sessão e sem ficha): Bem-vindo (tela 29) com "Criar meu
  plano" (ou "Montar a primeira ficha", se já há plano vazio) e "Registrar treino".
- **Uso normal:** treino em andamento no topo ("Continuar treino"), semana com 4
  estados (toque no dia abre a folha do dia), "Registrar treino" fixo, último treino
  e dica do acesso.
- **Sem plano, com histórico:** a Início normal com o card "Bem-vindo de volta · Crie
  seu plano".
- **"Registrar treino":** com fichas, o sheet "Qual treino?" (fichas com exercícios e
  "Sem ficha"); sem plano, direto ao treino livre.
- Depois de salvar um treino, o aviso "Treino salvo" com "Ver treino".

### Planos e fichas (aba Planos)
- Vários planos, um em uso; plano do professor só leitura (cópia para editar).
- Lista de planos (tela 18) e, sem planos, estado vazio próprio (tela 27).
- Criar plano por um caminho só: "Novo plano" (só o nome) → detalhe do plano vazio
  (tela 28) → "Nova ficha" → a ficha aparece no plano com o atalho "Adicionar
  exercícios".
- Detalhe do plano (tela 19): fichas com resumo, play para treinar (sheet "Iniciar
  agora / Registrar já feito"), ficha em andamento destacada com "Continuar",
  renomear e excluir no topo, duplicar, definir em uso.
- Ficha (tela 22): só edição. Adicionar vários exercícios de uma vez (seletor com
  filtro de músculo), reordenar, remover, alvos por exercício (séries, carga, faixa
  de repetições, descanso, tags de série).

### Treino
- **Treino ao vivo (telas 14 a 16):** cronômetro, exercício série por série (abas
  Séries, Histórico e Evolução, que se mantêm ao trocar de exercício), descanso,
  "Concluir exercício", exercício fora da ficha, um treino por vez.
- A seta só leva à Início (o treino segue em andamento); "Finalizar" leva ao Resumo.
- **Resumo (tela 25):** único passo de salvar; "Salvar treino vazio?" quando não há
  série; etiqueta "Fora da ficha"; "Manter na ficha?" para exercício adicionado.
- **Registro de treino já feito** (data editável) e **treino livre** (com "Salvar
  também como ficha").
- Detalhe da sessão: ver, editar e excluir.

### Progresso
- Gráfico de evolução por exercício, observação no ponto, lista de sessões do
  período (15/30/90 dias).

---

## 4. Arquitetura do front (decisões em vigor)

- **Escritas por comandos, aviso num lugar só (PBI-70):** as telas gravam por
  `fichasComandosProvider`, `sessaoComandosProvider` e `catalogoComandosProvider`;
  cada comando chama o repositório (só HTTP) e depois `invalidarDerivados`
  (`core/dados/invalidacao.dart`), o único lugar que invalida providers. "Tentar de
  novo" usa `ref.refresh` da própria leitura. O teste
  `arquitetura_invalidacao_test.dart` falha se a regra for quebrada.
- **Treino em andamento:** `treinoEmAndamentoProvider` deriva do treino ao vivo e,
  sem ele, do rascunho do aparelho (que avança `versaoRascunhoTreinoProvider` ao
  gravar). O rascunho é gravado já ao iniciar.
- **Criar plano:** `criarPlanoEAbrir` (`planos/acoes_plano.dart`), chamado de todos
  os pontos de entrada.
- **"Manter na ficha?":** `perguntarManterNaFicha` (`sessao/manter_na_ficha.dart`),
  usado pelo Resumo e pelo registro.
- **Tema:** nenhuma cor, tamanho ou espaçamento escrito direto no widget; tudo por
  `AppColors`, `AppText`, `AppSpacing`, `AppSizes` e `AppRadius`.

---

## 5. Back-end

- Endpoints: tabela completa no [MAS](MAS.md), seção 12. Destaques recentes:
  - `POST /sessoes` com `manterNaFicha` (PBI-72): sessão e ficha na mesma
    transação; 400 para pedido inconsistente ou treino livre, 403 em ficha do
    professor, 404 para outro usuário. O `PUT` recusa `manterNaFicha`.
  - `GET /treinos/{id}` devolve `somenteLeitura`.
  - Planos (PBI-44): listar, detalhe, criar com nome, renomear, em uso, duplicar,
    excluir.
- Regra única de acesso (MAS 11.3) em todos os endpoints de dado de atleta;
  somente leitura (403) sempre depois do acesso (404).

---

## 6. Banco de dados

Migrations versionadas (todas aplicam do zero):

| Migration | PBI | O que faz |
|---|---|---|
| `20261002204136_InitialCreate` | E0 | Tabelas do MER, constraints, índices e seed |
| `20261006183645_HabilitaUnaccent` | PBI-10 | Busca sem acento |
| `20261014143254_CatalogoExerciciosCompleto` | catálogo | 89 exercícios globais |
| `20261014190702_MembroMusculoEtapa1` | PBI-31 | Membro e músculo |
| `20261014202739_MembroMusculoEtapa4RemoveGrupo` | PBI-31 | Remove `grupo_muscular` |
| `20261015051429_TagDeSerie` | PBI-38 | Tag por série e por rodada |
| `20261015124844_FaixaRepeticoes` | PBI-39 | `volume_alvo_max` |
| `20261015204940_PlanosVariosEmUso` | PBI-44 | Vários planos, `em_uso` |

As PBIs 57 a 72 não mudaram o esquema.

---

## 7. Testes e CI

- **Front:** 32 arquivos de teste em `app/test/` (231 testes na última entrega),
  incluindo o fluxo de registro com o app inteiro, o teste de um `ProviderScope`
  só para a invalidação e o teste de arquitetura.
- **Back:** unitários (acesso, catálogo, planejamento, "manter na ficha") e
  integração com Testcontainers (Postgres real) para controle de acesso, esquema,
  catálogo, fichas, planos, sessões, progresso e "manter na ficha".
- **CI** (`.github/workflows/ci.yml`): build .NET sem warnings, testes unitários e
  de integração, `flutter analyze`, `flutter test --dart-define=TREINO_AO_VIVO=false`
  e build web; deploy da API e do front depois do CI verde na `main`.
- **Localmente no Windows:** os testes de integração precisam de Docker (sem ele,
  só rodam no CI). Com a flag `TREINO_AO_VIVO` ligada, 2 testes do plano falham
  porque esperam o caminho com a flag desligada.

---

## 8. O que falta

### Backlog
- **PBI-05 — backup do banco:** aguarda a escolha do destino (artifact do GitHub
  Actions com criptografia, ou Cloudflare R2).
- **PBI-26 — E2E com Robot:** os passos precisam acompanhar as mudanças de
  texto e de caminho (abaixo). As branches `feat/e2e-pbi-26` e `feat/pbi-26-e2e`
  existem fora da `main`.
- **PBI-48 e épico do educador (E7):** próxima sprint.
- **PBI-34** (trocar a métrica no registro), **PBI-35** (cronograma semanal) e
  cardio (**PBI-27 a 30**).

### Robot: o que mudou para os passos
- "Registrar sem ficha" virou **"Registrar treino"** (Bem-vindo e Início).
- "MONTAR MINHAS FICHAS" e "CRIAR FICHA" saíram: o caminho é "Criar meu plano" →
  "CRIAR PLANO" → "NOVA FICHA" → "Salvar".
- Depois de salvar não há mais "Treino registrado" nem "Ir para o Início": esperar a
  Início com o aviso **"Treino salvo"**.
- O passo de escolher exercício muda com o seletor da PBI-49.
- Campos de texto no Flutter web: `Click With Options force=True` e depois
  `Keyboard Input insertText` (o campo semântico é um `<input disabled>`).

### Perguntas ao PO
- PBI-69: o plano pode nascer sem fichas e a ficha voltar ao detalhe do plano?
- PBI-72: uma decisão para todos os exercícios adicionados serve?
- PBI-68: o card "Bem-vindo de volta · Crie seu plano" é o "manter o boas-vindas"?
- Atalho "Iniciar treino" na Início; toque no dia de hoje na semana; "excluir
  treino" é só plano ou plano e ficha (PBI-58); o aviso "Treino salvo" basta;
  séries sem marcar ficam de fora ao concluir o exercício; play no plano do
  professor.

### Pendências de infraestrutura
- Domínio próprio (hoje `*.fly.dev` e `*.workers.dev`).
- Resetar a senha do role do Neon (foi digitada em texto durante o setup).
- Ruído de log cosmético na API (`libgssapi_krb5.so.2`), sem efeito na conexão.

---

## 9. Ponto de retomada

Tudo da leva de 16/10 está na `main` (PRs #76 a #91). Próximos passos, nesta ordem:

1. Ajustar os passos do Robot (seção 8) e fechar a PBI-26.
2. PBI-05, assim que o destino do backup for escolhido.
3. Levar as perguntas da seção 8 ao PO.
