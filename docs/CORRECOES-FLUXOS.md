# Correções e fluxos de entrada (PBI-67 a PBI-72)

Respostas do PO de 16/10 já dentro. Layouts das telas 19, 23, 25, 27, 28 e 29 no PDF `Correcoes-e-fluxos.pdf`.

## Status

| PBI | Título | Status |
|---|---|---|
| PBI-70 | Telas atualizam pela origem da mudança | ✅ na `main` (PR #88) |
| PBI-67 | Treino em andamento visível ao voltar | ✅ na `main` (PR #86). Entrou antes da 70; o "ponto único" de aviso do rascunho veio com a 70 |
| PBI-68 | Início e Planos sem plano: cada aba com a sua tela | em revisão (branch `feat/pbi-68-69-sem-plano-e-criar-plano`) |
| PBI-69 | Criar plano e primeira ficha em um caminho só | em revisão (mesma branch da 68) |
| PBI-71 | Registrar treino sempre à mão na Início | a fazer (depois da 68) |
| PBI-72 | Manter na ficha o exercício adicionado no treino? | a fazer (front + API) |

## O que o PO decidiu e onde entrou

| Decisão do PO | Vira | Telas |
|---|---|---|
| Planos sem plano: tela própria "Monte seu primeiro plano e comece a treinar"; boas-vindas só na Início | PBI-68 | 27 |
| Início sem plano mas com histórico: Início normal, mantendo o boas-vindas como card | PBI-68 | 23 |
| Primeiro acesso só para conta nova, some depois da primeira ficha ou sessão | PBI-68 | 29 |
| "Registrar treino" com lugar fixo na Início | PBI-71 | 23 e 29 |
| Ao finalizar com exercício adicionado: manter na ficha ou descartar | PBI-72 | 25 |
| Voltar do "criar ficha" ao plano; plano e Início sem atualizar | PBI-69 e PBI-70 | 27, 28 e 19 |

## Ordem de entrega

1. **PBI-70** primeiro: invalidação pela origem. Sem ela, 67, 68 e 72 voltam a mostrar estado velho.
2. **PBI-67**, **PBI-68** e **PBI-69**: card "Continuar treino" e as telas e caminho de criar plano. Mexem nas mesmas telas.
3. **PBI-71** (precisa da 68 para o nome do botão) e **PBI-72** (depende da 70 e da API).

## Decisões tomadas no lugar do PO (revisar)

- Criar plano pede só o nome e o plano nasce sem fichas, em vez de já criar um "Treino A".
- Depois de criar a ficha, o destino é o detalhe do plano, e não a lista de planos.
- Conta com plano sem fichas e sem sessões ainda vê o "Bem-vindo", com o botão "Montar a primeira ficha".
- "Registrar treino" abre o sheet de fichas quando há plano com fichas; sem plano, vai direto ao treino livre.
- "Manter na ficha" entra no fim da ficha com as séries marcadas e o alvo da última série, uma decisão para todos os exercícios adicionados, sempre perguntando.

## Ajuste de documentos junto

Feito com a PBI-68: a PBI-09 (BACKLOG) e as PBIs 44, 45 e 47 (EPICO-PLANOS) passam a dizer que o primeiro acesso é só da Início e só para conta nova (sem plano com ficha e sem sessão).

## Impacto no E2E

- **PBI-68 e PBI-71:** o Robot clica em "Registrar sem ficha" depois do cadastro. O texto passa a ser "Registrar treino" e, sem plano, abre direto o treino livre. Ajustar o passo junto.
- **PBI-69:** conferir se algum passo usa "Montar fichas" ou "Criar ficha".
- **PBI-70, 67 e 72:** sem impacto (o E2E usa treino livre e roda com `TREINO_AO_VIVO=false`).
- **Campos de texto no Flutter web:** usar `Click With Options` com `force=True` e depois `Keyboard Input insertText`. O campo semântico é um `<input disabled>`, então `Focus` não funciona.

## Perguntas abertas para o PO

- PBI-69: criar o plano nascer sem fichas e a ficha ir para o detalhe do plano, como propus?
- PBI-72: com vários exercícios adicionados, uma decisão para todos serve?
- PBI-68: a Início de quem apagou os planos mostra "Bem-vindo de volta · Crie seu plano". Era isso que o PO quis dizer com manter o boas-vindas?

## Definição de pronto (todas)

- Critérios de aceite passando e testes de widget nos temas claro e escuro.
- Contraste mínimo 4,5:1, alvo de toque de 44 px, largura máxima de 600 px no web.
- Semântica (ADR-07) em todo elemento interativo.
- Teste que reproduz o bug original antes da correção (PBIs 67, 69 e 70).

---

## PBI-70 · Telas atualizam pela origem da mudança

_Front (técnica) · Primeiro, antes das outras_

**História:** Como atleta, quero que toda tela mostre na hora o que acabei de fazer em outra, para nunca ver informação velha depois de criar ou apagar plano, ficha, treino ou sessão.

### Contexto

**Sintomas vistos no teste do PO:** montei o plano e a Início continuou no "Bem-vindo"; iniciei o treino, voltei e a Início não mostrou "Continuar treino" (PBI-67). Nos dois casos a tela segue com o valor que carregou antes.

**Causa:** a Início observa `planoAtivoProvider`, `sessoesRecentesProvider` e `treinoEmAndamentoProvider`, que só atualizam com `ref.invalidate(...)`, e cada tela chamava por conta própria. A tela que muda os dados esquece de avisar as outras.

### Escopo

**Regra**
- Quem **muda** o dado avisa quem **lê**, num lugar só. Nenhuma tela chama `ref.invalidate` por conta própria.
- Cada operação de escrita invalida o que a leitura derivada depende.

**Mapa de invalidação**
- **Plano:** criar, renomear, excluir, mudar o plano em uso → `planoAtivoProvider`, lista de planos, o que a Início deriva (semana, primeiro acesso).
- **Ficha:** criar, renomear, excluir, adicionar ou remover exercício → plano ativo, detalhe do plano, ficha aberta.
- **Sessão:** salvar, editar, excluir → `sessoesRecentesProvider`, semana, plano ativo (último treino da ficha), progresso.
- **Treino em andamento:** iniciar, retomar, finalizar, descartar → `treinoEmAndamentoProvider`.

### Como foi entregue (branch `fix/pbi-70-invalidacao-pela-origem`)

- **Mapa único:** `lib/core/dados/invalidacao.dart`, com `invalidarDerivados(ref, Mudanca)`. `Mudanca.planos` cobre plano e ficha (lista, plano em uso, plano por id, detalhe, ficha aberta, rascunho do registro). `Mudanca.sessoes` cobre sessões recentes e do período, detalhe da sessão, "ficha tem sessões", histórico e progresso, mais tudo de planos (último treino e "última vez"). `Mudanca.catalogo` atualiza a busca. `Mudanca.treinoEmAndamento` avança a versão do rascunho.
- **Comandos:** as telas gravam por `fichasComandosProvider`, `sessaoComandosProvider` e `catalogoComandosProvider`. Cada comando chama o repositório e, ao terminar (com sucesso ou erro, porque o servidor pode ter mudado), chama o mapa. Os repositórios continuam só HTTP; os fakes dos testes seguem valendo.
- **Rascunho do treino:** o `RascunhoTreinoService` avisa ao gravar ou apagar. O Riverpod não deixa um provider invalidar quem depende dele, então o aviso avança `versaoRascunhoTreinoProvider`, que o `treinoEmAndamentoProvider` observa.
- **"Tentar de novo" e puxar para atualizar:** a tela busca de novo a própria leitura com `ref.refresh(...)`, ou `tentarDeNovo(ref, [...])` quando são várias.
- **Corrigido junto:** escritas que não avisavam ninguém. Alvos e exercícios da ficha só atualizavam a ficha aberta (o plano e o rascunho do registro ficavam velhos). Salvar ou excluir sessão não atualizava a aba Progresso, o histórico do exercício nem o rascunho. "Salvar também como ficha" só atualizava o plano em uso.

### Critérios de aceite

1. **Início depois de criar plano:** Dada uma conta sem plano e sem sessão, quando crio um plano com uma ficha e volto à Início, então ela mostra a tela correta para esse estado (PBI-68), sem puxar para atualizar.
2. **Início depois de excluir plano:** Dado um plano em uso, quando o excluo, então a Início e a lista de planos refletem na hora, sem reiniciar o app.
3. **Renomear:** Quando renomeio plano ou ficha, então o novo nome aparece na Início, na lista e no detalhe.
4. **Sessão:** Quando salvo ou excluo uma sessão, então a semana, o último treino e o progresso mudam na hora.
5. **Sem invalidação nas telas:** Nenhuma tela de plano, ficha ou sessão contém `ref.invalidate`; a busca no código falha o teste se contiver.

### Testes

- **Widget, um único `ProviderScope`** (`test/invalidacao_pela_origem_test.dart`): conta nova cria a primeira ficha e a Início sai do Bem-vindo; excluir o plano em uso atualiza a lista e a Início; renomear o plano muda o detalhe e a lista; excluir a sessão tira o último treino e o dia da semana. Salvar sessão já era coberto por `fluxo_registro_test.dart`. Com o mapa desligado, os cinco falham.
- **Arquitetura** (`test/arquitetura_invalidacao_test.dart`): `invalidate(` só existe no mapa, em todo `lib/`, e nenhum arquivo fora de repositórios e comandos chama escrita do repositório direto.
- **Rascunho:** gravar e apagar o rascunho atualiza o treino em andamento sem invalidar na tela (`treino_em_andamento_test.dart`).
- **Robot:** sem impacto direto.

### Fora do escopo

- Trocar a camada de dados por streams ou banco reativo.
- Cache offline.

---

## PBI-67 · Bug: treino em andamento invisível ao voltar

_Bug (Front) · ✅ entregue no PR #86 · detalhamento em [AJUSTES-LAYOUT.md](AJUSTES-LAYOUT.md#pbi-67--bug-treino-em-andamento-invisível-ao-voltar)_

**História:** Como atleta, quero ver que o treino está em andamento e ter um botão de continuar, na Início e no plano, para voltar a ele depois de sair pela seta.

O escopo desta rodada (card na Início com 0 séries, destaque "Em andamento · mm:ss" e "Continuar" no plano, um treino por vez, rascunho gravado ao iniciar, rótulo falado com os minutos) já está na `main`. O item técnico "invalidar o provider em um único ponto" fechou com a PBI-70.

### Critérios de aceite

1. **Início mostra o card:** Dado um treino iniciado com 0 séries marcadas, quando saio pela seta e chego à Início, então vejo o card "Treino em andamento" com "Continuar treino".
2. **Continuar:** Quando toco em "Continuar treino", então volto ao treino com as séries marcadas e o tempo como estavam.
3. **Plano indica:** Dado o mesmo treino, quando abro o plano da ficha, então a ficha mostra "Em andamento · mm:ss" e o botão "Continuar" no lugar do play.
4. **Só uma ficha:** Dado um treino aberto na ficha 1, quando toco no play da ficha 2, então não nasce um segundo treino (retoma ou pergunta).
5. **Some ao encerrar:** Quando salvo ou descarto o treino, então o card da Início e o destaque da ficha desaparecem sem reiniciar o app.
6. **Reabrir o app:** Dado um treino em andamento e o app fechado, quando abro de novo, então o card e o destaque continuam.
7. **Acessibilidade:** O card e o botão "Continuar" têm rótulo falado com o tempo decorrido ("em andamento há 12 minutos") e alvo de 44 px.

---

## PBI-68 · Início e Planos sem plano: cada aba com a sua tela

_Front · Depois da PBI-70_

**História:** Como atleta, quero que a aba Planos e a Início mostrem telas diferentes quando não tenho plano, cada uma dizendo o que faz sentido ali, e que o "Bem-vindo" apareça só para quem acabou de chegar.

### Contexto

**O que o PO viu:** depois de apagar todos os planos, as abas Início e Planos mostraram a mesma tela ("Bem-vindo · Seu diário de treino"). Confirmado no código: `planos_screen.dart` mostra o `PrimeiroAcessoScreen` quando a lista vem vazia, e a Início mostra o mesmo quando não há plano em uso. O "num teste depois a aba Planos já mostrava o estado vazio" não bate com o código atual; o mais provável é o PO ter visto o detalhe do plano vazio ("MONTAR FICHAS").

**Origem:** a PBI-09 diz que o primeiro acesso aparece "em vez da tela inicial" para quem não tem plano, e a PBI-47 repetiu isso. A regra vale para conta nova, não para quem já treinou e apagou os planos.

### Escopo

**Aba Planos, nenhum plano (tela 27)**
- Estado vazio próprio: ícone de calendário com mais, título "Monte seu primeiro plano e comece a treinar", texto "Um plano reúne suas fichas, como Treino A, B e C...", botão primário "Criar plano".
- O botão abre o diálogo "Novo plano" (campo "Nome do plano" já com "Meu plano", botões "Criar plano" e "Cancelar"). Segue na PBI-69.
- Nenhum texto de "Bem-vindo" nesta aba. A lista com "Novo plano" no cabeçalho só aparece quando há pelo menos um plano.

**Início, conta nova (tela 29)**
- Vale quando **não há nenhuma sessão** e não há ficha (nenhum plano, ou plano sem fichas). Mostra o card "Bem-vindo · Seu diário de treino", as três linhas (Monte seu plano, Registre o treino, Acompanhe a evolução) e dois botões.
- Botão primário: "Criar meu plano" quando não há plano; "Montar a primeira ficha" quando existe um plano sem fichas (abre o detalhe desse plano).
- Botão secundário: "Registrar treino" (PBI-71). O antigo "Registrar sem ficha" passa a ter esse nome.
- Some assim que existir a primeira ficha ou a primeira sessão (regra da PBI-09 mantida).

**Início, sem plano mas com sessões (tela 23, estado "sem plano")**
- Início normal (semana, último treino, novidades) com um card escuro "Bem-vindo de volta · Crie seu plano" e o botão "Criar plano", acima da semana.
- Se também houver treino em andamento, o card "Treino em andamento" vem primeiro e o "Crie seu plano" logo abaixo.
- O histórico e a semana continuam visíveis: apagar os planos não apaga o que o atleta já treinou.

**Texto a corrigir na lista de planos**
- Trocar "Só um plano fica em uso: é ele que alimenta a sequência A, B, C da tela Início" por "Só um plano fica em uso: é ele que alimenta a semana da Início. Os outros continuam à mão para iniciar quando você quiser."

### Critérios de aceite

1. **Planos sem plano:** Dado que não tenho nenhum plano, a aba Planos mostra "Monte seu primeiro plano e comece a treinar" com "Criar plano" e nenhum texto de boas-vindas.
2. **Telas diferentes:** Dado que não tenho plano, a Início e a aba Planos mostram telas diferentes entre si.
3. **Conta nova:** Dada uma conta sem plano e sem sessões, a Início mostra o "Bem-vindo" com "Criar meu plano" e "Registrar treino".
4. **Plano sem fichas:** Dada uma conta com plano sem fichas e sem sessões, o primário vira "Montar a primeira ficha" e abre o detalhe do plano.
5. **Com histórico:** Dada uma conta sem plano mas com sessões, a Início mostra a semana e o último treino e o card "Crie seu plano", e não o "Bem-vindo" de tela cheia.
6. **Some o bem-vindo:** Quando salvo a primeira sessão ou crio a primeira ficha, o "Bem-vindo" de tela cheia não volta.
7. **Texto da lista:** A lista de planos não menciona mais a "sequência A, B, C".

### Testes

- **Widget:** cinco cenários (conta nova; plano sem fichas; só sessões; plano com fichas; sem plano na aba Planos). Atualizar `primeiro_acesso_screen_test.dart` e `inicio_screen_test.dart`.
- **Robot:** **pode impactar.** O passo "Registrar sem ficha" vira "Registrar treino" (e, sem plano, abre direto o treino livre, ver PBI-71).

### Como foi entregue (branch `feat/pbi-68-69-sem-plano-e-criar-plano`)

- **Início:** `PrimeiroAcessoScreen(plano:)` só quando não há sessão e não há ficha. Sem plano e com sessões, a Início normal ganha o card `_CrieSeuPlano` acima da semana (abaixo do "Continuar treino"). Saiu o gate "sem plano em uso" da PBI-47.
- **Planos:** sem planos, `_SemPlanos` (tela 27); a lista com "Novo plano" no cabeçalho só aparece com pelo menos um plano. Texto da lista corrigido.
- **Testes:** os cinco cenários em `inicio_screen_test.dart`, `primeiro_acesso_screen_test.dart` e `planos_screen_test.dart`, com tema claro e escuro.

### Fora do escopo

- Ilustrações novas.
- Tutorial em passos.

---

## PBI-69 · Criar plano e primeira ficha em um caminho só

_Front · Junto da PBI-68_

**História:** Como atleta, quero criar meu plano e minha primeira ficha sem passar por telas vazias repetidas, e depois de criar voltar ao plano para montar o treino.

### Contexto

**Sintomas:** (1) "Montar fichas" na aba Planos abre a tela Fichas, que é outro estado vazio ("Nenhuma ficha ainda · Criar ficha"), e a seta dela devolve ao primeiro estado vazio. (2) Depois de criar a ficha, o app fica na tela de criar em vez de voltar ao plano.

**Causa (conferida no código):** o estado vazio do detalhe do plano tem o botão "MONTAR FICHAS", que faz `context.push(Rotas.fichaDoPlano)` sem `?plano=`: abre a tela Fichas do plano **em uso**, que pode nem ser o plano aberto. O "MONTAR MINHAS FICHAS" do Primeiro acesso usa a mesma rota. Na tela Fichas, "CRIAR FICHA" (`_criarPrimeiraFicha`) cria e fica ali, de propósito ("Fica nesta tela para já adicionar exercícios").

### Escopo

**Caminho novo**
- Aba Planos vazia: "Criar plano" abre o diálogo "Novo plano" (PBI-68).
- Confirmar cria o plano (em uso, se for o primeiro) e abre o **detalhe do plano vazio** (tela 28): "Nenhuma ficha ainda · Crie a primeira ficha, por exemplo o Treino A" e o botão "Nova ficha".
- "Nova ficha" abre o diálogo de nome. Confirmar cria a ficha e **volta ao detalhe do plano**, com a ficha na lista (vazia, play desabilitado) e o aviso "Ficha “Treino A” criada" com a ação "Adicionar exercícios" (PBI-61). A ficha não abre sozinha.

**O que sai**
- O botão "Montar fichas" e o estado vazio da tela Fichas antiga ("Nenhuma ficha ainda · Criar ficha"). Fichas só se criam e se editam a partir do plano (PBI-57).
- Qualquer rota que permita chegar à tela Fichas sem um plano.

**Voltar**
- A seta do detalhe do plano vazio leva à lista de planos, já com o plano criado. Nenhuma seta leva a um estado vazio igual ao de onde o atleta veio.

### Critérios de aceite

1. **Criar plano:** Dado que não tenho plano, quando toco em "Criar plano", então abre o diálogo de nome sem passar por outra tela.
2. **Plano criado:** Quando confirmo o nome, então abro o detalhe do plano vazio com "Nova ficha".
3. **Ficha criada:** Quando confirmo o nome da ficha, então volto ao detalhe do plano com a ficha na lista e o aviso "Adicionar exercícios"; não fico na tela de criar.
4. **Seta:** Quando toco na seta do detalhe do plano vazio, então vejo a lista de planos com o plano criado.
5. **Sem caminho antigo:** Não existe caminho que abra a tela Fichas antiga sem plano.

### Testes

- **Widget:** estado vazio de Planos abre o diálogo; detalhe do plano vazio; criar ficha volta ao plano.
- **Teste de rota:** depois de confirmar o nome da ficha, a rota atual é o detalhe do plano.
- **Robot:** conferir se algum passo usa "Montar fichas" ou "Criar ficha".

### Como foi entregue (mesma branch da 68)

- **Caminho único:** `criarPlanoEAbrir` em `planos/acoes_plano.dart` (diálogo `dialogoNovoPlano`, "Meu plano" sugerido, botões "Criar plano" e "Cancelar"). Lista, estado vazio de Planos, Bem-vindo e card "Crie seu plano" chamam a mesma função. Abre o detalhe com `go`, então a pilha fica lista → detalhe e a seta volta à lista.
- **Detalhe vazio (tela 28):** "Nenhuma ficha ainda" com "Nova ficha"; sem o botão tracejado e sem "Duplicar". Plano do professor vazio só mostra o aviso. "Nova ficha" já ficava no plano com o aviso "Adicionar exercícios" (PBI-61).
- **O que saiu:** "MONTAR MINHAS FICHAS" (Bem-vindo), "MONTAR FICHAS" do detalhe sem plano (vira "Criar plano") e o estado vazio "CRIAR FICHA" da tela Fichas, que agora volta ao plano quando não há ficha para abrir. O "Montar fichas" da Início (plano vazio com histórico) abre o detalhe do plano.
- **Testes:** um `ProviderScope` só, de conta nova até a Início (Bem-vindo → Criar plano → detalhe vazio → Nova ficha → fica no plano com o aviso → seta → lista com o plano → Início); detalhe vazio nos dois temas; Fichas sem ficha volta ao plano.

### Fora do escopo

- Criar a primeira ficha automaticamente.
- Modelos prontos de plano.

---

## PBI-71 · Registrar treino sempre à mão na Início

_Front · Junto da PBI-68_

**História:** Como atleta, quero registrar um treino de uma ficha, sem ficha ou de outro dia direto da Início, com ou sem plano, para não depender da tela de primeiro acesso.

### Contexto

Hoje o treino livre só é alcançável pelo Primeiro acesso e pelo card "Continuar treino". Com a PBI-68 o "Bem-vindo" fica só para conta nova, então o treino livre sumiria para quem já usa o app.

### Escopo

**Ação na Início (tela 23)**
- Linha-botão "Registrar treino" (ícone de prancheta, subtítulo "De uma ficha, sem ficha ou de outro dia") logo abaixo de "Esta semana". Visível sempre, inclusive com treino em andamento.
- Alvo de toque de no mínimo 56 px de altura, rótulo falado "Registrar treino".

**Comportamento**
- **Com plano em uso e fichas:** abre o sheet "Qual treino?" com as fichas do plano (que têm exercícios) e "Sem ficha". O dia do treino se escolhe na tela seguinte ("Dia em que treinou", padrão hoje).
- **Sem plano, ou plano sem fichas:** vai direto ao treino livre, sem sheet.
- O toque nos dias da semana (PBI-59) continua abrindo a folha do dia.

**Primeiro acesso**
- O botão secundário do Bem-vindo chama-se "Registrar treino" e faz o mesmo: sem plano, abre direto o treino livre.

### Critérios de aceite

1. **Sempre visível:** Dada qualquer conta que passou do primeiro acesso, a Início mostra "Registrar treino" abaixo da semana.
2. **Com fichas:** Dado um plano com fichas, quando toco em "Registrar treino", então vejo as fichas e "Sem ficha"; escolher uma abre o registro dessa ficha.
3. **Sem plano:** Dada uma conta sem plano, quando toco em "Registrar treino", então abre o treino livre direto.
4. **Dia:** Na tela de registro o dia vem como hoje e pode ser alterado para um dia passado.
5. **Primeiro acesso:** No "Bem-vindo", o botão "Registrar treino" abre o treino livre.

### Testes

- **Widget:** as quatro situações acima em `inicio_screen_test.dart` e `primeiro_acesso_screen_test.dart`.
- **Robot:** **impacta.** O passo que toca em "Registrar sem ficha" passa a tocar em "Registrar treino".

### Fora do escopo

- Atalho "Iniciar treino" na Início (pergunta aberta ao PO).
- Escolher o dia dentro do sheet.

---

## PBI-72 · Manter na ficha o exercício adicionado no treino?

_Front + API · Depois da PBI-70_

**História:** Como atleta, quando adiciono um exercício fora da ficha durante o treino, quero ser perguntado ao finalizar se ele fica na ficha ou só neste treino, para a ficha refletir o que realmente treino.

### Contexto

Hoje o exercício adicionado fora da ficha (PBI-17) entra só na sessão e nunca na ficha. O PO quer decidir na hora de salvar.

### Escopo

**Quando pergunta**
- Ao tocar em "Salvar treino" no Resumo (treino ao vivo) e ao salvar o registro de treino já feito.
- Condição: a sessão veio de uma ficha editável (do próprio atleta, não do professor) e tem pelo menos um exercício adicionado fora da ficha com pelo menos uma série marcada.
- Nunca pergunta em treino livre (sem ficha), nem ao editar uma sessão antiga.

**Diálogo (tela 25)**
- Título "Manter na ficha?". Texto: "Você adicionou um exercício que não está na ficha Treino B: Tríceps coice. Se mantiver, ele entra no fim da ficha com 2 séries de 20 × 10." Com mais de um, lista os nomes.
- Botões: "Manter na ficha" (primário), "Só neste treino" (secundário) e "Voltar ao resumo" (texto). Sem opção "não perguntar de novo".
- No Resumo, o exercício adicionado ganha a etiqueta "Fora da ficha".

**O que cada escolha faz**
- **Manter na ficha:** o exercício entra no fim da ficha com o número de séries marcadas e o alvo da última série marcada (carga e repetições, ou tempo). A sessão é salva normalmente.
- **Só neste treino:** a sessão é salva como hoje e a ficha não muda.
- **Voltar ao resumo:** nada é salvo.

**Técnica**
- Preferir uma única chamada de salvar com a lista `manterNaFicha` (ids dos exercícios), em uma transação. Se a API exigir duas chamadas, salvar a sessão primeiro; se a segunda falhar, avisar "Treino salvo, mas não deu para atualizar a ficha" com a ação "Tentar de novo".
- Depois de salvar, as telas de plano e ficha atualizam pela PBI-70 (`Mudanca.sessoes` já cobre plano e ficha).

### Critérios de aceite

1. **Pergunta:** Dado um exercício adicionado fora da ficha com séries marcadas, quando toco em "Salvar treino", então aparece "Manter na ficha?" com o nome do exercício.
2. **Manter:** Quando escolho "Manter na ficha", então a sessão é salva e a ficha passa a ter o exercício no fim, com as séries e o alvo do treino.
3. **Só neste treino:** Quando escolho "Só neste treino", então a sessão é salva e a ficha fica igual.
4. **Voltar:** Quando escolho "Voltar ao resumo", então nada é salvo e continuo no Resumo.
5. **Não pergunta:** Em treino livre, em ficha do professor, ao editar sessão antiga ou com exercício adicionado sem séries marcadas, o diálogo não aparece.
6. **Resumo:** O exercício adicionado aparece com a etiqueta "Fora da ficha".
7. **Falha parcial:** Dado que a sessão salvou e a atualização da ficha falhou, vejo "Treino salvo, mas não deu para atualizar a ficha" e posso tentar de novo.

### Testes

- **Widget:** os cenários acima em `resumo_treino_screen_test.dart` e `registrar_sessao_screen_test.dart`.
- **API:** salvar com `manterNaFicha` grava sessão e ficha juntas; com id de exercício que não é da sessão, recusa; ficha de outro usuário responde 404.
- **Robot:** sem impacto, o E2E usa treino livre, que não pergunta.

### Fora do escopo

- Escolher exercício por exercício.
- Remover da ficha o exercício que o atleta nunca faz.
- Reordenar a ficha pelo diálogo.
