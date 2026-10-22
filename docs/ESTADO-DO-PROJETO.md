# Estado do projeto — Diário de Treino

Documento de passagem: o que existe hoje (telas, front, back, banco e publicação) e o
que falta. O detalhe de cada entrega, PR por PR, está em
[HISTORICO-DE-ALTERACOES.md](HISTORICO-DE-ALTERACOES.md); o contrato da API, no
[MAS](MAS.md) (seção 12); as PBIs, no [BACKLOG](BACKLOG.md).

Data do levantamento: 21/10/2026, depois do PR #109 (PBI-26, E2E do fluxo principal).

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
- Backup semanal do banco (PBI-05): `pg_dump` do Neon em artifact do GitHub Actions,
  restauração testada. Ver [BACKUP-RESTAURACAO.md](BACKUP-RESTAURACAO.md).
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
| `20261019145756_ReparoPlanoEmUso` | PBI-77 | Reparo de dados: marca em uso o plano com a sessão mais recente para atletas sem plano em uso |

As PBIs 57 a 72 não mudaram o esquema; a PBI-77 trouxe a migration de reparo
acima (só dados, sem alterar tabelas). As correções 73 a 76, 78 a 80 e o
calendário (PBI-82) e o E2E (PBI-26) não mexeram no banco.

---

## 7. Testes e CI

- **Front (widget):** 37 arquivos de teste em `app/test/` (rodam no `flutter test`,
  headless, com as bordas fakeadas), incluindo o fluxo de registro com o app inteiro,
  o teste de um `ProviderScope` só para a invalidação e o teste de arquitetura.
- **E2E (PBI-26):** `app/integration_test/fluxo_pbi26_test.dart` — dirige a árvore de
  widgets (`tester.enterText`, digita de verdade) contra a **stack real** no CI:
  Postgres + API .NET + Firebase Auth Emulator + o app. Cobre entrar → registrar
  treino livre → ver no progresso. Roda com `flutter drive` + ChromeDriver (Chrome
  headless). Migrou de Robot/Playwright, inviável no CanvasKit (campos de texto não
  aceitam entrada via DOM). Ver PBI-26 no [BACKLOG](BACKLOG.md).
- **Back:** unitários (acesso, catálogo, planejamento, "manter na ficha") e
  integração com Testcontainers (Postgres real) para controle de acesso, esquema,
  catálogo, fichas, planos, sessões, progresso e "manter na ficha".
- **CI** (`.github/workflows/ci.yml`): build .NET sem warnings, testes unitários e
  de integração, `flutter analyze`, `flutter test --dart-define=TREINO_AO_VIVO=false`,
  build web e o job `e2e` (integration_test). Deploy da API e do front depois do CI
  verde na `main`.
- **Localmente no Windows:** os testes de integração (back) e o E2E precisam de
  Docker/emulador (sem eles, só rodam no CI). Com a flag `TREINO_AO_VIVO` ligada,
  2 testes do plano falham porque esperam o caminho com a flag desligada.

---

## 8. O que falta

### Backlog
- **PBI-34** (trocar a métrica no registro), **PBI-35** (cronograma semanal).
- **PBI-48 e épico do educador (E7):** próxima sprint.
- Incremento 2 — cardio (**PBI-27 a 30**).

### Entregue recentemente (PR)
- Correções de uso real de 16 a 19/10: **PBI-77** (#93, plano novo em uso +
  migration de reparo), **PBI-74** (#94, um exercício por ficha/sessão),
  **PBI-78/79** (#95, editor de alvos com dado atual e resumo com unidade),
  **PBI-73** (#96, gráfico sem carga usa repetições), **PBI-76** (#97, aviso
  quando não lê a ficha), **PBI-80** (#98, aba abre a raiz — ADR-11).
- **PBI-05** backup (#100/#102), **PBI-24** contraste (#101).
- **PBI-82** calendário do mês (#104–#106).
- **PBI-26** E2E do fluxo principal (#108/#109).
- Bloco 1 (fechar pendências antes do educador): **PBI-83** docs (#111),
  **PBI-81** "Manter na ficha?" por exercício (#112), **PBI-75** aviso vira
  pílula (#113). **PBI-84** (série em branco) entrou (#114) e foi **revertida**
  (#115) por decisão do PO — ver seção de decisões.

### Decisões do PO já tomadas (19/10)
- Início de quem apagou os planos mostra "Bem-vindo de volta · Crie seu plano" (PBI-68).
- Gráfico de exercício só de repetições usa a **melhor série** (maior nº de repetições da sessão) (PBI-73).
- Exercício já presente fica **desabilitado com aviso** no seletor (PBI-74).
- "Manter na ficha?" é decidido **exercício por exercício** (PBI-81).
- "Adicionar série" no registro posterior/edição **copia a série anterior**
  (valores já preenchidos e editáveis), igual ao treino ao vivo — a PBI-84
  (série em branco com dica) foi **revertida** por isso (31/10, #114→#115).
- Atalho "Iniciar treino" na Início: **dispensado**.
- "Excluir treino" apaga **só a sessão**.
- Toque num dia da semana **abre o treino daquele dia**.
- As dicas da Início **ficam no app** até o modo educador (E7).

### Perguntas ainda abertas com o PO
- PBI-69: o plano pode nascer sem fichas e a ficha criada volta ao detalhe do plano?
- Séries não marcadas ficam de fora ao "concluir exercício"?
- Play no plano do professor (só leitura): o que faz?
- PBI-75: "Treino salvo" mantém a ação "Ver treino" ou vira só o pop? (recomendação: só o pop).

### Pendências de infraestrutura
- Domínio próprio (hoje `*.fly.dev` e `*.workers.dev`).
- Resetar a senha do role do Neon (foi digitada em texto durante o setup).
- Ruído de log cosmético na API (`libgssapi_krb5.so.2`), sem efeito na conexão.

---

## 9. Ponto de retomada

O Incremento 1 (modo atleta) está essencialmente completo e na `main`, incluindo o
E2E automatizado do fluxo principal (PBI-26, PRs #108/#109). Próximos passos:

1. PBI-34 (trocar a métrica no registro) e PBI-35 (cronograma semanal).
2. Modo educador (PBI-48 e épico E7) na próxima sprint; depois o Incremento 2 (cardio).
3. Levar as perguntas da seção 8 ao PO.

### Dívidas técnicas de infra em aberto
- Deploy da API no Fly pode ficar vermelho por "no capacity in gru" ao criar a 2ª
  máquina de HA (transitório; a API sobe na 1ª). Candidato: `--ha=false` no
  `deploy-api`.
- O job `e2e` é `continue-on-error: true` (não bloqueia merge) enquanto amadurece;
  avaliar torná-lo bloqueante agora que passa de forma estável.
