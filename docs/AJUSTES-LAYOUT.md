# Ajustes de layout (PBI-57 a PBI-63)

Sete pedidos do PO (rodadas 1 e 2), 15/10. Layouts das telas 19, 21, 22, 23, 24 e 25 no PDF `Ajustes-de-layout.pdf`.

## O que o PO pediu e onde cada pedido cai

| Pedido | Vira | Telas |
|---|---|---|
| 1. Ficha sem as outras fichas e sem "Nova ficha" | PBI-57 | 22 |
| 2. Seletor igual à imagem, vários exercícios de uma vez | PBI-49 (já escrita, agora aprovada) | 21 |
| 3. Renomear e excluir em ícones no topo | PBI-58 | 19 e 22 |
| 4. Início só com a semana e caixas | PBI-59 (layout) e PBI-60 (novidades, em refinamento) | 23 |
| 5. Iniciar treino só pelo plano, nunca "criar e iniciar" na mesma tela | PBI-61 (e PBI-57 revisada: ficha só de edição) | 19 e 22 |
| 6. Botões de mover e excluir exercício e "Registrar treino já feito" | PBI-62 (mover e excluir) e PBI-61 (registrar já feito vai para o sheet do plano) | 22 e 19 |
| 7. Finalizar treino confuso; a seta não pode salvar nem descartar | PBI-63 | 24 e 25 |

## Ajustes em PBIs que já existem

- **PBI-49:** sai a condição "sujeita à aprovação do PO". A tela deve ficar exatamente como o protótipo 21. Continua só depois do E2E fechar, ou junto da atualização do passo do Robot que escolhe o exercício.
- **PBI-46:** o cabeçalho do detalhe do plano ganha lápis e lixeira, e o rodapé perde "Renomear" e "Excluir plano" (PBI-58). O quadrado da ficha segue a regra já escrita (nome de até 3 caracteres, senão a posição).
- **PBI-47:** encolhe. Sai o "próximo da sequência". Ficam: o plano em uso alimenta a folha do dia (PBI-59) e, sem plano em uso, a Início mostra o Primeiro acesso.
- **PBI-52:** o item do menu "⋯" da ficha é substituído pelos ícones da PBI-58. Os botões "Iniciar treino agora" e "Registrar treino já feito" saem da ficha e vão para o plano (PBI-61). Fica a regra de uma única ação de criar.
- **PBI-53:** o estilo de perigo dos diálogos vale também para "Descartar treino" da PBI-63. "Sair do treino?" continua só no treino livre.
- **PBI-50:** já entregue. A parte do cartão de ficha na Início deixa de existir com a PBI-59; a parte da Fichas continua valendo.

## Ordem de entrega

- PBI-58, PBI-57 e PBI-61, nessa ordem, depois da PBI-46. PBI-62 junto da PBI-57. PBI-63 é independente e pode entrar já.
- PBI-59 pode entrar já: usa o plano ativo de hoje e não passa pelo caminho do Robot.
- PBI-60 espera as respostas abaixo e depende da PBI-59. PBI-49 entra com a atualização do Robot.

## Impacto no E2E

- Sem impacto das PBIs 57, 58, 60, 61, 62 e 63 (o Robot entra por "Registrar sem ficha" e roda com `TREINO_AO_VIVO=false`).
- Sem impacto da PBI-59 enquanto o Primeiro acesso ficar igual (o Robot espera "Registrar sem ficha" depois do cadastro).
- A PBI-49 muda o passo "clicar no exercício".

## Perguntas para o PO

- PBI-59: o atalho "Iniciar treino" na Início entra? Sem ele, treinar custa 4 toques em vez de 1.
- PBI-59: tocar no dia de hoje abre a folha do dia e registra treino já feito, como hoje. Está certo, ou deveria iniciar o treino ao vivo?
- PBI-58: "excluir treino" era só o plano, ou plano e ficha?
- PBI-63: a seta do treino só volta à Início (o treino segue em andamento) e o Resumo é o único passo de salvar. Alguém quer um botão "Minimizar" além da seta? Recomendo não criar.
- PBI-61: no plano do professor o atleta também pode iniciar treino pelo play. Confirma?
- ~~PBI-60: quem escreve as novidades e com que frequência? Recomendo a opção A.~~ Respondida: opção A, com dicas de treino que trocam a cada acesso (ver PBI-60).
- ~~PBI-49: espera o E2E?~~ Respondida: pode entrar sem esperar o E2E; o passo do Robot que escolhe o exercício é ajustado depois.

## Definição de pronto (vale para todas)

- Critérios de aceite passando e testes de widget nos temas claro e escuro.
- Contraste mínimo 4,5:1 para texto, alvo de toque de 44 px e largura máxima de 600 px no web.
- Semântica (ADR-07) em todo elemento interativo.
- MAS atualizado quando a tela muda.

---

## PBI-57 · Ficha enxuta: só edição da ficha aberta

_Front · R1 (junto do detalhe do plano) · Tela 22_

**História:** Como atleta, quero que a tela da ficha mostre apenas a ficha que abri, sem as outras fichas e sem um botão de criar no topo, para focar em montar a ficha. Treinar acontece no plano (PBI-61).

### Contexto

Hoje a mesma tela (`fichas_screen.dart`) serve de seletor de fichas e de edição. Depois de criar uma ficha, ela aparece com os chips de todas as fichas do plano acima do título e com "+ Nova ficha" no cabeçalho. Com o detalhe do plano (PBI-46), que já lista as fichas com resumo e tem o "Nova ficha", esses dois itens ficam repetidos.

**Custo assumido:** trocar de ficha passa a custar um toque a mais (voltar ao plano).

### Escopo

- **Cabeçalho (tela 22):** seta de voltar para o detalhe do plano de origem. Linha pequena com o nome do plano, o nome da ficha como título e o resumo "N exercícios · último em dd/mm" (ou "nunca feito"). Some o rótulo "NOME DA FICHA". Renomear e excluir a ficha como ícones (PBI-58).
- **O que sai:** os chips das outras fichas; o "+ Nova ficha" do cabeçalho (criar ficha só no detalhe do plano).
- **Tela só de edição:** saem "Iniciar treino agora", "Registrar treino já feito" e "Adicione exercícios para iniciar." (PBI-61). Ficha vazia mostra só "Ficha sem exercícios" e "Adicionar exercício à ficha". Criar ficha não abre mais a ficha (PBI-61).
- **Ficha que não existe mais:** volta ao detalhe do plano com o aviso "Essa ficha não existe mais". Substitui a regra "cai na primeira ficha" da PBI-50.

### Critérios de aceite

1. **Só a ficha aberta:** abrir o Treino B pelo plano mostra só o Treino B, sem chips e sem "Nova ficha" no topo.
2. **Sem botões de treino:** nenhuma ficha tem "Iniciar treino agora" nem "Registrar treino já feito".
3. **Ficha vazia aberta pelo plano:** mostra "Ficha sem exercícios" e "Adicionar exercício à ficha".
4. **Voltar:** a seta leva ao detalhe do plano de onde abri a ficha.
5. **Ficha inexistente:** volta ao plano com o aviso "Essa ficha não existe mais", sem erro.
6. **Acessibilidade:** título da ficha como cabeçalho de semântica, seta com rótulo "Voltar para {plano}", alvos de 44 px.

### Testes

- **Widget:** ajustar `fichas_screen_test.dart` e cobrir ficha vazia, voltar e ficha inexistente.
- **Robot:** sem impacto.

### Fora do escopo

- Trocar de ficha por deslize. Reordenar fichas. Duplicar ficha.

---

## PBI-58 · Renomear e excluir como ícones no topo

_Front · R1 (junto do detalhe do plano) · Telas 19 e 22_

**História:** Como atleta, quero um lápis e uma lixeira no topo do plano e da ficha, para renomear e excluir sem procurar texto solto no fim da tela.

### Contexto

Hoje o detalhe do plano tem "Renomear" e "Excluir plano" como textos no rodapé, e a ficha esconde as duas ações no menu "⋯". Texto solto no rodapé parece link e a lixeira perto do "Duplicar plano" convida ao toque errado.

**Interpretação a confirmar com o PO:** "excluir treino" entendido como excluir plano e excluir ficha, com o mesmo padrão nas duas telas. Se era só o plano, a ficha mantém o "⋯".

### Escopo

- **Cabeçalho do plano (tela 19) e da ficha (tela 22):** dois botões de 44 × 44 px no canto direito, com o fundo de campo do cabeçalho: lápis (`LucideIcons.pencil`) e lixeira (`LucideIcons.trash2`).
- A lixeira usa um vermelho claro fixo (`#FF8A80`), porque o vermelho de perigo do tema claro não tem contraste sobre o cabeçalho escuro.
- Rótulos: "Renomear plano", "Excluir plano", "Renomear ficha", "Excluir ficha".
- **O que sai:** "Renomear" e "Excluir plano" do rodapé do plano (o "Duplicar plano" fica). O menu "⋯" da ficha, se só tiver renomear e excluir.
- **Comportamento:** o lápis abre o diálogo de nome que já existe; a lixeira, a confirmação no estilo de perigo da PBI-53. Plano do professor não mostra lápis nem lixeira. A regra de exclusão não muda.

### Critérios de aceite

1. **Ícones no topo:** o detalhe do meu plano tem lápis e lixeira no cabeçalho e nenhum "Renomear" ou "Excluir plano" no rodapé.
2. **Renomear:** tocar no lápis e informar "Força" muda o título e a lista de planos.
3. **Excluir plano:** a lixeira abre a confirmação do plano, e confirmar leva à lista.
4. **Excluir ficha:** a confirmação diz se a ficha será apagada (sem sessões) ou só sairá do plano (com sessões), e confirmar volta ao plano.
5. **Plano do professor:** sem lápis e sem lixeira.
6. **Alvo e rótulo:** botões de 44 px, achados pelo Robot por `role=button[name="Excluir plano"]` e equivalentes.

### Testes

- **Widget:** ícones no plano e na ficha, ausentes no plano do professor, e os dois diálogos.
- **Robot:** sem impacto.

### Fora do escopo

- Desfazer depois de excluir. Menu de mais ações no cabeçalho. Deslizar para excluir.

---

## PBI-59 · Início nova: semana e caixas

_Front · Qualquer sprint · Tela 23_

**História:** Como atleta, quero que a Início mostre a minha semana e o meu último treino, sem lista de fichas nem sugestão, para ver de relance como estou indo. Treinar fica nas telas de plano.

### Contexto

- A faixa semanal é um botão: tocar num dia chama `_registrar` com a ficha sugerida. Sem sugestão, o toque abre a folha do dia.
- O treino livre perde a entrada (`Rotas.treinoLivre` só abre pelo Primeiro acesso e pelo "Continuar treino"). A folha do dia devolve a entrada com "Sem ficha".
- Iniciar treino passa de 1 toque para 4 (decisão aberta abaixo).
- `InicioLogica.proximaFicha` e `ultimaVezPorFicha` ficam sem uso na Início. A PBI-47 encolhe.

### Escopo

- **Tela 23:** cabeçalho igual ao de hoje. "Continuar treino" no topo quando há treino em andamento (nunca some). Cartão "Esta semana": seg a dom e "N dias treinados", com quatro estados que não dependem só de cor (treinou: círculo cheio com check; passado sem treino: círculo vazio; hoje: anel azul e letra azul; futuro: tracejado e inerte). Cartão "Último treino": ficha (ou "Treino livre"), data e quantidade de exercícios, abre o detalhe da sessão; sem sessões, não aparece. Área "Novidades" (PBI-60), oculta até lá.
- **Folha do dia:** tocar num dia (menos os futuros) abre uma folha com o título "qua, 14/10". Seção "Registrado" quando há sessões no dia (cada uma abre o detalhe). Seção "Registrar treino neste dia" (ou "Registrar outro treino neste dia"): fichas do plano em uso, com o nome do plano, e "Sem ficha". Escolher abre o registro retroativo com a data do dia.
- **O que sai:** "Sugestão de hoje", "Suas fichas" e o modo `_SemHistorico`. No lugar deste, aviso com "Tentar de novo" dentro do cartão da semana.
- **O que não muda:** Primeiro acesso para quem não tem ficha nem sessão. Rótulos de semântica dos dias ("Dia 14/10, treino registrado").

> **Decisão aberta do PO: atalho para treinar.** Botão "Iniciar treino" abaixo da semana que abre a folha de fichas do plano em uso e "Sem ficha", iniciando o treino ao vivo. Esta PBI entrega sem o atalho; se aprovado, vira uma PBI pequena depois.

### Critérios de aceite

1. Sem "Sugestão de hoje" nem "Suas fichas"; com semana e último treino.
2. Faixa semanal: treinos na segunda e na quarta, aberto numa quinta → seg e qua com check, ter vazia, qui com anel, sex a dom tracejados, "2 dias treinados".
3. Dia sem treino: folha "ter, 13/10" com as fichas do plano em uso e "Sem ficha"; escolher o Treino B abre o registro com a data de terça.
4. Dia com treino: "Registrado" com o treino (abre o detalhe) e "Registrar outro treino neste dia".
5. Dia futuro não responde ao toque.
6. "Sem ficha" abre o treino livre com a data do dia.
7. "Continuar treino" no topo com treino em andamento.
8. Primeiro acesso sem mudança.
9. Último treino abre o detalhe; sem sessões, não existe.
10. Erro de histórico: aviso com "Tentar de novo", sem semana vazia.
11. Acessibilidade: estado de cada dia em texto, alvos de 44 px, folha anuncia o dia como título.

### Testes

- **Widget:** reescrever `inicio_screen_test.dart`. Manter `primeiro_acesso_screen_test.dart`.
- **Unitário:** `diasDaSemana` continua; decidir se `proximaFicha` e `ultimaVezPorFicha` saem junto.
- **Robot:** sem impacto, desde que o Primeiro acesso continue igual.

---

## PBI-60 · Caixa de novidades na Início

_Front · Depois da PBI-59 · refinada (opção A, dicas de treino)_

**História:** Como atleta, quero ver na Início uma dica de treino que muda a cada acesso, para aprender algo simples sem sair do app.

| Opção | Como funciona | Limite |
|---|---|---|
| A · Conteúdo no app | Lista de avisos e dicas num arquivo versionado; publicar o front atualiza para todos. | Mudar texto exige deploy do front. |
| B · Tabela e API | Tabela `aviso` e `GET /avisos`, cadastro por SQL no começo. | Migration, endpoint e testes só para mostrar texto. |
| C · Painel de edição | PO ou professor escrevem pelo app. | Fica para o épico do educador. |

**Decisão do PO (resposta à pergunta da PBI-60):** opção A, com **dicas de treino**
em vez de novidades do app. Uma série de mensagens curtas ("Se hidrate durante o
treino", "Antes de iniciar séries com cargas altas, aqueça."), mostradas num
cartão e trocadas a cada vez que o atleta acessa o app. Sem links, datas de
validade nem etiquetas: a versão com novidades do app (critérios antigos) fica
para depois, se for pedida.

### Escopo (revisado)

- Lista de dicas no front (`app/lib/features/inicio/dicas.dart`), versionada.
- Um cartão "DICA DE TREINO" na Início, abaixo do último treino.
- A cada acesso ao app, a próxima dica da lista (volta ao começo no fim). A
  posição fica salva no aparelho (`shared_preferences`); trocar de aba ou voltar
  à Início no mesmo acesso não troca a dica.
- Dicas gerais de treino, sem orientação médica.

### Critérios de aceite (revisados)

1. A Início mostra um cartão com uma dica. 2. Abrir o app de novo mostra a dica
seguinte; depois da última, volta à primeira. 3. No mesmo acesso, a dica não
muda. 4. Sem dicas na lista, o cartão não aparece. 5. Falha ao ler ou salvar a
posição não quebra a Início (mostra a primeira). 6. O cartão é lido como
"Dica de treino: {texto}" e funciona nos dois temas.

---

## PBI-61 · Treinar a partir do plano

_Front · R1 (junto do detalhe do plano) · Tela 19_

**História:** Como atleta, quero iniciar o treino pelo detalhe do plano, e não dentro da tela de montar a ficha, para que criar e treinar sejam momentos separados.

**Decisão:** a ficha só se edita; o treino só se inicia pelo plano.

### Escopo

- **Linha da ficha:** o corpo abre a ficha para editar; um botão redondo de 44 × 44 px com "play" abre o sheet de treinar. Ficha sem exercícios: play desabilitado, rótulo "{ficha}: adicione exercícios para treinar". Rótulo do play: "Treinar {ficha}".
- **Sheet de treinar:** cabeçalho "Ficha N · {plano}" e o nome da ficha. "Iniciar treino agora" (primário, treino ao vivo), "Registrar treino já feito" (secundário, prancheta), Cancelar.
- **Depois de criar uma ficha:** volta ao detalhe do plano com a ficha na lista e o snackbar "Ficha “{nome}” criada" com a ação "Adicionar exercícios".
- **Regras que continuam:** com treino ao vivo aberto, o play segue `iniciarTreinoAoVivoDaFicha` (sem segundo treino). No plano do professor, play e sheet funcionam.

### Critérios de aceite

1. Play + "Iniciar treino agora" abre o treino ao vivo com a ficha. 2. Corpo abre a edição sem iniciar treino. 3. Ficha vazia: play desabilitado com o rótulo. 4. Depois de criar: volta ao plano com o aviso; a ficha não abre sozinha. 5. "Registrar treino já feito" abre o registro manual. 6. Com treino ao vivo aberto, não nasce um segundo. 7. Alvos de 44 px, rótulos próprios, foco volta ao play ao fechar o sheet.

---

## PBI-62 · Cartão de exercício: mover e excluir

_Front · R1 (junto da PBI-57) · Tela 22_

**História:** Como atleta, quero um jeito claro de reordenar e de remover um exercício da ficha, sem dois ícones sobrepostos, para não apagar sem querer.

**Contexto:** causa provável do "=" extra: `ReorderableListView.builder` sem `buildDefaultDragHandles: false`, então no web/desktop o Flutter adiciona a própria alça. Confirmar no navegador antes de mexer.

### Escopo

- Alça de mover à esquerda (36 × 44 px, grip de seis pontos, `ReorderableDragStartListener`).
- Excluir à direita: botão de 44 × 44 px, fundo vermelho suave (`dangersoft`) e lixeira vermelha, sem texto.
- `buildDefaultDragHandles: false`; ações de semântica "Mover para cima" e "Mover para baixo". Remover continua como hoje.

### Critérios de aceite

1. Uma alça e um excluir por cartão, sem ícones sobrepostos. 2. Arrastar muda a ordem e persiste. 3. Excluir mantém a regra atual. 4. Alça e lixeira com 44 px de altura, sem sobrepor em 360 de largura. 5. Rótulos "Arrastar para reordenar {exercício}" e "Remover {exercício} da ficha", mais as ações de mover.

---

## PBI-63 · Fluxo de finalizar treino: seta só sai, botões encerram

_Front · R1 (junto do treino ao vivo) · Telas 24 e 25_

**História:** Como atleta, quero que a seta de voltar apenas me tire da tela do treino, e que salvar ou descartar aconteça só pelos botões, em um único passo de salvar, para não perder nem apagar treino sem querer.

**Regra nova:** a seta **nunca salva nem descarta**. Ela só leva à Início, e o treino continua em andamento. Encerrar é só pelos botões "Finalizar treino" e "Descartar treino".

**Histórico das rodadas:**
- Rodada 1 (PR #78): sem seta; aviso de treino vazio e de séries pendentes na tela do treino.
- Rodada 2 (PR #82): o Resumo virou o único passo de salvar e o aviso de treino vazio foi para o "Salvar treino" dele (antes eram dois salvamentos em sequência).
- Rodada 3 (branch `fix/pbi-63-seta-volta`): tirar a seta foi decisão errada, porque sem ela o atleta não vai à Início durante o treino. A seta volta, sem salvar nem descartar.

### Escopo

**Tela do treino (tela 24)**
- Cabeçalho escuro com **seta de voltar**, "Treino em andamento", nome da ficha, cronômetro, "Começou às hh:mm" e séries feitas.
- **A seta e o voltar do sistema fazem a mesma coisa:** vão para a Início, sem diálogo, sem salvar e sem descartar. O cronômetro e as séries marcadas continuam salvos no aparelho.
- Na Início, o cartão "Continuar treino" (PBI-59) leva de volta ao treino.
- Barra fixa embaixo, empilhada: "Finalizar treino" (primário, check) e "Descartar treino" (contorno vermelho, lixeira), 48 px cada.
- Texto de apoio: "Pode voltar para a Início sem perder nada: o treino continua em andamento e fica salvo no aparelho. Para encerrar, use os botões abaixo."

**Finalizar (um passo só)**
- "Finalizar treino" **nunca salva e nunca abre diálogo**: leva direto ao Resumo (tela 25). O "Sair do treino?" não existe nesta tela, e os avisos de séries pendentes saíram, porque o Resumo já mostra o que ficou sem marcar.
- No Resumo, "Salvar treino" salva e abre "Treino registrado". "Voltar ao treino" e a seta voltam à tela do treino.
- **Treino vazio** (zero séries): "Salvar treino" abre "Salvar treino vazio?" com "Você irá salvar sem inserir nenhum dado, tem certeza?". Botões: "Salvar mesmo assim", "Descartar treino" (contorno vermelho) e "Voltar ao resumo".

**Descartar**
- Na tela do treino, "Descartar treino" abre "Descartar treino?" com "O que você fez neste treino será perdido."; botão vermelho cheio e "Voltar ao treino". Confirmar volta ao plano.
- No Resumo de um treino vazio, o descartar fica no diálogo de salvar vazio, com a mesma consequência.
- `dialogoSairDoTreino` continua no treino livre e no registro já feito.

### Critérios de aceite

1. **Seta só sai:** tocar na seta vai à Início sem diálogo; o treino não é salvo nem descartado e o cronômetro segue. 2. **Voltar do sistema:** resultado idêntico ao da seta. 3. **Retomar:** o cartão "Continuar treino" da Início volta ao treino com as séries e o tempo como estavam. 4. "Finalizar treino" abre o Resumo direto, sem diálogo e sem salvar. 5. Uma única ação de salvar entre "Finalizar treino" e "Treino registrado". 6. Zero séries: "Salvar treino" mostra "Salvar treino vazio?"; "Salvar mesmo assim" salva sem dados e abre "Treino registrado". 7. Descartar (tela do treino ou diálogo de vazio) confirma e volta ao plano sem sessão. 8. Voltar do Resumo mantém as séries como estavam. 9. Seta com rótulo "Voltar para a Início. O treino continua em andamento", barra com alvos de 48 px, diálogos com foco preso, cronômetro como `timer` com rótulo falado.

### Fora do escopo

- Botão "Minimizar" separado da seta.
- Pausar o cronômetro.
- Mudar o diálogo de saída do treino livre.
