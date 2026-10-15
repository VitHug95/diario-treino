# TV-1 · Tag de série — Design

> PBI TV-1 do épico "Treino ao vivo, série por série" (Release 1).

## Visão geral

A tag de série é um **marcador de identificação** por série, com uma lista fixa
de 10 códigos. Ela é **ortogonal** ao campo `Tipo` que já existe em
`SerieExecutada`/`EtapaPrescrita` (`ESFORCO`/`RECUPERACAO`, vocabulário de
esforço×recuperação do intervalado). Por isso a tag é um **campo novo**, não um
reaproveitamento do `Tipo` — crucial para não quebrar o gráfico de progresso
(PBI-20), que filtra por `Tipo == ESFORCO`.

Dois lugares guardam a tag:
- **Prescrição (ficha):** por rodada de um `treino_exercicio` → tabela nova
  `rodada_marcador`. A ficha hoje tem uma única `etapa_prescrita` (molde que
  vale para todas as séries), então a tag — que é de uma série específica — não
  cabe em `etapa_prescrita`; ganha tabela própria por rodada.
- **Execução (sessão):** por série feita → coluna nova
  `serie_executada.marcador`.

## Decisões

1. **Campo separado, não o `Tipo`.** `Tipo` continua `ESFORCO`/`RECUPERACAO`. A
   tag vira `Marcador` (enum `TagSerie`), seguindo o padrão de enum-string do
   Domain (`Domain/Comum/Enums.cs`).
2. **`VALIDA` é o default e não ocupa linha na prescrição.** `rodada_marcador`
   só guarda rodadas com tag ≠ `VALIDA`; rodada sem linha vale `VALIDA`. Em
   `serie_executada`, `marcador` é `NOT NULL DEFAULT 'VALIDA'` (registros
   antigos ficam `VALIDA` sem backfill explícito além do default).
3. **Gráfico intocado.** `RepositorioProgresso` não é tocado. A tag não entra em
   nenhuma query de progresso.
4. **Enum em um lugar só.** `TagSerie` (Domain) é a fonte; o `CHECK` da migration
   e a validação do FluentValidation derivam de `TagSerie.Todos`.
5. **Front trata a tag como `String`** (convenção do projeto — não há enum Dart
   de domínio). Os rótulos/descrições/cores vêm de uma tabela de constantes no
   front (`TagSerieInfo`), espelhando a lista fixa.

## Backend

### Domínio (`DiarioTreino.Domain`)

- `Comum/Enums.cs`: nova classe estática `TagSerie` com as 10 `const string` e
  `IReadOnlyList<string> Todos`. Um helper `EhValida(string)` opcional.
- `Execucao/SerieExecutada.cs`: novo `public string Marcador { get; set; } =
  TagSerie.Valida;`.
- `Planejamento/RodadaMarcador.cs` (novo): entidade
  `{ Guid TreinoExercicioId; short Rodada; string Marcador; TreinoExercicio? }`,
  PK composta `(TreinoExercicioId, Rodada)`.
- `Planejamento/TreinoExercicio.cs`: `ICollection<RodadaMarcador> Marcadores`.

### EF Core (`DiarioTreino.Infrastructure/Persistencia`)

- `Configuracoes/ExecucaoConfiguration.cs` (`SerieExecutadaConfiguration`):
  mapear `Marcador` → coluna `marcador varchar(20) NOT NULL DEFAULT 'VALIDA'`;
  novo CHECK `ck_serie_executada_marcador` com `IN (...TagSerie.Todos...)`.
- `Configuracoes/PlanejamentoConfiguration.cs`: nova
  `RodadaMarcadorConfiguration` → tabela `rodada_marcador`, PK
  `(treino_exercicio_id, rodada)`, FK para `treino_exercicio` com
  `ON DELETE CASCADE`, CHECK `ck_rodada_marcador_marcador` (mesma lista) e CHECK
  `rodada >= 1`.
- `DiarioTreinoDbContext.cs`: `DbSet<RodadaMarcador>`.
- Migration nova `AAAAMMDDHHMMSS_TagDeSerie` (+ Designer + snapshot) seguindo o
  padrão. Conteúdo: `ADD COLUMN marcador` em `serie_executada` com default e
  check; `CREATE TABLE rodada_marcador` com PK/FK/checks. Aplica do zero sem
  erro. **Sem backfill** (default cobre os antigos).

### Aplicação (`DiarioTreino.Application`)

**Prescrição (ficha):**
- `Planejamento/PlanoDtos.cs`:
  - `DefinirAlvosRequest` ganha
    `IReadOnlyList<MarcadorRodada>? Marcadores` (só rodadas ≠ `VALIDA`).
  - `MarcadorRodada(short Rodada, string Marcador)` (novo record).
  - `TreinoExercicioResumo` ganha
    `IReadOnlyList<MarcadorRodada> Marcadores` (os prescritos).
- `Planejamento/ServicoPlanejamento.DefinirAlvosAsync`: ao salvar alvos,
  sincroniza `rodada_marcador`: apaga os existentes do `treino_exercicio` e
  regrava os informados que (a) sejam ≠ `VALIDA` e (b) tenham `Rodada` entre 1 e
  `Series`. Reduzir séries ⇒ marcadores de rodada > Series somem naturalmente
  (ficam fora do filtro).
- `Planejamento/DefinirAlvosValidator.cs`: valida cada marcador — código em
  `TagSerie.Todos` e `Rodada` entre 1 e `Series` → 400.
- Leitura (`TreinoDetalhe`/rascunho): projetar os marcadores do
  `treino_exercicio`.

**Execução (sessão):**
- `Execucao/SessaoDtos.cs`:
  - `SerieRequest` ganha `string? Marcador` (ausente/nulo ⇒ `VALIDA`).
  - `SerieDetalhe` e `SerieRascunho` ganham `string Marcador`.
- `Execucao/CriarSessaoValidator.cs` (`SerieValidator`): `RuleFor(x =>
  x.Marcador).Must(m => m is null || TagSerie.Todos.Contains(m))` → 400.
- `Execucao/ServicoSessao.cs`:
  - `CriarSessaoAsync`/`EditarSessaoAsync`: gravar `Marcador = s.Marcador ??
    TagSerie.Valida` em cada `SerieExecutada`.
  - `ObterSessaoAsync` (detalhe): projetar `Marcador` em `SerieDetalhe`.
  - `MontarRascunhoAsync`: pré-preencher a tag por rodada na ordem de prioridade
    (ficha → última sessão → `VALIDA`). A última execução já é lida aqui; passa a
    trazer `Marcador`. Quando vem de ficha, cruza com `rodada_marcador`.

**Autorização:** nenhuma regra nova. A tag entra em endpoints que já chamam
`IControleAcesso` (alvos da ficha, sessão). Os testes de 404 "outro usuário"
desses endpoints já existem; adicionar asserções de marcador onde fizer sentido.

### API (`DiarioTreino.Api/Endpoints`)

Nenhum endpoint novo. Os contratos mudam dentro de:
- `PlanoEndpoints`: `PUT /treinos/{id}/exercicios/{teId}/alvos` (aceita
  `marcadores`), `GET /treinos/{id}` (devolve `marcadores`).
- `SessaoEndpoints`: `POST`/`PUT /sessoes` (aceita `marcador` por série),
  `GET /sessoes/{id}` e `GET /treinos/{id}/rascunho-sessao` /
  `GET /exercicios/{id}/ultima-execucao` (devolvem `marcador`).

## Frontend (Flutter, `app/lib`)

### Modelo e constantes
- Novo `features/sessao/tag_serie.dart` (ou em `shared/`): `TagSerieInfo` com a
  lista fixa — código, rótulo, descrição, e se usa cor `primary` suave ou
  neutra. Helpers: `rotulo(cod)`, `descricao(cod)`, `ehValida(cod)`,
  `lista` (ordem do PDF). Tag trafega como `String`.
- `features/sessao/sessao_models.dart`: `SerieRascunho` e `SerieDetalhe` ganham
  `String marcador` (default `'VALIDA'` quando ausente no JSON).
- `features/sessao/sessao_edicao.dart`: `SerieEdicao` ganha `String marcador`
  mutável; `.doRascunho`/`.doDetalhe` leem; `copiarComoRodada` propaga a tag.
- `features/fichas/plano_models.dart`: `TreinoExercicioResumo` ganha
  `List<MarcadorRodada> marcadores`; novo model `MarcadorRodada(rodada,
  marcador)`.

### Componente de seletor (reuso nas 3 telas)
- Novo `shared/widgets/seletor_tag_serie.dart`:
  - `ChipTagSerie`: o chip. No modo leitura, `VALIDA` não renderiza nada; tag ≠
    `VALIDA` renderiza chip (cor por token: neutra = `bgInput`+`lineDefault`;
    primary suave = `primaryTint`+`primaryText`). No modo edição, mostra o
    rótulo (ou "Válida" em `textSecondary`) com um ▾, e ao tocar abre o seletor.
  - `abrirSeletorTagSerie(context)`: `showModalBottomSheet` (lista de baixo pra
    cima) com as 10 opções (rótulo + descrição) e a atual marcada; devolve o
    código escolhido.
  - Acessibilidade: cada chip com `Semantics(label: 'Tag da série N: Rótulo')`;
    cada opção do seletor com o rótulo como label. Tudo por token (cor/raio/
    espaçamento), nada de literal.

### Telas
- `features/sessao/registrar_sessao_screen.dart` (`_LinhaSerie`): o
  `SizedBox(width: 24)` com o número da rodada passa a conviver com o
  `ChipTagSerie` em modo edição (mesmo lugar do número da série, protótipo 15),
  ligado ao `SerieEdicao.marcador`.
- `features/sessao/detalhe_sessao_screen.dart` (`_LinhaSerie`): `ChipTagSerie`
  em modo leitura ao lado da série (reusa a ideia do `_Chip` que já existe).
- `features/fichas/editar_alvos_screen.dart`: como hoje a tela tem uma
  prescrição única e um stepper de séries (1–12), adiciona-se uma lista de N
  chips (um por série prescrita), cada um ligado a um marcador local; ao salvar,
  envia `marcadores` (só ≠ `VALIDA`) no `definirAlvos`. Ao reduzir o número de
  séries, descarta os marcadores das rodadas que sumiram.

### Repository (serialização)
- `features/sessao/sessao_repository.dart` (`_serializarSeries`): inclui
  `'marcador': s.marcador` quando ≠ `VALIDA` (ou sempre; o back aceita nulo).
- `features/fichas/fichas_repository.dart` (`definirAlvos`): inclui
  `'marcadores': [...]` com `{rodada, marcador}` das rodadas ≠ `VALIDA`.

## Riscos e mitigação
- **Acoplamento do gráfico ao `Tipo`:** mitigado por a tag ser campo separado;
  `RepositorioProgresso` fica intocado (CA do Requisito 5).
- **Prescrição de tag por série vs. etapa única:** a tabela `rodada_marcador`
  resolve sem mexer na `etapa_prescrita`.
- **Dados antigos:** default `'VALIDA'` + ausência de linha ⇒ sem backfill
  arriscado (CA do Requisito 7).

## Testes

**Unitário (xUnit):**
- Validação do enum (`TagSerie.Todos`) e do validator (código inválido, rodada
  fora de 1..Series → 400).
- Regra de prioridade do pré-preenchimento (ficha → última sessão → `VALIDA`).
- Corte de marcadores ao reduzir rodadas.

**Integração (Testcontainers + WebApplicationFactory):**
- Ida e volta de `marcadores` no item da ficha (define, relê, confere).
- Ida e volta de `marcador` na sessão (grava, lê no detalhe).
- Caso "outro usuário" → 404 nos endpoints que ganham marcador.
- Dados antigos (sem marcador) leem como `VALIDA`.

**Widget / Robot (front):**
- Widget: chip não aparece para `VALIDA` em leitura; aparece com rótulo/cor para
  tag ≠ `VALIDA`; seletor troca o valor; herança no registro.
- Robot (quando o E2E estiver destravado): cada chip com label "Tag da série N:
  Rótulo"; cada opção do seletor com o nome como label. Cenários dos CA 1, 3 e 4.

## Definition of Done (BACKLOG 4)
Código revisado e na `main`; CI verde (build + unit + integração); migration
aplica do zero; endpoints com marcador passam pela regra de acesso e têm teste
404; telas conferidas nos dois temas com rótulo de acessibilidade; MER/MAS
atualizados se alguma decisão mudar (aqui: MER seção 7 ganha `rodada_marcador` e
`serie_executada.marcador`).
