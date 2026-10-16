# Histórico de alterações — Diário de Treino

Registro de tudo que entrou na `main`, PR por PR, do início do projeto (02/10/2026) até
a PBI-67 (PR #86) e este documento (PR #87), 16/10/2026. Fonte: histórico Git. O detalhe de cada PBI (história,
critérios de aceite) está no [BACKLOG](BACKLOG.md) e, para as PBIs 57 a 67, em
[AJUSTES-LAYOUT](AJUSTES-LAYOUT.md).

Como manter: a cada PR mergeado, acrescente uma linha na tabela do período e, se mudar o
banco, na seção de migrations. Os números #53 e #64 não aparecem porque esses PRs foram
fechados sem merge.

---

## Fundação · 02/10

| PR | O que mudou |
|---|---|
| — | Épico E0 (PBI-01 a 03): solução .NET em camadas, banco com a migration inicial do MER e app Flutter feature-first. |

## Autenticação e acesso · 05 e 06/10

| PR | PBI | O que mudou |
|---|---|---|
| #1 | PBI-06 | API valida o token do Firebase; `GET /me` cria o usuário no primeiro acesso. |
| #2 | PBI-07 | `IControleAcesso`: regra única de acesso, recurso de outro usuário responde 404. |
| #3 | fix | Testes de integração apontam para o Postgres do container. |
| #4 | PBI-08 | Login e cadastro no app (e-mail/senha e Google). |

## Catálogo, fichas e registro · 07 a 09/10

| PR | PBI | O que mudou |
|---|---|---|
| #5, #6 | PBI-10 | Busca no catálogo (API `GET /exercicios` e tela). |
| #7, #8 | PBI-11 | Criar exercício próprio (`POST /exercicios`, `GET /metricas` e tela). |
| #9 | design | Design system do protótipo: temas claro/escuro por tokens, tipografia Barlow, navegação. |
| #10, #11 | PBI-12 | Criar, renomear e arquivar fichas. |
| #12, #13 | PBI-13 | Adicionar, reordenar e remover exercícios da ficha. |
| #14, #15 | PBI-14 | Alvos do exercício na ficha (séries, carga, reps, descanso). |
| #16, #17 | PBI-15 | Registrar sessão a partir da ficha, com rascunho pré-preenchido. |
| #18 | PBI-16 | Editar séries durante o registro. |
| #19 | PBI-17 | Exercício fora da ficha no registro. |
| #20, #21 | PBI-18 | Ver, editar e excluir sessão. |

## Publicação e tela inicial · 12 e 13/10

| PR | PBI | O que mudou |
|---|---|---|
| #22 a #24 | PBI-04 | Publicação: API no Fly (Docker), front no Netlify, banco no Neon, migrations no startup, CORS. |
| #25 | docs | `ESTADO-DO-PROJETO.md`, ADR-10 (membro) e PBIs 31/32. |
| #26 | PBI-32 | Criar exercício pelo seletor; largura máxima de 600 px no web. |
| #27 | PBI-23 B | Tela inicial lista as fichas e inicia o registro. |
| #28 | PBI-22 | `GET /sessoes?de=&ate=` (sessões do período). |
| #29, #30 | docs | Registro do bug PBI-33 e ponto de retomada. |
| #31 | PBI-33 | Bug: sessão salva vazia. Série em branco no rascunho e salvar bloqueado sem séries. |
| #32 | CI | Deploy automático da API no Fly a cada merge na `main`. |
| #33, #34 | PBI-23 A | Próxima ficha da rotação, última vez por ficha, faixa semanal; correção da sugestão que não atualizava. |
| #35 | PBI-26 | Teste de fluxo de UI (registrar → voltar → rotação), parcial do E2E. |
| #36 | PBI-22 | Lista de sessões do período na aba Progresso (15/30/90 dias). |
| #37, #38 | PBI-20 | API de evolução por exercício e lista dos exercícios com histórico. |

## Progresso, perfil e membro · 14/10

| PR | PBI | O que mudou |
|---|---|---|
| #39 | PBI-20 | Gráfico de evolução por exercício (`fl_chart`). |
| #40, #41 | PBI-21 | Observação no ponto do gráfico, com "Abrir sessão". |
| #42 | catálogo | Carga de 89 exercícios globais. |
| #43 | docs | MAS, MER, README e ESTADO atualizados. |
| #44 | fix | Busca zera ao abrir o seletor e o catálogo. |
| #45 | PBI-25 / 24 | Perfil e conta: tema (Sistema/Claro/Escuro), sair e excluir conta. |
| #46 | PBI-36 | Excluir ficha: apaga sem sessões, arquiva com sessões. |
| #47 a #50 | PBI-31 | Membro e músculo em 4 etapas (banco, API com `GET /membros`, filtro no front, remoção de `grupo_muscular`). |
| #51 | PBI-19 / 09 | Treino livre e tela de primeiro acesso. |
| #52 | PBI-37 | Treino em andamento: iniciar, finalizar e rascunho no aparelho. |

## Treino ao vivo (Release 2) e deploy · 15/10

| PR | PBI | O que mudou |
|---|---|---|
| #54 | PBI-37 | Corrige a trava ao sair do treino e mostra o erro real do 400. |
| #55 | PBI-38 (TV-1) | Tag de série (válida, aquecimento etc.) na ficha, no registro e no detalhe. |
| #56 | PBI-39 (TV-2) | Faixa de repetições no alvo ("8 a 12"). |
| #57 | PBI-40 a 43 (TV-3 a 6) | Treino ao vivo: tela 14 com cronômetro, exercício série por série (abas Séries/Histórico/Evolução), descanso, Resumo; flag `TREINO_AO_VIVO`. |
| #58 a #61 | fix | Flag ligada por padrão no build, Início abre o treino ao vivo, telas ao vivo em tela cheia, emulador do Firebase para o E2E. |
| #62 | infra | Front migra do Netlify para o Cloudflare Workers. |
| #63 | docs | Post-mortem do deploy do Release 2 e ADR-09 reescrito. |
| #65 | PBI-50 | Tocar no cartão da ficha só abre a ficha, não inicia treino. |
| #66 | PBI-54 | Filtro de músculo em lista. |
| #67 | PBI-44 | Vários planos, com um em uso; plano do professor somente leitura. |
| #68 | PBI-53 | Diálogos de perigo em vermelho. |
| #69 | PBI-55 | Registro e treino livre em tela cheia. |
| #70 | PBI-51 | Componentes compartilhados de erro, vazio e pós-registro. |
| #71 | PBI-52 | Ações e hierarquia dos botões na tela Fichas. |
| #72 | PBI-45 | Lista de planos e aba Planos. |
| #73 | PBI-46 | Detalhe do plano (tela 19). |
| #74 | PBI-47 | Início segue o plano em uso. |

## Ajustes de layout do PO (PBI-57 a 67) · 16/10

| PR | PBI | O que mudou |
|---|---|---|
| #75 | docs | Modo educador vira épico próprio na próxima sprint. |
| #76 | PBI-58 | Renomear e excluir como ícones no topo do plano e da ficha. |
| #77 | PBI-57, 62, 61 | Ficha só de edição; cartão de exercício com alça e remover; treinar pelo play do plano (sheet "Iniciar agora" / "Registrar já feito"). |
| #78 | PBI-63 r1 | Finalizar treino sem a seta e com avisos de vazio e pendentes. |
| #79 | PBI-59 | Início nova: semana com 4 estados, último treino e folha do dia. |
| #80 | PBI-60 | Dicas de treino na Início, trocando a cada acesso. |
| #81 | PBI-49 | Seletor com vários exercícios de uma vez e filtro de músculo. |
| #82 | PBI-63 r2 | "Finalizar treino" vai direto ao Resumo; aviso "Salvar treino vazio?" no Resumo. |
| #83 | PBI-63 r3 | A seta volta e só leva à Início; o treino segue em andamento. |
| #84 | PBI-66 | Setas do exercício mantêm a aba (Histórico/Evolução). |
| #85 | PBI-64, 65 | Salvar leva à Início com o aviso "Treino salvo" e "Ver treino"; botão "Concluir exercício" e "Concluído N/M" no Resumo. |
| #86 | PBI-67 | Treino em andamento aparece na Início e no plano logo ao iniciar; um treino por vez. |
| #87 | docs | Este histórico de alterações. |

## Correções e fluxos de entrada (PBI-67 a 72) · 16/10

| PR | PBI | O que mudou |
|---|---|---|
| #88 | PBI-70 | Telas atualizam pela origem da mudança: escritas por comandos e mapa único de invalidação; teste de arquitetura. Registra as PBIs 67 a 72. |
| #89 | PBI-68, 69 | Bem-vindo só na Início e só para conta nova; Planos vazio com tela própria; "Crie seu plano" para quem já treinou; caminho único de criar plano até o detalhe vazio com "Nova ficha". |
| #90 | PBI-71 | "Registrar treino" fixo na Início: sheet "Qual treino?" com as fichas que têm exercícios e "Sem ficha"; sem plano, direto ao treino livre. |

---

## Migrations do banco

| Migration | PBI | O que faz |
|---|---|---|
| `20261002204136_InitialCreate` | E0 | Tabelas do MER, constraints, índices e seed inicial. |
| `20261006183645_HabilitaUnaccent` | PBI-10 | Extensão `unaccent` (busca sem acento). |
| `20261014143254_CatalogoExerciciosCompleto` | catálogo | 89 exercícios globais; 7 genéricos antigos ficam inativos. |
| `20261014190702_MembroMusculoEtapa1` | PBI-31 | Tabelas `membro` e `musculo` e classificação do catálogo. |
| `20261014202739_MembroMusculoEtapa4RemoveGrupo` | PBI-31 | Remove `grupo_muscular`. |
| `20261015051429_TagDeSerie` | PBI-38 | Marcador por série e por rodada. |
| `20261015124844_FaixaRepeticoes` | PBI-39 | `volume_alvo_max` com `CHECK`. |
| `20261015204940_PlanosVariosEmUso` | PBI-44 | Coluna `em_uso` e vários planos por atleta. |

## Infraestrutura

- API no Fly.io (`gru`), deploy automático no CI desde o PR #32.
- Front no Netlify até 15/10; desde o PR #62, no Cloudflare Workers (`wrangler deploy` no CI). Motivo em `POST-MORTEM-deploy-release2.md`.
- Banco no Neon; migrations aplicadas no startup da API.
- CI: build .NET sem warnings, testes unitários e de integração (Testcontainers), `flutter analyze`, `flutter test --dart-define=TREINO_AO_VIVO=false` e build web.

## O que ainda falta

- PBI-05: backup do banco (aguarda a escolha entre artifact do GitHub Actions com criptografia e Cloudflare R2).
- PBI-26: E2E completo com Robot. Os passos que esperam "Treino registrado" ou "Ir para o Início" precisam esperar o aviso "Treino salvo" (PBI-64), e o passo de escolher exercício mudou com a PBI-49.
- PBI-48 e o épico do educador (E7), na próxima sprint.
- PBI-34 (trocar a métrica no registro), PBI-35 (cronograma semanal) e cardio (PBI-27 a 30).
- Perguntas abertas ao PO em `AJUSTES-LAYOUT.md` (atalho "Iniciar treino", "Minimizar", escopo da PBI-58 e outras).
