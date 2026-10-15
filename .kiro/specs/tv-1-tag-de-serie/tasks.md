# TV-1 · Tag de série — Tarefas

> PBI TV-1 do épico "Treino ao vivo, série por série" (Release 1).

Ordem por camada, respeitando a regra de dependência (MAS 9.1):
`Domain → Application → Api` e `Infrastructure → Application`. O front vem depois
de a API estar verde. Cada tarefa referencia os requisitos que atende.

## Backend — domínio e banco

- [ ] 1. Enum `TagSerie` no Domain
  - Adicionar classe estática `TagSerie` em `Domain/Comum/Enums.cs` com os 10
    códigos (`VALIDA`, `AQUECIMENTO`, `PREPARATORIA`, `TOP_SET`, `BACK_OFF`,
    `FALHA`, `DROP_SET`, `REST_PAUSE`, `NEGATIVA`, `PARCIAIS`), `Todos` e `Valida`.
  - _Requisitos: 6.3_

- [ ] 2. Campo `Marcador` em `SerieExecutada` e entidade `RodadaMarcador`
  - `Execucao/SerieExecutada.cs`: `Marcador` (default `TagSerie.Valida`).
  - `Planejamento/RodadaMarcador.cs`: nova entidade com PK composta
    `(TreinoExercicioId, Rodada)`.
  - `Planejamento/TreinoExercicio.cs`: coleção `Marcadores`.
  - _Requisitos: 1.1, 1.2, 7.1_

- [ ] 3. Mapeamento EF + migration
  - `SerieExecutadaConfiguration`: coluna `marcador varchar(20) NOT NULL DEFAULT
    'VALIDA'` + CHECK `ck_serie_executada_marcador` derivado de `TagSerie.Todos`.
  - Nova `RodadaMarcadorConfiguration`: tabela `rodada_marcador`, PK composta, FK
    `ON DELETE CASCADE`, CHECK do marcador e CHECK `rodada >= 1`.
  - `DbContext`: `DbSet<RodadaMarcador>`.
  - Gerar migration `TagDeSerie` (+ Designer + snapshot); conferir que aplica do
    zero sem erro. Sem backfill (default cobre os antigos).
  - _Requisitos: 6.3, 7.1, 7.2_

## Backend — aplicação (prescrição / ficha)

- [ ] 4. DTOs e validação dos marcadores da ficha
  - `PlanoDtos.cs`: `MarcadorRodada(short Rodada, string Marcador)`;
    `DefinirAlvosRequest.Marcadores`; `TreinoExercicioResumo.Marcadores`.
  - `DefinirAlvosValidator.cs`: código em `TagSerie.Todos` e `Rodada` entre 1 e
    `Series`.
  - _Requisitos: 1.1, 1.2, 1.3, 6.1, 6.2_

- [ ] 5. `ServicoPlanejamento.DefinirAlvosAsync` sincroniza `rodada_marcador`
  - Apaga marcadores existentes do `treino_exercicio` e regrava os informados
    que sejam ≠ `VALIDA` e com rodada ∈ [1, Series]. Projetar `Marcadores` na
    leitura (`TreinoDetalhe`/`TreinoExercicioResumo`).
  - _Requisitos: 1.1, 1.2, 1.3_

## Backend — aplicação (execução / sessão)

- [ ] 6. DTOs e validação do marcador na sessão
  - `SessaoDtos.cs`: `SerieRequest.Marcador` (opcional), `SerieDetalhe.Marcador`,
    `SerieRascunho.Marcador`.
  - `CriarSessaoValidator.cs` (`SerieValidator`): `Marcador` nulo ou ∈
    `TagSerie.Todos`.
  - _Requisitos: 3.1, 4, 6.1_

- [ ] 7. `ServicoSessao`: gravar, ler e pré-preencher a tag
  - `CriarSessaoAsync`/`EditarSessaoAsync`: grava `Marcador ?? VALIDA`.
  - `ObterSessaoAsync`: projeta `Marcador` no `SerieDetalhe`.
  - `MontarRascunhoAsync` / `ultima-execucao`: pré-preenche por rodada na ordem
    ficha → última sessão → `VALIDA`.
  - _Requisitos: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2_

- [ ] 8. Confirmar que o gráfico (PBI-20) não mudou
  - Revisar `RepositorioProgresso`/`ServicoProgresso`: nenhuma referência a
    `Marcador`. Teste que prova que uma série `AQUECIMENTO` de maior carga ainda
    é o ponto do dia.
  - _Requisitos: 5.1, 5.2_

## Backend — testes

- [ ] 9. Testes unitários
  - Enum/validator (código inválido, rodada fora de 1..Series → 400); prioridade
    do pré-preenchimento; corte de marcadores ao reduzir rodadas.
  - _Requisitos: 1.3, 2.4, 6.1, 6.2_

- [ ] 10. Testes de integração
  - Ida e volta de `marcadores` na ficha; de `marcador` na sessão (grava → lê no
    detalhe); troca na sessão não altera a ficha (CA 3.2); dados antigos leem
    `VALIDA` (CA 7.1); caso "outro usuário" → 404 nos endpoints com marcador.
  - _Requisitos: 1.1, 3.1, 3.2, 7.1, 8.1, 8.2_

## Frontend

- [ ] 11. Constantes e models da tag
  - `tag_serie.dart` (`TagSerieInfo`: lista fixa com rótulo/descrição/cor).
  - `sessao_models.dart` (`SerieRascunho`/`SerieDetalhe` + `marcador`),
    `sessao_edicao.dart` (`SerieEdicao.marcador`, `copiarComoRodada`),
    `plano_models.dart` (`TreinoExercicioResumo.marcadores`, `MarcadorRodada`).
  - _Requisitos: 2.1, 2.2, 4_

- [ ] 12. Componente `SeletorTagSerie` (chip + bottom sheet)
  - `shared/widgets/seletor_tag_serie.dart`: `ChipTagSerie` (leitura/edição) e
    `abrirSeletorTagSerie` (lista de baixo pra cima, 10 opções, atual marcada).
  - Cores/raios/espaçamentos por token; `Semantics` em chip e opções. `VALIDA`
    sem chip no modo leitura; "Válida" em `textSecondary` no modo edição.
  - _Requisitos: 4.1, 4.2, 4.3, 4.5_

- [ ] 13. Chip no registro e no detalhe
  - `registrar_sessao_screen.dart` (`_LinhaSerie`): chip de edição no lugar do
    número da série, ligado a `SerieEdicao.marcador`.
  - `detalhe_sessao_screen.dart` (`_LinhaSerie`): chip de leitura.
  - _Requisitos: 3.1, 4.1, 4.3, 4.4_

- [ ] 14. Tags na edição da ficha
  - `editar_alvos_screen.dart`: lista de N chips (um por série prescrita) ligados
    aos marcadores; reduzir séries descarta os marcadores das rodadas que sumiram.
  - _Requisitos: 1.1, 1.3_

- [ ] 15. Serialização nos repositories
  - `sessao_repository.dart` (`_serializarSeries`): envia `marcador`.
  - `fichas_repository.dart` (`definirAlvos`): envia `marcadores` (≠ `VALIDA`).
  - _Requisitos: 1.1, 1.2, 3.1_

- [ ] 16. Testes de widget
  - Chip ausente para `VALIDA` em leitura; presente com rótulo/cor para tag ≠
    `VALIDA`; seletor troca o valor; herança da tag no registro. Conferir nos
    dois temas.
  - _Requisitos: 2.1, 4.1, 4.2, 4.3_

## Fechamento

- [ ] 17. Verificação e documentação
  - `dotnet build` Release (warnings-as-errors) + testes verdes; `flutter
    analyze` 0 issues + `flutter test` verde.
  - Atualizar MER (seção 7: `rodada_marcador` + `serie_executada.marcador`) e o
    BACKLOG (entrada do PBI-38 com status).
  - _Requisitos: 7.2, 8.1_
