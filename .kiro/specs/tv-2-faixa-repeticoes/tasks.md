# TV-2 · Faixa de repetições — Tarefas

> PBI TV-2 do épico "Treino ao vivo" (Release 1). Ordem por camada
> (Domain → Application → Api → front), cada tarefa referencia os requisitos.

## Backend — domínio e banco

- [ ] 1. Campo `VolumeAlvoMax` no domínio + EF + migration
  - `EtapaPrescrita.cs`: `decimal? VolumeAlvoMax`.
  - `EtapaPrescritaConfiguration`: coluna `volume_alvo_max` `HasPrecision(9,2)` +
    CHECK `ck_etapa_prescrita_volume_max`
    (`volume_alvo_max IS NULL OR volume_alvo_max >= volume_alvo`).
  - Migration `FaixaRepeticoes` (+ Designer + snapshot); aplica do zero; sem backfill.
  - _Requisitos: 1, 2.3, 6.2_

## Backend — aplicação

- [ ] 2. DTOs + validação
  - `PlanoDtos.cs`: `AlvoExercicio.VolumeAlvoMax`; `DefinirAlvosRequest.VolumeAlvoMax`.
  - `DefinirAlvosValidator.cs`: `>= 0`; `>= VolumeAlvo`; exige `VolumeAlvo` quando
    `VolumeAlvoMax` presente.
  - _Requisitos: 2.1, 2.2_

- [ ] 3. Serviço grava, lê e mantém o pré-preenchimento
  - `ServicoPlanejamento.DefinirAlvosAsync`: grava `VolumeAlvoMax`.
  - `MapearAlvoAsync`: projeta `VolumeAlvoMax`.
  - `ServicoSessao.MontarPlanoAsync`: "3 × 8 a 12 com 30 kg" quando há faixa.
  - Confirmar que o pré-preenchimento sem histórico usa `VolumeAlvo` (mínimo) — sem mudança.
  - _Requisitos: 1, 3, 4.2, 5_

## Backend — testes

- [ ] 4. Unit + integração
  - Unit: validator (max<min inválido; max sem min inválido; max>=min válido).
  - Integração: ida-volta `volumeAlvoMax`; 400 (max<min e max sem min); dados
    antigos relêem nulo; (404 outro usuário se útil).
  - Build Release + unit verdes local; integração no CI.
  - _Requisitos: 1, 2, 6_

## Frontend

- [ ] 5. Model + repository
  - `plano_models.dart`: `AlvoExercicio.volumeAlvoMax`.
  - `fichas_repository.dart` (`definirAlvos`): parâmetro `volumeAlvoMax`.
  - Helper `formatarVolumeAlvo(min, max, unidade)`.
  - _Requisitos: 1, 4.1_

- [ ] 6. Tela de edição de alvos
  - Campo "até (opcional)" ligado a `_volumeAlvoMax`; init do alvo.
  - Validação local (max sem min / max<min bloqueia salvar).
  - `_salvar` envia `volumeAlvoMax`; `_Resumo` mostra a faixa.
  - _Requisitos: 1, 2.2, 4.1_

- [ ] 7. Testes de widget + fechamento
  - Widget: resumo com/sem faixa; bloqueio de faixa inválida.
  - `flutter analyze` 0; `flutter test` verde.
  - Atualizar MER (etapa_prescrita.volume_alvo_max) e BACKLOG (TV-2).
  - Push + PR (não mergear).
  - _Requisitos: 1, 2, 4, 6_
