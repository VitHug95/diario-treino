# TV-2 · Faixa de repetições na prescrição — Requisitos

> Épico: **Treino ao vivo, série por série** (pós-MVP). PBI **TV-2**, Release 1.
> Fonte: PDF do épico (p. 6-7). Referências: MER (etapa_prescrita), protótipos 13 e 15.
> Tipo: banco + API + front. Depende de: PBI-14 (alvos da ficha).
>
> **Definição de pronto do épico (vale aqui):** critérios de aceite + cenários
> Robot no CI; unit + integração das regras novas; tema claro/escuro, contraste
> ≥ 4,5:1, toque 44px, largura máx 600px no web; semântica em todo interativo
> (ADR-07); MER/MAS atualizados quando mexer em modelo/regra.

## Introdução

Como atleta (e, no futuro, como educador montando a ficha do aluno), quero
prescrever uma **faixa de repetições**, como "8 a 12", para a ficha refletir o
jeito que a gente realmente treina.

Hoje `etapa_prescrita` tem um único `volume_alvo`. A faixa entra como um
**limite superior opcional** (`volume_alvo_max`): se não for preenchido, nada
muda no comportamento atual. Vale para qualquer métrica de volume — repetições
("8 a 12 reps") ou tempo ("30 a 45 s"). A faixa é **só na prescrição**: não
muda o gráfico de progresso (PBI-20) nem o volume calculado.

---

## Requisitos

### Requisito 1 — Prescrever a faixa

**História:** Como atleta montando a ficha, quero informar um "até" ao lado do
alvo de volume, para prescrever uma faixa.

#### Critérios de aceite
1. QUANDO o atleta informa 8 no alvo e 12 no "até" e salva, ENTÃO a ficha passa
   a mostrar "8 a 12 reps".
2. QUANDO o atleta informa só o alvo 10 (sem "até"), ENTÃO a ficha mostra
   "10 reps", como hoje.
3. QUANDO a métrica de volume é tempo e o atleta informa 30 e 45, ENTÃO a ficha
   mostra "30 a 45 s".

### Requisito 2 — Validação da faixa

**História:** Como time, queremos que a faixa só seja aceita quando fizer
sentido, para o dado nunca ficar inconsistente.

#### Critérios de aceite
1. QUANDO o "até" (`volumeAlvoMax`) é informado sem o alvo (`volumeAlvo`),
   ENTÃO a resposta é 400 (o máximo depende do mínimo).
2. QUANDO o "até" é menor que o alvo (ex.: alvo 12, até 8), ENTÃO front e API
   recusam com erro de validação e nada é gravado.
3. O banco também protege: `CHECK (volume_alvo_max IS NULL OR volume_alvo_max >=
   volume_alvo)`.

### Requisito 3 — Pré-preenchimento sem histórico

**História:** Como atleta, quero que o registro de um exercício com faixa e sem
histórico sugira o começo da faixa.

#### Critérios de aceite
1. QUANDO o atleta abre o registro de um exercício com faixa e sem histórico,
   ENTÃO a série vem sugerida com o **mínimo** da faixa (`volume_alvo`).
2. O comportamento com histórico não muda (continua usando a última execução).

### Requisito 4 — Exibição da faixa

**História:** Como atleta, quero ver a faixa de forma clara onde o plano aparece.

#### Critérios de aceite
1. A faixa aparece como "min a max <unidade>" (ex.: "8 a 12 reps", "30 a 45 s")
   e, sem faixa, "<alvo> <unidade>" (ex.: "10 reps").
2. Vale na ficha (tela 13 / resumo do exercício) e no cabeçalho da tela do
   exercício quando ela existir (TV-4: "Alvo 4 × 8 a 12 reps").

### Requisito 5 — Sem efeito no gráfico

#### Critérios de aceite
1. A faixa NÃO aparece no gráfico de progresso nem altera nenhum cálculo
   (PBI-20 inalterado).

### Requisito 6 — Autorização e compatibilidade

#### Critérios de aceite
1. A faixa entra no endpoint de alvos da ficha, que já aplica a regra do
   `IControleAcesso`; recurso de outro usuário → 404.
2. DADOS os registros existentes antes da migration, ENTÃO `volume_alvo_max`
   fica nulo e a exibição continua "<alvo> <unidade>", sem quebrar.

---

## Fora de escopo

- Faixa de **carga** (intensidade). Se o PO pedir, vira outra PBI no mesmo molde.
