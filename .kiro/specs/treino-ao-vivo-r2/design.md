# Treino ao vivo (Release 2) — Design

> Épico "Treino ao vivo", Release 2 (TV-3..TV-6). Branch única
> `feat/treino-ao-vivo-r2`, flag `treinoAoVivoHabilitado`.

## Princípio: evoluir o PBI-37, não reescrever

O PBI-37 já entregou a fundação: `RascunhoTreinoService` + `treinoEmAndamentoProvider`
(`treino_em_andamento.dart`), autosave por controller, duração automática por
horário de início, diálogo de sair (Finalizar/Continuar depois/Descartar), card
"Continuar treino" na Início e os botões "Iniciar/Registrar já feito" na ficha.
O Release 2 **adiciona** sobre isso:
- **TV-3:** uma tela nova 14 (visão "em andamento" com cronômetro vivo + cards
  por exercício), reaproveitando o rascunho/estado que já existe.
- **TV-4:** uma tela nova por exercício (check por série), que grava no mesmo
  rascunho; + 1 endpoint de leitura.
- **TV-5:** barra de descanso (timer por horário de fim), gravando o descanso na
  série.
- **TV-6:** uma tela de resumo antes do `POST /sessoes` (que já existe).

A tela 3 atual (`registrar_sessao_screen.dart`) **continua** servindo o
"Registrar treino já feito" e a edição (PBI-18) — não é removida.

## Flag

`const bool treinoAoVivoHabilitado = bool.fromEnvironment('TREINO_AO_VIVO', defaultValue: false);`
em `app/lib/core/flags.dart` (nova). Enquanto false:
- "Iniciar treino agora" (ficha e Início) mantém o comportamento atual (abre a
  tela 3 em andamento).
Quando true (ao fim do Release 2):
- "Iniciar treino agora" abre a **tela 14** (TV-3); "Continuar treino" idem.
Em dev/CI do Robot, roda com `--dart-define=TREINO_AO_VIVO=true`.

## Clock injetável (teste de timers)

Novo `app/lib/core/relogio.dart`: `abstract class Relogio { DateTime agora(); }`
+ `RelogioDoSistema`. Provider `relogioProvider` (default sistema; testes
sobrepõem com um fake). Cronômetro (TV-3) e descanso (TV-5) calculam tudo por
`relogio.agora()` − horário de início/fim; nunca por `Timer` acumulado. Um
`Ticker`/`Timer.periodic(1s)` só dispara **rebuild** (não conta tempo): o valor
exibido é sempre `agora - inicio`.

## TV-3 — Treino em andamento (tela 14)

### Estado / rascunho
- `SerieEmAndamento` ganha `marcador` (hoje perde a tag ao reabrir) e
  `descansoSeg` já existe como texto. Persistir a tag é a única mudança no
  modelo do rascunho.
- Autosave passa a valer também no **treino livre** iniciado ao vivo (hoje o
  `TreinoLivreScreen` não liga o autosave) — ao abrir "ao vivo", monta um
  `TreinoEmAndamento` com `treinoLivre: true`.
- Check **por série**: a noção de "série feita" passa a ser por série (campo novo
  `feita` em `SerieEmAndamento`/`SerieEdicao`), não só `ExercicioEdicao.realizado`.
  Um exercício é "concluído" quando todas as suas séries estão feitas; o contador
  N/M conta séries feitas / total.

### Telas e navegação
- Nova `TreinoAoVivoScreen` (tela 14): cabeçalho (nome da ficha, `CronometroVivo`
  com `role=timer`, "Começou às HH:MM", "N/M séries feitas"); um `CardExercicioVivo`
  por exercício (barra segmentada por série + status "2/4", "Concluído",
  "0/4 · ainda não começou"); "+ Adicionar exercício fora da ficha"; botão
  "Finalizar"; seta de sair → diálogo (reusa a lógica do PBI-37). Tocar num card
  abre a `ExercicioAoVivoScreen` (TV-4).
- Rotas novas em `app_router.dart`: `treinoAoVivo` (`/fichas/ao-vivo`) e
  `exercicioAoVivo` (`/fichas/ao-vivo/exercicio`). O estado vivo é mantido por um
  controller Riverpod (ver abaixo), não por `extra`.
- Início/ficha: quando a flag liga, "Iniciar treino agora" e "Continuar treino"
  empurram `treinoAoVivo`.

### Controller do treino ao vivo
Novo `TreinoAoVivoController` (Notifier) que segura o estado vivo (lista de
`ExercicioEdicao` + início + ficha) em memória e **espelha** no
`RascunhoTreinoService` a cada mudança (autosave). A tela 14 e a tela do
exercício observam/alteram o mesmo controller — assim "completar série" numa tela
reflete o contador na outra sem `extra`/round-trip. Carrega do rascunho ao abrir;
`limpar()` ao finalizar/descartar.

## TV-4 — Tela do exercício (série por série)

- `ExercicioAoVivoScreen`: cabeçalho (espaço de mídia = membro, "Exercício N de
  M", nome, alvo+faixa [TV-2], descanso, tempo do treino), botões
  anterior/próximo (`Semantics(button)`, pontos de posição), abas Séries /
  Histórico / Evolução.
- **Séries:** três estados (feita / ativa / pendente). A ativa mostra "Última
  vez: …", o `ChipTagSerie` (TV-1) e `StepperMetrica` conforme a métrica
  (passos: carga 2,5; reps 1; tempo 5; zona 1 [1–5]; distância 100). "Completar
  série" → marca feita, próxima ativa, dispara descanso (TV-5). Tocar numa feita
  reabre. "Adicionar série" copia a última.
- **Histórico:** `GET /exercicios/{id}/historico?limite=3` → 3 últimas sessões
  (séries + observação em laranja). Estado vazio quando não há.
- **Evolução:** extrair o núcleo do gráfico (`progresso_screen.dart`:
  `_GraficoComDados`/`_DetalhePonto`) para `shared/progresso/grafico_exercicio.dart`
  público, recebendo `ProgressoExercicio`. Novo provider
  `progressoPorExercicioProvider.family<ProgressoExercicio?, String>` (não depende
  do `exercicioSelecionadoProvider` global). A aba Progresso passa a reusar o
  mesmo widget (refactor sem mudança visual).

### Backend do histórico
- `IRepositorioSessao.ObterHistoricoExercicioAsync(atletaId, exercicioId, limite)`
  → lista das N sessões mais recentes com o exercício (data, observação, séries),
  ordem data desc. Impl em `RepositorioSessao` espelhando `ObterUltimaExecucaoAsync`.
- `ServicoSessao.ObterHistoricoExercicioAsync`: valida exercício disponível +
  `IControleAcesso` (inexistente/outro usuário → 404), mapeia para DTO novo
  `HistoricoExercicio` (lista de `SessaoHistorico { Data, Observacao?, Series[] }`).
- Endpoint `GET /exercicios/{id}/historico` em `SessaoEndpoints.cs` no padrão dos
  demais. Teste de integração com o caso 404.
- App: `SessaoRepository.obterHistorico(id, limite)` + model Dart + provider family.

## TV-5 — Descanso automático

- `DescansoController` (Notifier) no controller do treino ao vivo: guarda
  `fimPrevisto` (horário) e o exercício/série de origem. Valor restante =
  `fimPrevisto - relogio.agora()`. +15/−15 ajustam `fimPrevisto`. "Pular" encerra
  e grava `descansoSeg = agora - inicioDescanso`.
- `BarraDescanso` fixa no rodapé da tela 14 e da tela do exercício: contagem
  regressiva (`role=timer`, label "Descanso, faltam M min e S s"), barra de
  progresso, botões "+15 s"/"−15 s"/"Pular" com `Semantics`. Ao zerar: muda de
  estado + `HapticFeedback` onde suportado (sem promessa no iPhone).
- Abre só quando o exercício tem descanso (ficha ou série). **Descanso nulo → não
  abre** (decisão do PO).

## TV-6 — Resumo ao finalizar

- `ResumoTreinoScreen` (tela 16): cabeçalho (nome da ficha, data editável [mesma
  regra do registro], duração do cronômetro arredondada e editável); números
  (Duração, Séries feitas/total, Volume kg = Σ carga×reps das feitas com carga);
  um bloco por exercício (séries + tag + status Completo/Incompleto N/M/Não
  realizado); observação do dia (laranja) antes do botão; "Salvar treino" e
  "Voltar ao treino".
- Salvar monta os `ExercicioEdicao` → `SessaoRepository.criarSessao` (POST
  existente, já envia marcador e descansoSeg). Só séries feitas. Sucesso: limpa o
  rascunho e mostra "Treino salvo" (Ver progresso / Voltar ao início). Falha de
  rede: mantém o rascunho, mostra erro, permite tentar de novo.
- Reaproveita helpers de `_salvar`/`_confirmarRegistro`/`_criarFichaDoTreino` da
  tela 3 onde fizer sentido (extrair o que for comum).

## Acessibilidade / design
- Tudo por token (AppColors/AppText/AppRadius/AppSpacing/AppSizes). Observação em
  laranja (`obs*`). Cronômetro e descanso com `Semantics(liveRegion: true)` +
  rótulo "role=timer"-equivalente. Botões anterior/próximo e completar série com
  `Semantics(button, label)`. Largura máx 600 no web. Alvo de toque 44.

## Testes
- **Unit (Dart):** cálculo do cronômetro e do descanso com `Relogio` fake; regra
  da série ativa; passo do stepper por métrica; contador N/M; volume do resumo;
  status por exercício; serialização do rascunho com `marcador`+`feita`.
- **Integração (backend):** `GET /exercicios/{id}/historico` (3 últimas, ordem,
  observação) + caso 404 outro usuário.
- **Widget:** card por exercício e barra de progresso; completar série muda
  contador; navegação anterior/próximo; resumo (números/status); barra de
  descanso abre/!abre, +15/−15/pular (com Relogio fake).
- **Robot (quando o E2E permitir):** labels "Iniciar treino agora", "Finalizar",
  "Continuar treino", cronômetro `role=timer`, "Diminuir/Aumentar carga",
  "Completar série", "Próximo exercício", barra de descanso. Cenários dos CA.

## Ordem de implementação (fatias) — ver tasks.md
Fundação (flag, Clock, modelo do rascunho) → TV-3 → endpoint histórico → TV-4 →
TV-5 → TV-6 → ligar a flag + testes + docs. O fluxo só fica acessível ao usuário
no fim; cada fatia mantém build/analyze/test verdes.
