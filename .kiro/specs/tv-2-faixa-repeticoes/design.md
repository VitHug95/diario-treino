# TV-2 · Faixa de repetições na prescrição — Design

> PBI TV-2 do épico "Treino ao vivo, série por série" (Release 1).

## Visão geral

Adiciona um limite superior **opcional** ao volume prescrito de um exercício da
ficha: `etapa_prescrita.volume_alvo_max`. O `volume_alvo` existente passa a ser o
mínimo da faixa; o máximo é opcional. Nada muda quando o máximo é nulo. Vale para
qualquer métrica de volume (reps, tempo). Só prescrição — não toca sessão,
`serie_executada`, nem o gráfico (PBI-20).

## Decisões
1. **Coluna nova, nullable, sem backfill.** `volume_alvo_max numeric(9,2) NULL`
   com `CHECK (volume_alvo_max IS NULL OR volume_alvo_max >= volume_alvo)`.
   Registros antigos ficam nulos (sem faixa).
2. **Faixa só no eixo VOLUME.** A intensidade (carga) continua valor único
   (fora de escopo).
3. **Formatação centralizada no front** num helper reusável (ficha, resumo e,
   futuramente, cabeçalho da TV-4), para "8 a 12 reps" / "10 reps" saírem iguais
   em todo lugar.

## Backend

### Domínio (`DiarioTreino.Domain`)
- `Planejamento/EtapaPrescrita.cs`: novo `public decimal? VolumeAlvoMax { get; set; }`.

### EF Core (`Infrastructure/Persistencia`)
- `Configuracoes/PlanejamentoConfiguration.cs` (`EtapaPrescritaConfiguration`):
  mapear `VolumeAlvoMax` → coluna `volume_alvo_max` `HasPrecision(9,2)`; novo
  CHECK `ck_etapa_prescrita_volume_max`:
  `volume_alvo_max IS NULL OR volume_alvo_max >= volume_alvo`.
- Migration nova `FaixaRepeticoes` (+ Designer + snapshot): `AddColumn` +
  `AddCheckConstraint`. Aplica do zero sem erro; sem backfill.

### Aplicação (`DiarioTreino.Application/Planejamento`)
- `PlanoDtos.cs`:
  - `AlvoExercicio` ganha `decimal? VolumeAlvoMax` (leitura).
  - `DefinirAlvosRequest` ganha `decimal? VolumeAlvoMax` (opcional, default null).
- `DefinirAlvosValidator.cs`:
  - `VolumeAlvoMax >= 0` quando informado;
  - `VolumeAlvoMax >= VolumeAlvo` quando ambos presentes;
  - `VolumeAlvo` obrigatório quando `VolumeAlvoMax` vem (o máximo depende do mín).
- `ServicoPlanejamento.cs`:
  - `DefinirAlvosAsync`: grava `VolumeAlvoMax` na etapa.
  - `MapearAlvoAsync`: projeta `VolumeAlvoMax` no DTO.
  - Pré-preenchimento (`ServicoSessao.MontarSeriesDosAlvosAsync`) continua usando
    `etapa.VolumeAlvo` (o mínimo) — **nada a mudar** (CA 3). Confirmar.

### API
Nenhum endpoint novo. `PUT /treinos/{id}/exercicios/{teId}/alvos` e
`GET /treinos/{id}` passam a aceitar/devolver `volumeAlvoMax`.

## Frontend (`app/lib`)
- `features/fichas/plano_models.dart`: `AlvoExercicio.volumeAlvoMax` (double?,
  parse de `json['volumeAlvoMax']`).
- `features/fichas/fichas_repository.dart` (`definirAlvos`): novo parâmetro
  `double? volumeAlvoMax`, enviado no corpo.
- `features/fichas/editar_alvos_screen.dart`:
  - Novo controller `_volumeAlvoMax`, inicializado de `alvo?.volumeAlvoMax`.
  - Um `_CampoAlvo` "até (opcional)" ao lado/abaixo do alvo de volume.
  - Validação local antes de salvar: se `max` preenchido e (`min` vazio ou
    `max < min`) → `_erro(...)` e não salva.
  - `_salvar` envia `volumeAlvoMax`.
  - `_Resumo`: quando há faixa, mostra "de 8 a 12 reps"; senão, como hoje.
- Helper de formatação `formatarVolumeAlvo(min, max, unidade)` em
  `shared/` (ou em `plano_models`): "8 a 12 reps" / "10 reps" / "30 a 45 s".
  Reusado no resumo e onde o plano é exibido.
- Exibição do plano no detalhe da sessão (`ServicoSessao.MontarPlanoAsync`, back)
  já monta "3 × 10 com 30 kg": estender para "3 × 8 a 12 com 30 kg" quando houver
  faixa (usa `VolumeAlvoMax`).

## Testes

**Unit (xUnit):**
- Validator: `max < min` → inválido; `max` sem `min` → inválido; `max == min` e
  `max > min` → válidos.
- (front) formatação: "8 a 12 reps", "10 reps", "30 a 45 s".

**Integração:**
- Ida e volta de `volumeAlvoMax` no item da ficha (define, relê).
- `max < min` → 400; `max` sem `min` → 400.
- Dados antigos: alvo sem faixa relê com `volumeAlvoMax` nulo.
- Caso "outro usuário" → 404 (já coberto pelo endpoint; adicionar asserção se útil).

**Widget / Robot:**
- Widget: resumo com faixa e sem faixa; bloqueio de salvar com faixa inválida.
- Robot (quando o E2E permitir): cenários 1, 2 e 3.

## Definition of Done
Build Release 0 avisos; unit + integração verdes (integração no CI); migration
aplica do zero; endpoint com a regra de acesso; telas nos dois temas com rótulo;
MER atualizado (etapa_prescrita.volume_alvo_max) e BACKLOG (TV-2 status).
