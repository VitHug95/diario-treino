# Treino ao vivo (Release 2) — Tarefas

> Branch única `feat/treino-ao-vivo-r2`, flag `treinoAoVivoHabilitado`. Cada
> fatia mantém `flutter analyze` 0 + testes verdes e é commitada. O fluxo só
> fica visível ao usuário na última fatia (ligar a flag).

## Fundação

- [ ] 1. Flag + Clock + modelo do rascunho
  - `core/flags.dart`: `treinoAoVivoHabilitado` (bool.fromEnvironment).
  - `core/relogio.dart`: `Relogio`/`RelogioDoSistema` + `relogioProvider`.
  - `SerieEmAndamento` + `SerieEdicao`: persistir `marcador` e novo campo `feita`
    (check por série); `exercicioParaRascunho`/`paraEdicao` propagam.
  - _Req: TV-3.4, TV-3.9; base de tudo_

## Backend — histórico (TV-4)

- [ ] 2. Endpoint `GET /exercicios/{id}/historico?limite=3`
  - `IRepositorioSessao.ObterHistoricoExercicioAsync` + impl.
  - DTO `HistoricoExercicio`/`SessaoHistorico`; `ServicoSessao.ObterHistoricoExercicioAsync`
    (acesso + 404); endpoint em `SessaoEndpoints.cs`.
  - Integração: 3 últimas (ordem, observação) + 404 outro usuário. Build + unit.
  - _Req: TV-4.7, TV-4 API_

## TV-3 — treino em andamento (tela 14)

- [ ] 3. Controller do treino ao vivo + rotas
  - `TreinoAoVivoController` (estado vivo + espelho no rascunho/autosave; carrega
    do rascunho; limpar ao finalizar/descartar). Rotas `treinoAoVivo` e
    `exercicioAoVivo`.
  - _Req: TV-3.2, TV-3.4, TV-3.9_
- [ ] 4. Tela 14 (cabeçalho + cards + finalizar/sair)
  - `CronometroVivo` (role=timer, por Relogio); contador N/M; `CardExercicioVivo`
    (barra por série + status); "+ fora da ficha"; "Finalizar" (aviso de
    pendência → resumo); seta → diálogo (reusa PBI-37). Diálogo "outra ficha".
  - _Req: TV-3.1,2,3,5,6,7,8_

## TV-4 — tela do exercício

- [ ] 5. Gráfico reutilizável + provider por exercício
  - Extrair `shared/progresso/grafico_exercicio.dart` do `progresso_screen.dart`
    (sem mudança visual; aba Progresso passa a reusar). `progressoPorExercicioProvider.family`.
  - _Req: TV-4.8_
- [ ] 6. `ExercicioAoVivoScreen` (abas Séries/Histórico/Evolução)
  - Cabeçalho + anterior/próximo (Semantics, pontos). Séries: estados feita/
    ativa/pendente, `StepperMetrica` por métrica, `ChipTagSerie`, completar/
    reabrir/adicionar/remover. Histórico (3 últimas, obs laranja). Evolução
    (gráfico). Estado vazio sem histórico.
  - _Req: TV-4.1..9_

## TV-5 — descanso automático

- [ ] 7. `DescansoController` + `BarraDescanso`
  - Timer por horário de fim (Relogio); +15/−15/pular; grava `descansoSeg`;
    não abre quando o descanso é nulo; vibra onde dá; role=timer.
  - _Req: TV-5.1..7_

## TV-6 — resumo ao finalizar

- [ ] 8. `ResumoTreinoScreen` (tela 16)
  - Números (duração/feitas/volume), status por exercício, data/duração
    editáveis, observação; salvar (POST existente, só feitas) → limpa rascunho +
    "Treino salvo"; falha de rede mantém o rascunho; "Voltar ao treino".
  - _Req: TV-6.1..8_

## Fechamento

- [ ] 9. Ligar a flag + testes + docs + PR
  - "Iniciar treino agora"/"Continuar treino" abrem a tela 14 quando a flag liga.
  - Unit (cronômetro/descanso com Relogio fake, série ativa, stepper, contador,
    volume, status, rascunho) + widget + integração. `flutter analyze` 0;
    `flutter test` + backend verdes.
  - BACKLOG (TV-3..TV-6) e MAS/MER se necessário (sem mudança de banco). Push + PR.
