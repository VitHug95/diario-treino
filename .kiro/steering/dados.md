---
inclusion: fileMatch
fileMatchPattern: 'backend/**'
---

# Modelo de dados — referência rápida

O modelo oficial e completo está no MER. Esta é uma referência de bolso para o
back-end. Em caso de divergência, vale o [MER](../../docs/MER.md).

## Convenções do banco (MER 1)

- `snake_case`, singular. PK `id` do tipo `uuid` gerado pela aplicação, exceto
  `metrica` (tabela de referência com `smallint`).
- `timestamptz` (UTC) para instantes; `date` para a data do treino.
- Enums como `varchar` com `CHECK`.
- Valores medidos em `numeric(9,2)`.
- Nada é apagado fisicamente quando há histórico ligado: usa-se `ativo = false`.

## Tabelas (MER 3)

`usuario`, `usuario_papel`, `vinculo` (estrutura pronta, uso futuro),
`metrica` (referência), `exercicio`, `plano_treino`, `treino`,
`treino_exercicio`, `etapa_prescrita`, `sessao`, `serie_executada`.

## Pontos que a migration precisa garantir

- Seed de `metrica` com os 6 registros: CARGA_KG(1), PESO_CORPORAL(2), ZONA(3),
  REPETICOES(10), TEMPO_SEG(11), DISTANCIA_M(12).
- `CHECK`s: papel, status do vínculo, modalidade, tipo de etapa/série, eixo da
  métrica, `data <= current_date + 1` em `sessao`, `volume >= 0`, `rodadas > 0`,
  `educador_id <> aluno_id`.
- Índices únicos parciais: um plano ativo por atleta
  `(atleta_id) WHERE ativo`; vínculo aberto único
  `(educador_id, aluno_id) WHERE status IN ('PENDENTE','ATIVO')`; nome de
  exercício único por catálogo `(lower(nome), coalesce(criado_por_id, uuid-zero))`.
- Índices de consulta do MER 4 (sessao por atleta+data, series por exercício, etc.).
- Cascatas: `treino_exercicio`/`etapa_prescrita`/`serie_executada` em
  `ON DELETE CASCADE` sob seus pais; `serie_executada.treino_exercicio_id` em
  `ON DELETE SET NULL`.

## Regras ligadas ao modelo (MER 5)

- Pré-preenchimento: a sessão abre com as séries da sessão mais recente do mesmo
  atleta que contenha aquele exercício; sem histórico, usa os alvos prescritos.
- Toda série tem par intensidade (eixo INTENSIDADE) + volume (eixo VOLUME); a
  métrica gravada precisa pertencer ao eixo correto (validado na aplicação).
- Modalidade da sessão é derivada dos exercícios das séries, sem coluna própria.
