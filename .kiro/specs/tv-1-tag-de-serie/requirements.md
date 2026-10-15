# TV-1 · Tag de série — Requisitos

> Épico: **Treino ao vivo, série por série** (pós-MVP). Esta é a PBI **TV-1**,
> primeira do épico (Release 1), aprovada pelo PO em 15/10/2026.
> Referências: MER seção 7, protótipos 13, 15 e 16.
> Tipo: banco + API + front. Depende de: nada novo.
>
> **Mapa do épico** (numeração provisória TV-1..TV-6):
> - **R1 (mexe no banco):** TV-1 Tag de série · TV-2 Faixa de repetições na prescrição.
> - **R2 (treino ao vivo, front):** TV-3 Iniciar treino / em andamento · TV-4 Tela
>   do exercício série por série (+ `GET /exercicios/{id}/historico`) · TV-5
>   Descanso automático · TV-6 Resumo ao finalizar.
>
> **Definição de pronto do épico (vale para esta PBI):** critérios de aceite +
> cenários Robot no CI; unit + integração das regras novas; tema claro/escuro,
> contraste ≥ 4,5:1, alvo de toque 44px, largura máx. 600px no web; semântica em
> todo elemento interativo (ADR-07); observação do dia nunca em log; MER/MAS
> atualizados quando mexer em modelo/regra.

## Introdução

Como atleta, quero marcar cada série com o **tipo de série** que fiz
(aquecimento, top set, até a falha e as outras), para o meu histórico mostrar
**como** o treino foi feito, e não só a carga e as repetições.

A tag é **só identificação**: não muda o gráfico de progresso (que continua
usando a maior carga do exercício — PBI-20), nem nenhum cálculo de volume. Ela
pode ser definida na montagem da ficha (pelo atleta hoje, pelo educador no
futuro) e trocada pelo atleta na hora de registrar.

A funcionalidade entra em três telas que já existem — **Editar exercício da
ficha** (tela 10), **Registrar treino** (tela 3) e **Detalhe da sessão**
(tela 11) — reaproveitando o mesmo componente de seletor. A futura tela de
treino ao vivo (protótipo 15) usará o mesmo componente quando for feita.

### Lista fixa de marcadores

A tag é um enum de 10 valores, guardado como texto com `CHECK` (convenção do
MER). Tag nova só entra por migration, **nunca** como texto livre.

| Código        | Rótulo na tela | Descrição no seletor                                   | Cor do chip      |
|---------------|----------------|--------------------------------------------------------|------------------|
| `VALIDA`      | Válida         | Série de trabalho, a padrão. Sem chip no modo leitura. | neutra           |
| `AQUECIMENTO` | Aquecimento    | Carga leve, prepara articulação e músculo              | neutra           |
| `PREPARATORIA`| Preparatória   | Aproximação de carga antes das válidas                 | neutra           |
| `TOP_SET`     | Top set        | A série mais pesada do dia                             | primary suave    |
| `BACK_OFF`    | Back-off       | Depois do top set, com carga reduzida                  | primary suave    |
| `FALHA`       | Até a falha    | Até não conseguir outra repetição                      | primary suave    |
| `DROP_SET`    | Drop set       | Reduz a carga e segue sem descanso                     | primary suave    |
| `REST_PAUSE`  | Rest-pause     | Pausa curta e mais repetições                          | primary suave    |
| `NEGATIVA`    | Negativa       | Ênfase na fase excêntrica                              | primary suave    |
| `PARCIAIS`    | Parciais       | Amplitude reduzida no fim da série                     | primary suave    |

`VALIDA` é o padrão: rodada sem marcador vale `VALIDA`; registros anteriores à
migration valem `VALIDA`.

---

## Requisitos

### Requisito 1 — Tags na ficha (prescrição por série)

**História:** Como atleta montando a ficha, quero marcar o tipo de cada série
prescrita de um exercício, para o plano já dizer, por exemplo, que a série 1 é
aquecimento e a série 4 é até a falha.

#### Critérios de aceite
1. QUANDO o atleta, num exercício da ficha com N séries, define a tag de uma ou
   mais rodadas e salva, ENTÃO ao reabrir a ficha as tags definidas aparecem nas
   rodadas certas e as demais rodadas aparecem como `VALIDA`.
2. ENQUANTO uma rodada estiver como `VALIDA`, o sistema NÃO grava marcador para
   aquela rodada (só persiste o que for diferente de `VALIDA`).
3. QUANDO o atleta reduz a quantidade de séries do exercício (ex.: de 4 para 3),
   ENTÃO os marcadores das rodadas que deixaram de existir são apagados.

### Requisito 2 — Herança da tag no registro

**História:** Como atleta registrando um treino, quero que cada série já venha
com a tag certa, para não ter que marcar tudo de novo.

#### Critérios de aceite
1. QUANDO o atleta abre "Registrar treino" a partir de uma ficha com tags,
   ENTÃO cada série já vem pré-preenchida com a tag da ficha para aquela rodada.
2. QUANDO o atleta abre um treino livre (sem ficha) de um exercício que já
   registrou antes, ENTÃO as séries vêm com as tags da última sessão daquele
   exercício.
3. QUANDO não há tag na ficha nem na última sessão, ENTÃO a série vem como
   `VALIDA`.
4. A ordem de prioridade do pré-preenchimento é: (1) tag da ficha para a rodada;
   (2) tag da última sessão daquele exercício; (3) `VALIDA`.

### Requisito 3 — Trocar a tag na hora do registro

**História:** Como atleta, quero trocar a tag de uma série no momento do
registro, porque nem sempre o treino sai igual ao plano.

#### Critérios de aceite
1. QUANDO o atleta troca a tag de uma série no registro e salva, ENTÃO o detalhe
   da sessão passa a mostrar a tag nova.
2. QUANDO o atleta troca a tag no registro, ENTÃO a tag prescrita na ficha
   permanece inalterada (a troca é só da sessão).

### Requisito 4 — Exibição da tag

**História:** Como atleta, quero ver as tags das séries de forma clara, para ler
o histórico de relance.

#### Critérios de aceite
1. QUANDO uma série é `VALIDA`, ENTÃO no modo leitura (detalhe da sessão) ela NÃO
   mostra chip.
2. QUANDO uma série é `VALIDA`, ENTÃO no modo edição (ficha/registro) ela mostra
   "Válida" em tom secundário, sinalizando que dá para trocar.
3. QUANDO uma série tem tag diferente de `VALIDA`, ENTÃO o chip aparece com o
   rótulo e a cor da lista fixa (neutra para Aquecimento/Preparatória; primary
   suave para as demais).
4. O chip entra no mesmo lugar onde hoje fica o número da série, nas três telas.
5. O seletor abre uma lista de baixo para cima com as 10 opções (rótulo +
   descrição), com a opção atual marcada (protótipo 15).

### Requisito 5 — Gráfico de progresso intocado

**História:** Como atleta, quero que a tag não mude meu gráfico, porque ela é só
identificação.

#### Critérios de aceite
1. QUANDO existe uma sessão com uma série `AQUECIMENTO` de carga maior que as
   demais, ENTÃO o ponto do gráfico mostra a maior carga do dia, independentemente
   da tag.
2. O cálculo do progresso (PBI-20) NÃO muda: continua filtrando por
   `Tipo == ESFORCO` e pegando a maior carga da sessão. A tag não entra em
   nenhum cálculo.

### Requisito 6 — Validação na API

**História:** Como time, queremos que a API rejeite tags inválidas, para o dado
nunca sair da lista fixa.

#### Critérios de aceite
1. QUANDO um código de marcador fora da lista fixa é enviado direto à API,
   ENTÃO a resposta é 400 (Problem Details) com mensagem de validação.
2. QUANDO um marcador de ficha vem com rodada menor que 1 ou maior que o número
   de rodadas do exercício, ENTÃO a resposta é 400 com mensagem de validação.
3. O enum fica em um único lugar no Domain; o `CHECK` da migration é derivado
   dele.

### Requisito 7 — Compatibilidade com dados antigos

**História:** Como atleta com histórico, quero que meus registros antigos
continuem funcionando após a mudança.

#### Critérios de aceite
1. DADOS os registros existentes antes da migration, ENTÃO todas as séries
   aparecem como `VALIDA` e nada quebra no detalhe nem no gráfico.
2. A migration aplica do zero sem erro (convenção do projeto): coluna
   `serie_executada.marcador` com default `'VALIDA'`, tabela `rodada_marcador`
   nova, ambos com o `CHECK` dos 10 códigos.

### Requisito 8 — Autorização (MAS 11.3)

#### Critérios de aceite
1. QUANDO qualquer leitura/escrita de marcador de atleta ocorre, ENTÃO passa
   pela regra única do `IControleAcesso` (próprio atleta OU educador com vínculo
   ativo). A tag entra em endpoints de ficha e sessão que já aplicam essa regra.
2. QUANDO um recurso de outro usuário é acessado, ENTÃO a resposta é **404**,
   nunca 403.

---

## Fora de escopo

- Métodos de ficha / agrupamento de exercícios (bi-set, super-série, pirâmide,
  FST-7): vão em outra PBI.
- Filtro ou análise por tag.
- A tela de treino ao vivo (protótipos 13 a 17): outra PBI, reaproveita este
  componente.
