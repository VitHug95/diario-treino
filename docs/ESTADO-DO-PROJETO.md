# Estado do projeto — Diário de Treino

Documento de passagem: o que existe hoje (telas, front, back, banco e publicação) e o
que falta. O detalhe de cada entrega, PR por PR, está em
[HISTORICO-DE-ALTERACOES.md](HISTORICO-DE-ALTERACOES.md); o contrato da API, no
[MAS](MAS.md) (seção 12); as PBIs, no [BACKLOG](BACKLOG.md).

Data do levantamento: 14/11/2026, com o PR das PBIs 95 e 96 (compartilhar o
corpo com o educador) depois do #148. Incrementos 1 (atleta), o épico do educador
(E7), o E12 (corpo e medidas) e o E13 (exercícios conjugados) estão entregues.

---

## 1. Visão geral

- **App:** registrar treinos (inclusive dias depois) e acompanhar a evolução por
  exercício. Modo atleta e modo educador entregues.
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
- **Uso normal:** treino em andamento no topo ("Continuar treino"), semana com
  estados treinou / faltou / planejado / descanso (PBI-35; todo dia que passou sem
  treino mostra o "X", com ou sem ficha planejada, desde o #148; toque no dia abre
  a folha do dia, que mostra "Planejado: X"), calendário do mês (PBI-82), "Registrar treino"
  fixo, último treino e dica do acesso.
- **Sem plano, com histórico:** a Início normal com o card "Bem-vindo de volta · Crie
  seu plano".
- **"Registrar treino":** com fichas, o sheet "Qual treino?" (fichas com exercícios e
  "Sem ficha"); sem plano, direto ao treino livre.
- Depois de salvar um treino, a pílula "Treino salvo" (sem ação; o treino se reabre
  pelo cartão de último treino). Confirmações usam `mostrarAviso` (pílula) e erros
  usam `mostrarErro`, nunca a pílula (PBI-75, em todo o app).

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
- **Bloco conjugado (PBI-101):** "Juntar com…" (ícone de elo) abre a lista da ficha
  para escolher com quais exercícios juntar (ou em qual bloco entrar); "Adicionar
  exercício" no cabeçalho do bloco traz mais um. Junta 2 a 4 exercícios num cartão só, "Conjugado · 4 rodadas · descanso 30 s", com um descanso
  por rodada; "Descanso" e "Desfazer bloco" no cabeçalho; cada exercício tem "Mover
  para cima/baixo", "Tirar do bloco" e "Remover da ficha". O bloco se arrasta
  inteiro. Dentro do bloco, o editor de alvos não tem descanso. Vale para o
  educador na ficha do aluno.
- **Bloco no treino ao vivo (PBI-102):** o bloco é um cartão só na tela 14 ("2 de 4
  rodadas") e abre a tela do bloco, rodada a rodada, com "RODADA FEITA", o check de
  cada série e um descanso só por rodada. O registro de uma vez mostra os exercícios
  separados. O detalhe da sessão (também na visão do educador) mostra o bloco
  agrupado rodada a rodada, com o descanso uma vez por rodada (PBI-103).
- **Semana do plano (PBI-35):** seção Semana no plano define qual ficha cai em cada
  dia (no máximo 1 ficha por dia; opcional; semana fixa). Duplicar copia a semana;
  arquivar libera os dias. "Fez" = treinou no dia com qualquer ficha.

### Treino
- **Treino ao vivo (telas 14 a 16):** cronômetro, exercício série por série (abas
  Séries, Histórico e Evolução, que se mantêm ao trocar de exercício), descanso,
  "Concluir exercício" (no fim da aba Séries, PBI-90), exercício fora da ficha, um
  treino por vez. O descanso não some ao zerar: conta negativo, com o aviso
  "Descanso acabou, volte ao treino".
- A seta só leva à Início (o treino segue em andamento); "Finalizar" leva ao Resumo.
- **Resumo (tela 25):** único passo de salvar; "Salvar treino vazio?" quando não há
  série; etiqueta "Fora da ficha"; "Manter na ficha?" para exercício adicionado.
- **Registro de treino já feito** (data editável) e **treino livre** (com "Salvar
  também como ficha").
- Detalhe da sessão: ver, editar e excluir.

### Progresso
- Gráfico de evolução por exercício, observação no ponto, lista de sessões do
  período (15/30/90 dias).
- **Exportar PDF (PBI-89):** botão na aba Progresso; PDF dos últimos 90 dias
  (configurável), gerado no backend.

### Datas (PBI-97)
- O campo de data é um só em todo o app (nascimento, dia da medição, dia em que treinou): o campo inteiro abre o seletor, que tem calendário e digitação com barras automáticas (`26051995` vira `26/05/1995`). O seletor é próprio, porque o do SDK lê mm/dd/aaaa (o app não tem locale pt-BR).

### Corpo (E12, PBI-92)
- Perfil: bloco **Corpo** com a linha "Medidas corporais" e o resumo da última medição.
- Medidas corporais: últimas medidas dos 12 tipos com variação (seta e sinal), histórico por dia; registrar só o que mediu (vírgula ou ponto), editar e excluir um dia. Dado de saúde: só o dono vê, a não ser que ele compartilhe (PBIs 95 e 96, abaixo).

- Gráfico de evolução de cada medida e do peso (30 dias, 90 dias, 1 ano ou tudo), com os registros também em texto.
- Dados corporais: sexo, nascimento, altura e peso, e a **taxa metabólica basal** (Mifflin-St Jeor, só para adultos), calculada pelo backend; o atleta pode informar o próprio valor, que passa a valer até ele voltar ao cálculo (PBI-98).
- Compartilhar com o educador (PBIs 95 e 96): dois cadeados, "Dados corporais" e "Medidas corporais", trancados por padrão, na tela "Compartilhar com o educador" (Perfil, bloco Corpo). Destrancado, todo educador com vínculo ativo vê, só leitura; destrancar pede confirmação e trancar corta na hora. Selo "Privado" / "Compartilhado" nas telas de dados e de medidas. O educador vê o cartão "Corpo" na tela do aluno, com as seções independentes. O PDF continua sem dado corporal.

### Modo educador (E7)
- Tornar-se educador, convidar aluno, aceitar/recusar/encerrar vínculo (PBI-85,
  PBI-88a/b), lista de alunos.
- Tela do aluno: treinos, progresso e planos (leitura via `atletaId`, PBI-86/88c);
  montar plano e fichas com autor = educador (PBI-88d, fecha a PBI-48); botão de
  PDF na tela do aluno.
- Privacidade (PBI-87): observação privada do atleta e termo de consentimento
  (texto provisório). Ao sair de ATIVO, o educador perde o acesso sem apagar dados.

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
    excluir. `PUT /planos/{id}/semana` define a semana (PBI-35).
  - Educador: `POST /me/papeis/educador`, vínculos (convite/aceite/recusa/encerrar),
    `GET /alunos`; `atletaId` opcional nas leituras; criar plano para o aluno.
  - `GET /progresso/pdf` (PBI-89): relatório gerado com QuestPDF Community, atrás
    de `IGeradorRelatorioPdf`, orquestrado por `ServicoRelatorio`.
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
| `20261030143221_ObservacaoPrivadaEConsentimento` | PBI-87 | Flag de observação privada e tabela de consentimento |
| `20261105201232_PlanoSemana` | PBI-35 | Tabela `plano_dia_semana` (ficha por dia da semana) |
| `20261109174739_MedidaCorporal` | PBI-91 | Tabela `medida_corporal` (medidas do corpo por dia e tipo) |
| `20261111144536_PerfilCorporal` | PBI-93 | `sexo`, `data_nascimento`, `altura_cm` em `usuario` |
| `20261112202209_TmbManual` | PBI-98 | `tmb_manual_kcal` em `usuario` (TMB informada) |
| `20261113173129_BlocoConjugado` | PBI-101 | Tabela `bloco_exercicio` e `treino_exercicio.bloco_id` |
| `20261113191412_SerieBloco` | PBI-102 | `serie_executada.bloco` e `posicao_no_bloco` |
| `20261114042934_CompartilhamentoCorporal` | PBI-95 | `dados_corporais_compartilhados_em` e `medidas_compartilhadas_em` em `usuario` (nulo = trancado) |

As PBIs 57 a 72 não mudaram o esquema; a PBI-77 trouxe a migration de reparo
(só dados). As demais correções, o calendário (PBI-82), o E2E (PBI-26), o PDF
(PBI-89) e as telas do educador não mexeram no banco além das migrations acima.

---

## 7. Testes e CI

- **Front (widget):** 581 testes em `app/test/` (rodam no `flutter test`,
  headless, com as bordas fakeadas; backend: 140 unitários e 276 de integração), incluindo o fluxo de registro com o app inteiro,
  o teste de um `ProviderScope` só para a invalidação e o teste de arquitetura.
- **E2E (PBI-26):** `app/integration_test/fluxo_pbi26_test.dart` — dirige a árvore de
  widgets (`tester.enterText`, digita de verdade) contra a **stack real** no CI:
  Postgres + API .NET + Firebase Auth Emulator + o app. Cobre entrar → registrar
  treino livre → ver no progresso. Roda com `flutter drive` + ChromeDriver (Chrome
  headless). Migrou de Robot/Playwright, inviável no CanvasKit (campos de texto não
  aceitam entrada via DOM). Ver PBI-26 no [BACKLOG](BACKLOG.md).
  O mesmo job roda `alvos_ficha_pbi100_test.dart` (PBI-100): salvar os alvos e
  voltar à ficha mostra o valor novo na hora; e `bloco_ao_vivo_pbi102_test.dart`
  (PBI-102), com `TREINO_AO_VIVO` ligado: duas rodadas de um bloco e o salvar.
- **Back:** unitários (acesso, catálogo, planejamento, "manter na ficha") e
  integração com Testcontainers (Postgres real) para controle de acesso, esquema,
  catálogo, fichas, planos, sessões, progresso e "manter na ficha".
- **CI** (`.github/workflows/ci.yml`): build .NET sem warnings, testes unitários e
  de integração, `flutter analyze`, `flutter test --dart-define=TREINO_AO_VIVO=false`,
  build web e o job `e2e` (integration_test). Deploy da API e do front depois do CI
  verde na `main`.
- **Localmente no Windows:** sem Docker, os testes de integração (back) rodam
  contra um Postgres local com `TESTES_POSTGRES` (connection string de um usuário
  que pode criar banco; cada execução cria e apaga um banco próprio). O E2E
  precisa do emulador, da API e do ChromeDriver. Com a flag `TREINO_AO_VIVO` ligada,
  2 testes do plano falham porque esperam o caminho com a flag desligada.

---

## 8. O que falta

### Backlog
- **PBI-34** (trocar a métrica no registro): **bloqueada** por decisão de
  produto (opção a × b — ver "Perguntas ainda abertas"). Em espera.
- **Incremento 2 — cardio (PBI-27 a 30):** depende da resposta do Vinicius sobre
  como a zona é definida (FC, pace ou percepção).
- **E12 · Corpo e medidas (PBI-91 a 98):** completo. A PBI-91 (back, `/me/medidas`, #137), a PBI-92 (app das medidas, #138), a PBI-93 (dados corporais e TMB, #139), a PBI-94 (gráfico de evolução, #140), a PBI-98 (TMB informada, #142) e as PBIs 95 e 96 (compartilhar com o educador). Nas 95 e 96, as perguntas 1 e 2 do PO foram **assumidas** (todos os educadores com vínculo ativo; dois cadeados) e falta ele confirmar.
- **E13 · Exercícios conjugados (PBI-101 a 103):** entregue (#144 a #147). Falta o PO conferir as telas (não houve protótipo) e as interpretações registradas no BACKLOG.
- **PBI-100** (ficha com o valor antigo): não reproduzida; endurecida com `no-store` (#143). Falta conferir no Safari do iPhone.
- **Épicos futuros:** E8 a E11 (ver [BACKLOG](BACKLOG.md), seção 9), incluindo
  publicação na Google Play (E10).

### Entregue recentemente (PR)
- **E12 — compartilhar o corpo com o educador:** PBIs 95 e 96 (PR desta
  entrega). A PBI-99 foi descartada pelo PO.
- **E13 — exercícios conjugados:** PBI-101 bloco na ficha (#144), PBI-102 treino
  ao vivo com bloco (#145), PBI-103 bloco no detalhe da sessão (#146) e o ajuste
  "Juntar com…" para escolher os exercícios do bloco (#147).
- **Ajuste da PBI-35:** "X" em todo dia passado sem treino na faixa da semana
  (#148).
- **PBI-100:** API sem cache, testes de regressão da ficha e E2E dos alvos (#143).
- **E12:** PBI-91 a 94 (#137 a #140), PBI-97 campo de data (#141), PBI-98 TMB
  informada (#142); docs até o #135 (#136).
- **E7 — modo educador completo:** PBI-85 vínculo (#120), PBI-86 leitura do aluno
  (#122), PBI-87 observação privada + consentimento (#124), PBI-88a a 88d telas
  do educador e planos do aluno (#125 a #129, fecha a PBI-48), PBI-89 PDF
  (#130 back, #131 front).
- **PBI-90** "Concluir exercício" no fim da aba Séries e descanso negativo (#132).
- **PBI-75** aviso em pílula (#113), "Treino salvo" sem ação (#116) e aplicação
  no app todo, com `mostrarErro` para erros (#133).
- **PBI-35** semana planejada: back (#134) e front (#135).
- Bloco 1 anterior: **PBI-83** docs (#111), **PBI-81** "Manter na ficha?" por
  exercício (#112), **PBI-84** entrou (#114) e foi **revertida** (#115).
- Infra: Fly `--ha=false` (#117), E2E bloqueante com 1 retry (#118), Wrangler v4
  no deploy-web (#121), correção de diálogo (#119), PBI-85 (#120), PBI-86 (#122),
  docs (#123).
- Antes: correções 16 a 19/10 (PBI-73 a 80, #93 a #98), PBI-05 backup
  (#100/#102/#103), PBI-24 contraste (#101), PBI-82 calendário (#104 a #106),
  PBI-26 E2E (#108 a #110).

### Decisões do PO já tomadas
- (19/10) Início de quem apagou os planos mostra "Bem-vindo de volta · Crie seu plano" (PBI-68).
- (19/10) Gráfico só de repetições usa a **melhor série** (PBI-73).
- (19/10) Exercício já presente fica **desabilitado com aviso** no seletor (PBI-74).
- (19/10) "Manter na ficha?" é decidido **exercício por exercício** (PBI-81).
- (31/10) "Adicionar série" copia a série anterior; PBI-84 revertida.
- (31/10) "Treino salvo" é só a pílula, sem ação (PBI-75).
- Atalho "Iniciar treino" na Início: **dispensado**.
- "Excluir treino" apaga **só a sessão**; toque num dia da semana abre o treino do dia.
- (31/10, E7) Observação pode ser privada; o educador perde o acesso quando o
  vínculo sai de ATIVO, sem apagar nada; o PDF leva treinos + evoluções
  (respeitando a privacidade); o aluno pode excluir o plano do professor após o
  fim do vínculo. PDF para atleta e educador, botão na aba Progresso e na tela do
  aluno, 90 dias configuráveis, gerado no backend (QuestPDF Community).
- PBI-90: "Concluir exercício" no fim da aba Séries; descanso conta negativo com
  o aviso "Descanso acabou, volte ao treino".
- PBI-75: confirmação usa a pílula `mostrarAviso`; erro usa `mostrarErro`.
- (05/11, PBI-35) Semana pertence ao plano; semana fixa; no máximo 1 ficha por
  dia; "fez" = treinou no dia com qualquer ficha; sem atalho novo na Início;
  calendário do mês, rotação e notificações ficam fora; semana opcional.
- (12/11, PBI-98) A TMB calculada é a padrão; o atleta pode informar outra
  (800 a 5.000 kcal), que vale até ele voltar ao cálculo.
- (13/11) A PBI-99 foi descartada ("pode ignorar").
- (12/11, E13) Exercícios conjugados em bloco de 2 a 4, com um descanso só por
  rodada; rodadas = maior número de séries; exercício sozinho continua igual.
- (13/11, PBI-101) Juntar escolhendo os exercícios ("Juntar com…"), e não só o
  de baixo.
- (13/11, PBI-35) Todo dia passado sem treino mostra o "X", também o dia sem ficha
  planejada (antes ficava como descanso, sem "X").

### Perguntas ainda abertas com o PO
- **PBI-34** (trocar a métrica de intensidade no registro): (a) por série no
  registro, flexível, mas o gráfico precisa agrupar por métrica; ou (b) no alvo
  da ficha, mais previsível e com mudança de banco? **Bloqueia a implementação.**
  Recomendação: (a), com o gráfico agrupando por métrica num passo seguinte
  (falta conferir como o rascunho escolhe a métrica quando há histórico).
- **PBI-73:** melhor série × total de repetições no gráfico só de repetições.
- **Termo de consentimento:** o texto atual é provisório; falta o texto jurídico.
- **Cardio:** como a zona é definida (FC, pace ou percepção) — resposta do Vinicius.
- **E12 (PBI-95 e 96), assumido e a confirmar:** o atleta libera para todos os
  educadores com vínculo ativo (sem escolher por educador) e há dois cadeados
  separados, dados corporais e medidas, trancados por padrão. Já implementado
  assim; se o PO quiser outra coisa, vira ajuste.
- **E13 (interpretações a confirmar):** o item 5 da ficha não tem descanso; a
  panturrilha acompanha as 2 séries da isometria; o descanso vale também depois da
  última rodada; "Rodada feita" marca com os valores pré-preenchidos.
- **PBI-100:** em qual navegador e aparelho o PO viu o valor antigo, e se foi no
  modo educador.
- **Educador e CREF:** proposta de verificação do educador conversada, ainda sem
  PBI registrada.
- **Ficha do professor:** a API não aplica o 403 nas rotas de ficha, exercício e
  bloco (o app esconde as ações). Alinhar com a regra do plano?

### Pendências de infraestrutura
- Domínio próprio (hoje `*.fly.dev` e `*.workers.dev`).
- Resetar a senha do role do Neon (foi digitada em texto durante o setup).
- Ruído de log cosmético na API (`libgssapi_krb5.so.2`), sem efeito na conexão.
- Confirmar que o `deploy-web` segue verde com o Wrangler v4.

---

## 9. Ponto de retomada

Incremento 1 (atleta), E7 (educador), E12 até a PBI-98 e E13 (exercícios
conjugados) estão na `main` (último PR: #148); as PBIs 95 e 96 (compartilhar o
corpo, fecha o E12) estão no PR desta entrega. Próximos passos:

**Com o PO (conferir o que foi entregue)**
1. **E13:** o PO usar o bloco na ficha real dele (montar, treinar ao vivo, ver o
   histórico) e confirmar as interpretações do épico (seção 8). As telas foram
   feitas sem protótipo, seguindo o design system.
2. **Ajuste do "X" (#148):** avisar o PO de que a regra da PBI-35 mudou.
3. **PBI-100:** conferir no Safari do iPhone. Se o valor antigo continuar,
   reler a ficha à força ao voltar da tela de alvos.
4. **E12 · PBIs 95 e 96:** confirmar as respostas assumidas para as perguntas 1
   e 2 (todos os educadores com vínculo ativo; dois cadeados) e conferir as telas
   "Compartilhar com o educador" e "Corpo" do aluno nos dois temas.

**Esperando o PO para começar**
5. **PBI-34:** decidir (a) × (b) e implementar.
6. **Cardio (PBI-27 a 30):** definição de zona com o Vinicius.
7. **CREF / verificação do educador:** decidir se vira PBI.

**Técnico (sem bloqueio)**
8. Aplicar a regra do autor (403) nas rotas de ficha, exercício e bloco, se o PO
   confirmar que a regra do plano vale para elas.
9. Versão no JSON do rascunho local do treino, para mudanças de formato não
   apagarem um treino em andamento.
10. E2E: deixar os fluxos independentes do banco de uma execução anterior (o
    retry do CI roda no mesmo banco).
11. Teto do descanso nos alvos do exercício (hoje só ≥ 0; o bloco usa 0 a 600),
    depois de ver se há dado acima de 600 em produção.

**Depois**
12. **E8 a E11:** épicos futuros do [BACKLOG](BACKLOG.md), seção 9.
13. Texto jurídico do termo de consentimento (também cobre a privacidade do E12
    e os textos de compartilhamento) antes de abrir ao público.
14. Pendências de infraestrutura (seção 8).
