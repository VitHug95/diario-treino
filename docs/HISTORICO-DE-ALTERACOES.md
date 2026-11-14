# Histórico de alterações — Diário de Treino

Registro de tudo que entrou na `main`, PR por PR, do início do projeto (02/10/2026) até
o PR #135 (PBI-35), 05/11/2026. Fonte: histórico Git. O detalhe de cada PBI (história,
critérios de aceite) está no [BACKLOG](BACKLOG.md).

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
| #91 | PBI-72 | "Manter na ficha?": `POST /sessoes` com `manterNaFicha` grava sessão e ficha na mesma transação (séries salvas e alvo da última); 400/403/404 sem gravar nada; `GET /treinos/{id}` com `somenteLeitura`; diálogo no Resumo e no registro, etiqueta "Fora da ficha". |

## Correções de uso real, backup, contraste e calendário · 19 e 20/10

| PR | PBI | O que mudou |
|---|---|---|
| #93 | PBI-77 | Plano novo nasce em uso quando não há plano em uso (planos escondidos não contam); migration de reparo `ReparoPlanoEmUso`. |
| #94 | PBI-74 | Um exercício por ficha e por sessão: 409 ao adicionar à ficha, 400 ao salvar a sessão; seletor desabilita quem já está presente. |
| #95 | PBI-78, 79 | Editor de alvos abre sempre com o dado atual (não reabre em branco); resumo da ficha mostra a faixa de repetições e "65 kg" (não "65 carga"). |
| #96 | PBI-73 | Gráfico de progresso decide a grandeza por exercício: sem carga, usa repetições. |
| #97 | PBI-76 | "Manter na ficha?": avisa quando não consegue ler a ficha e firma os três botões em coluna. |
| #98 | PBI-80 | Tocar numa aba sempre abre a raiz dela (ADR-11). |
| #100, #102 | PBI-05 | Backup semanal do banco no CI (`pg_dump` do Neon guardado fora, em artifact); restauração testada. |
| #101 | PBI-24 | Conferência de contraste 4,5:1 nos dois temas, travada por teste. |
| #104 a #106 | PBI-82 | Calendário do mês a partir do cartão "Esta semana": grade seg→dom, navegação por mês, folha do dia; ícone de calendário no canto e "X" nos dias passados sem treino. |

## E2E do fluxo principal · 21/10

| PR | PBI | O que mudou |
|---|---|---|
| #108 | PBI-26 | E2E do caminho principal em `integration_test` (`flutter drive` + ChromeDriver), contra a stack real (Postgres + API + Firebase Auth Emulator): entrar, registrar treino livre e ver no progresso. Migrado de Robot/Playwright, inviável no CanvasKit (campos de texto não aceitam entrada via DOM). Inclui auto-login no modo emulador, aceitação do token do emulador (`RequireSignedTokens=false`) e CORS de qualquer localhost no E2E. **Correção de produção:** provisionamento de usuário idempotente — o primeiro acesso disparava `/planos/ativo` e `/sessoes` em paralelo e a 2ª inserção violava o índice único (500); agora trata o conflito e re-busca. |
| #109 | docs | BACKLOG, MAS e HISTORICO: PBI-26 concluído e as decisões do E2E. |
| #110 | docs | HISTORICO: registro dos PRs #108 e #109 na tabela. |
| #111 | PBI-83 | Sincroniza os documentos com a `main`: ESTADO (migration `ReparoPlanoEmUso`, ADR-11, PBIs 73–82 entregues com PR, PBI-81/84 em andamento, decisões do PO separadas das perguntas abertas); BACKLOG ganha as PBIs 73–81 (sem lacuna); README não cita mais o E2E Robot como pendente. |

| #107 | docs | Registro do calendário (PBI-82) nos documentos. |

## Bloco 1, infraestrutura e início do educador · 22 a 30/10

| PR | PBI | O que mudou |
|---|---|---|
| #112 | PBI-81 | "Manter na ficha?" decidido exercício por exercício. |
| #113 | PBI-75 | Aviso vira pílula (`mostrarAviso`). |
| #114 | PBI-84 | Série em branco com dica no registro posterior. |
| #115 | PBI-84 | Reverte o #114 por decisão do PO: "Adicionar série" copia a anterior. |
| #116 | PBI-75 | "Treino salvo" sem ação (tira o "Ver treino"). |
| #117 | infra | Deploy da API no Fly com `--ha=false` (evita "no capacity in gru"). |
| #118 | infra | Job E2E bloqueante com 1 retry (tira o `continue-on-error`). |
| #119 | fix | Correção de diálogo. |
| #120 | PBI-85 | Back: tornar-se educador, vínculo (convite/aceite/recusa/encerrar), `GET /alunos`, `GET /vinculos/pendentes`. |
| #121 | infra | Wrangler v4 no deploy-web (corrige o `code 10013` do upload de assets). |
| #122 | PBI-86 | Back: educador lê os dados do aluno via `atletaId`, sempre pelo `IControleAcesso`. |
| #123 | docs | Sincronização dos documentos. |
| #124 | PBI-87 | Observação privada e consentimento (migration `ObservacaoPrivadaEConsentimento`). |

## Telas do educador, PDF e semana planejada · 30/10 a 05/11

| PR | PBI | O que mudou |
|---|---|---|
| #125 a #127 | PBI-87 front, 88a a 88c | Consentimento e observação privada no app; contexto/escolha de papel, lista de alunos, convite, treino e progresso do aluno. |
| #128 | PBI-88d | Back: criar plano para o aluno (autor = educador), plano somente-leitura para quem não é o autor. |
| #129 | PBI-88d | Front: `AlunoPlanosScreen` e `AlunoPlanoDetalheScreen` (fecha a PBI-48). |
| #130 | PBI-89 | Back: `GET /progresso/pdf` com QuestPDF Community, `ServicoRelatorio`, `IGeradorRelatorioPdf`. |
| #131 | PBI-89 | Front: `BotaoExportarPdf` na aba Progresso e na tela do aluno. |
| #132 | PBI-90 | "Concluir exercício" no fim da aba Séries; descanso conta negativo com o aviso "Descanso acabou, volte ao treino". |
| #133 | PBI-75 | Pílula em todo o app: confirmações com `mostrarAviso`, erros com `mostrarErro`. |
| #134 | PBI-35 | Back: tabela `plano_dia_semana` (migration `PlanoSemana`), `PUT /planos/{id}/semana`; duplicar copia a semana, arquivar libera os dias. |
| #135 | PBI-35 | Front: seção Semana no plano e faixa da Início com planejado/faltou/descanso; "Planejado: X" na folha do dia. |

## Corpo e medidas (E12) · 09/11

| PR | PBI | O que mudou |
|---|---|---|
| #136 | docs | Estado, histórico, pendências, backlog, MAS e README atualizados até o #135. |
| #137 | PBI-91 | Back: medidas corporais por dia. Migration `MedidaCorporal` (tabela `medida_corporal`, 12 tipos, peso como medida com histórico), `GET /me/medidas`, `GET\|PUT\|DELETE /me/medidas/{data}`, variação por tipo, validação por faixa sem repetir o valor digitado, só o dono. E12 registrado no BACKLOG (PBIs 91 a 96), MER 3.15 e MAS 12. |
| #138 | PBI-92 | Front: bloco CORPO no Perfil, tela Medidas corporais (últimas medidas com variação, histórico) e Registrar medidas (parcial, vírgula ou ponto, editar e excluir o dia). `Mudanca.medidas` na invalidação. Widget `CampoData` compartilhado. |
| #139 | PBI-93 | Back: migration `PerfilCorporal` (`sexo`, `data_nascimento`, `altura_cm` em `usuario`), `CalculoTmb` (Mifflin-St Jeor), `GET\|PUT\|DELETE /me/perfil-corporal` (o `PUT` com `pesoKg` grava a medida PESO; o `DELETE` preserva o histórico de peso). Front: linha "Dados corporais" no Perfil e tela com o cartão da TMB (calculada, incompleta, menor de idade). |
| (PR da PBI-94) | PBI-94 | Back: `GET /me/medidas/{tipo}/evolucao` (pontos por data, primeira, última e variação; período vazio é lista vazia). Front: tela de evolução da medida (filtros 30 dias/90 dias/1 ano/Tudo, gráfico com eixo fora do zero, cartões, lista em texto e rótulo falado); a linha de cada medida com registro passa a ser tocável. |

## Campo de data e TMB informada · 11 e 12/11

| PR | PBI | O que mudou |
|---|---|---|
| (PR da PBI-97) | PBI-97 | Front: `CampoData` compartilhado (campo inteiro tocável; o nó de semântica ganhou o `onTap` que faltava, causa do toque perdido na web) e seletor próprio `escolherData` (calendário + digitação com máscara dd/mm/aaaa, barras automáticas, teclado numérico). Substitui as duas cópias privadas do registro e do resumo e o `showDatePicker` nas quatro telas. |
| (PR da PBI-98) | PBI-98 | Back: migration `TmbManual` (`usuario.tmb_manual_kcal`), `tmbKcal` efetivo + `tmbCalculadaKcal` + `tmbManual` no `GET /me/perfil-corporal`, `PUT\|DELETE /me/perfil-corporal/tmb-manual`; limpar os dados corporais limpa a TMB informada. Front: botão "Editar" no cartão da TMB, diálogo com "Usar o cálculo", selo "Informada por você" e linha "Calculada". |
| (PR da PBI-100) | PBI-100 | Bug da ficha com valor antigo depois de salvar os alvos: **não reproduzido** (widget, app inteiro e Chrome real contra a stack real). Back: `SemCacheMiddleware` (`Cache-Control: no-store` e `Pragma: no-cache` em toda resposta) e `SemCacheEndpointTests`; `PostgresFixture` aceita `TESTES_POSTGRES` para rodar a integração sem Docker. Front: testes de regressão da ficha e do fluxo inteiro; E2E `alvos_ficha_pbi100_test.dart` no job `e2e`. Falta conferir no Safari do iPhone. |
| (PR da PBI-101) | PBI-101 | Bloco conjugado na ficha. Back: migration `BlocoConjugado` (`bloco_exercicio` + `treino_exercicio.bloco_id`), `RegrasBloco` no domínio (rodadas = maior número de séries, 2 a 4 membros, contiguidade), `POST|PUT|DELETE /treinos/{id}/blocos[/{blocoId}]` e `PUT .../membros`; reordenar recusa separar um bloco; remover membro desfaz o bloco de dois; duplicar o plano copia os blocos. Front: cartão do bloco na ficha, "Juntar com o de baixo" com o sheet do descanso, "Descanso", "Desfazer bloco", menu do membro (mover, tirar do bloco, remover); editor de alvos sem descanso no bloco. |
| (PR da PBI-102) | PBI-102 | Treino ao vivo com bloco conjugado. Back: migration `SerieBloco` (`serie_executada.bloco` e `posicao_no_bloco`), `POST|PUT /sessoes` gravam os dois, rascunho da ficha com `blocoId` e `blocos`. Front: cartão "CONJUGADO" na tela 14, tela do bloco ("Rodada 2 de 4", "RODADA FEITA", check por série, "Concluir bloco"), um descanso por rodada (só se > 0; desmarcar cancela), rascunho local com o bloco e compatível com o antigo, descanso do bloco só na última série de cada rodada ao salvar. E2E `bloco_ao_vivo_pbi102_test.dart` no job `e2e` com `TREINO_AO_VIVO=true`. |
| (PR da PBI-103) | PBI-103 | Bloco no histórico: o detalhe da sessão (do atleta e do educador) agrupa os membros do bloco rodada a rodada, com o descanso uma vez por rodada, só pelo que a sessão gravou; sessões antigas como antes. Teste de integração confirma histórico e gráfico do exercício iguais com e sem bloco. |
| (PR do "Juntar com…") | PBI-101 (ajuste) | Editor da ficha: "Juntar com o de baixo" virou "Juntar com…", um sheet para escolher de 1 a 3 exercícios (até 4 no bloco) ou um bloco existente, com o descanso no mesmo sheet; membros de outros blocos desabilitados. "Adicionar exercício" no cabeçalho do bloco. Só front: a API já juntava não vizinhos. |

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
| `20261019145756_ReparoPlanoEmUso` | PBI-77 | Reparo de dados: marca em uso o plano ativo com a sessão mais recente para atletas sem plano em uso. |
| `20261030143221_ObservacaoPrivadaEConsentimento` | PBI-87 | Flag de observação privada e tabela de consentimento. |
| `20261105201232_PlanoSemana` | PBI-35 | Tabela `plano_dia_semana` (ficha por dia da semana). |
| `20261109174739_MedidaCorporal` | PBI-91 | Tabela `medida_corporal` (medidas do corpo por dia e tipo; peso incluso). |
| `20261111144536_PerfilCorporal` | PBI-93 | Colunas `sexo`, `data_nascimento` e `altura_cm` em `usuario`, com CHECK de sexo e de altura. |
| `20261112202209_TmbManual` | PBI-98 | Coluna `tmb_manual_kcal` em `usuario` (TMB informada), com CHECK de 800 a 5000. |
| `20261113173129_BlocoConjugado` | PBI-101 | Tabela `bloco_exercicio` (descanso do bloco, CHECK de 0 a 600) e coluna `treino_exercicio.bloco_id` (nula, ON DELETE SET NULL). Não mexe nas linhas existentes. |
| `20261113191412_SerieBloco` | PBI-102 | Colunas `serie_executada.bloco` e `posicao_no_bloco` (nulas), com CHECK "os dois juntos, posição 1 a 4". Não mexe nas séries existentes. |

## Infraestrutura

- API no Fly.io (`gru`), deploy automático no CI desde o PR #32; `--ha=false` desde o #117.
- Front no Netlify até 15/10; desde o PR #62, no Cloudflare Workers (`wrangler deploy` no CI; Wrangler v4 desde o #121). Motivo em `POST-MORTEM-deploy-release2.md`.
- Banco no Neon; migrations aplicadas no startup da API.
- CI: build .NET sem warnings, testes unitários e de integração (Testcontainers), `flutter analyze`, `flutter test --dart-define=TREINO_AO_VIVO=false`, build web e o **E2E (PBI-26)** — job `e2e` bloqueante com 1 retry (#118), com `integration_test` via `flutter drive` + ChromeDriver, contra Postgres + API + Firebase Auth Emulator.

## Estado atual

O resumo do que existe hoje e do que falta está em [ESTADO-DO-PROJETO.md](ESTADO-DO-PROJETO.md).

## O que ainda falta

- E12 · Corpo e medidas: PBI-95 e 96, o compartilhamento com o educador (a 91 a 94 estão prontas).
- PBI-34 (trocar a métrica no registro), bloqueada pela escolha (a) × (b).
- Cardio (PBI-27 a 30) e os épicos E8 a E11 (inclui a publicação na Google Play).
- Pendências e decisões em aberto com o PO em [PENDENCIAS-PUBLICACAO.md](PENDENCIAS-PUBLICACAO.md).