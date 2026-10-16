# Épico Planos (PBI-44 a PBI-49)

Ordem sugerida: PBI-44, depois 45, 46 e 47. A PBI-48 entra com o modo educador. A PBI-49 é avulsa e só entra depois do E2E fechar.

Protótipos 18 a 21 no canvas, nos temas claro e escuro.

## Decisões já tomadas (PO, 15/10)

- O aluno **não edita** plano montado pelo professor: só copia, e edita a cópia.
- Se o vínculo acabar, o plano do professor **fica com o aluno**, em leitura, com opção de copiar.
- Só **um plano em uso** por atleta.
- O nome da ficha é livre. "A, B, C" é convenção; a sequência vem de `ordem`.
- Fica fora o que dá para o atleta fazer sozinho amanhã: planos prontos em destaque e busca de profissionais.

## Premissas assumidas (confirmar com o PO)

- O primeiro plano do atleta nasce em uso.
- Excluir o plano em uso passa o uso para o plano com a sessão mais recente; sem outro plano, a Início mostra o Primeiro acesso.
- Excluir plano do professor: o atleta só exclui depois que o vínculo acabar (a confirmar).
- Duplicar e copiar geram "Nome (cópia)", fora de uso, sem sessões, com fichas, exercícios, alvos e tags de rodada.
- Ordem da lista: em uso primeiro, depois pelo início mais recente.

## Riscos

- **E2E (PBI-26):** a tela Fichas e o Robot dependem de `POST /planos` sem corpo e de `GET /planos/ativo`. Os dois ficam como estão. A PBI-49 muda o passo que escolhe o exercício.
- **Início depende do plano único:** "próximo da sequência" e a lista passam a olhar o plano em uso (PBI-47). Tem teste com sessões de dois planos.
- **Autorização:** plano de outro atleta responde 404; edição de plano de leitura responde 403.
- **Plano do professor sem como criá-lo:** a tela 20 só fica alcançável quando o épico do educador existir. Até lá, cobertura por teste de widget e de integração com plano de autor diferente.
- **Navegação:** a aba Fichas vira Planos.
- **Cronograma semanal (PBI-35):** deve consultar o plano em uso.

## Definição de pronto (vale para todas)

- Critérios de aceite passando e cenários de Robot da PBI no CI.
- Testes unitários e de integração das regras novas, com o caso 404 de endpoint novo.
- Tema claro e escuro, contraste mínimo 4,5:1, alvo de toque de 44 px, largura máxima de 600 px no web.
- Semântica habilitada em todo elemento interativo (ADR-07).
- MER e MAS atualizados quando a PBI mexer em modelo ou regra.

## Fora do épico

- Criar e editar plano pelo professor (épico do educador).
- Planos prontos em destaque e busca de profissionais.
- Capa ou imagem do plano, compartilhar e exportar plano.
- Estatísticas por plano.
- Imagens dos exercícios.

---

## PBI-44 · Vários planos por atleta: banco e API

_Banco + API · R1_

**História:** Como atleta, quero ter mais de um plano de treino, com um deles em uso, para alternar entre ciclos (força, hipertrofia, viagem) sem apagar nem refazer nada.

### Contexto

Hoje o índice único parcial `(atleta_id) WHERE ativo` em `plano_treino` garante um plano por atleta. Ele cai. Para a coluna `ativo` não ficar com dois significados (plano excluído ou não, e plano que a tela Início segue), nasce a coluna `em_uso`. `autor_id` e `atleta_id` já são separados no MER, então o plano montado pelo professor para o aluno não pede coluna nova.

| Coluna | Significa | Regra |
|---|---|---|
| `ativo` | Plano existente com histórico | Igual a hoje. Só vira `false` quando o plano é excluído e já tem sessões ligadas: ele some das telas, mas o histórico fica (junto com `em_uso = false`). |
| `em_uso` (nova) | O plano que a Início segue | No máximo um por atleta. Índice único parcial `(atleta_id) WHERE em_uso` e `CHECK (NOT em_uso OR ativo)`. |
| autor ≠ atleta | Plano do professor | Somente leitura para o atleta. Sem coluna nova, a regra sai da comparação dos dois campos. |

### Escopo

**Banco (migration)**
- `plano_treino.em_uso boolean NOT NULL DEFAULT false`, preenchida com o valor de `ativo` para os planos existentes.
- Remove o índice único `(atleta_id) WHERE ativo` e cria o índice único parcial em `em_uso`, mais o `CHECK`.
- **Sem mudança** em `treino`, `treino_exercicio` e `sessao`: `sessao.treino_id` já liga a sessão à ficha.

**API**
- `GET /planos`: planos do atleta com `ativo` (id, nome, início, `emUso`, autor, `somenteLeitura`, quantidade de fichas e de exercícios).
- `GET /planos/{id}`: detalhe com as fichas e a data da última vez, no mesmo contrato de hoje do plano ativo.
- `POST /planos` com `{ nome }` cria o plano; o primeiro do atleta nasce em uso. **Sem corpo** mantém o comportamento de hoje, até o E2E fechar.
- `PUT /planos/{id}` renomeia.
- `POST /planos/{id}/em-uso` troca o uso numa transação só, sem janela com zero ou dois em uso.
- `POST /planos/{id}/duplicar` cria "Nome (cópia)" com autor = atleta, fichas, exercícios, alvos e tags de rodada. Não copia sessões. A cópia nasce fora de uso.
- `DELETE /planos/{id}` exclui o plano e as fichas dele. Sem sessões ligadas, apaga de verdade. Com sessões, marca `ativo = false` e `em_uso = false`. Se estava em uso, o uso passa para o plano com a sessão mais recente; se não houver outro, fica sem plano em uso.
- Rotas de ficha e de exercício da ficha em plano de autor diferente do atleta retornam **403** em Problem Details (`plano-somente-leitura`). Leitura e registro de sessão continuam liberados.
- `GET /planos/ativo` segue funcionando como alias do plano em uso até o front migrar.

**O que o código de hoje obriga (revisão de 15/10)**
- FK `sessao.treino_id` é `Restrict`: a regra "apaga se vazio, esconde se tem histórico" é a mesma do `ExcluirFichaAsync` (PBI-36), olhando as fichas do plano inteiro.
- `POST /planos/{id}/treinos` passa a usar o id da URL, com acesso e somente leitura verificados.
- `POST /planos/fichas-de-treino` (PBI-19) passa a gravar no plano em uso.
- Índice `ux_plano_atleta_ativo` é derrubado e recriado em `em_uso`, com novo `ModelSnapshot`.
- Autoria: método novo no repositório para o `autor_id`; o 403 só vale depois de passar pelo `IControleAcesso` (outro usuário continua 404).
- Excluir conta continua certo com vários planos e com planos escondidos; ganha teste com três planos, um escondido.
- O fake em `ServicoPlanejamentoTests` implementa os métodos novos de `IRepositorioPlano`.
- `PlanoEndpointTests`, `MeEndpointTests` e `ExcluirFichaEndpointTests` devem passar sem alteração.

### Critérios de aceite

1. **Segundo plano:** com um plano em uso, criar "Treino de viagem" gera dois planos e o primeiro continua em uso.
2. **Primeiro plano:** sem planos, o primeiro nasce em uso.
3. **Trocar o uso:** definir "Treino de viagem" em uso tira "Hipertrofia" de uso na mesma operação. Com duas chamadas simultâneas, nunca sobram dois nem nenhum em uso.
4. **Duplicar:** a cópia tem as mesmas fichas, exercícios, alvos e tags de rodada, autor igual ao atleta, nasce fora de uso e sem sessões.
5. **Excluir o plano em uso:** com outro plano com sessão registrada, o uso passa para o outro. Sessões e gráficos do excluído continuam.
6. **Somente leitura:** plano com autor diferente do atleta responde 403 para renomear, criar ficha ou editar exercício. GET e registro de sessão funcionam.
7. **Isolamento:** plano de outro atleta responde 404 em toda rota.
8. **Dados antigos:** depois da migration, o plano ativo de cada atleta aparece como em uso.
9. **Ficha no plano certo:** `POST /planos/{id}/treinos` num plano fora de uso cria a ficha nesse plano.
10. **Excluir conta:** com três planos, um escondido, tudo some sem erro de FK.
11. **Compatibilidade:** `POST /planos` sem corpo e `GET /planos/ativo` respondem como antes.

### Testes

- **Unitário:** regra de troca de uso e escolha do plano mais recente ao excluir.
- **Integração:** preenchimento da migration, transação da troca com chamadas concorrentes, 403 e 404, duplicação completa.
- **Robot:** nenhum cenário novo; o fluxo principal atual continua verde.

---

## PBI-45 · Lista de planos

_Front · R1 · Tela 18_

**História:** Como atleta, quero ver todos os meus planos numa lista, com o que está em uso em destaque, para trocar de ciclo em poucos toques.

### Contexto

A aba **Fichas** passa a se chamar **Planos**. O conteúdo da tela Fichas de hoje vira o detalhe do plano (PBI-46). A lista é vertical, e não um carrossel: com 600 px no web o deslize horizontal é ruim de usar, não é navegável por teclado e o Robot não acha cada item.

### Escopo

**Navegação**
- Aba renomeada para "Planos" com ícone de calendário e label de semântica "Planos".
- Rota nova da lista; a tela atual de Fichas passa a ser aberta a partir dela, dentro do plano.

**Lista (tela 18)**
- Um cartão por plano: nome, tag "Em uso" (ícone e texto, nunca só cor), "N fichas · M exercícios · desde dd/mm/aaaa". O plano em uso tem borda de 2 px na cor principal.
- Plano do professor mostra "Prof. Nome" e o chip "Do professor · só leitura" com cadeado.
- Ordem: em uso primeiro, depois pelo início mais recente.
- Cada cartão tem dois alvos separados, ambos com no mínimo 44 px: abrir o plano e o botão de menu, com label "Mais ações de {plano}".
- Texto de apoio fixo: só um plano fica em uso, é ele que alimenta a sequência da Início.

**Menu de ações**
- Plano próprio: Definir como em uso (some no plano que já está em uso), Duplicar plano, Renomear e Excluir plano.
- Plano do professor: Definir como em uso, Copiar para editar. Sem Excluir enquanto o vínculo estiver ativo.
- Excluir plano pede confirmação e explica o que acontece com o uso.

**Novo plano e estados**
- Botão "Novo plano" no topo. Pede só o nome, no mesmo diálogo de nome que a ficha usa hoje, e abre o detalhe do plano criado.
- Carregando, erro com "Tentar de novo" e vazio. Sem nenhum plano, a lista mostra o Primeiro acesso (tela 6).

### Critérios de aceite

1. **Lista:** com três planos, vejo os três, o em uso primeiro e com a tag "Em uso".
2. **Trocar o uso:** "Definir como em uso" no segundo plano move a tag e a Início passa a seguir o novo plano.
3. **Menu sem ação inválida:** no plano em uso, o menu não mostra "Definir como em uso".
4. **Plano do professor:** o cartão mostra o chip com cadeado e o menu não tem Renomear.
5. **Novo plano:** informar "Treino de viagem" cria o plano e abre o detalhe vazio, com "Nova ficha".
6. **Excluir:** confirmar tira o plano da lista; se era o em uso, o uso passa para outro (PBI-44).
7. **Sem plano:** sem planos, a lista mostra o Primeiro acesso.
8. **Acessibilidade:** cada cartão expõe "abrir" e "menu" como botões separados, com labels e alvo mínimo de 44 px. O Robot encontra cada plano pelo nome.

### Testes

- **Widget:** ordem da lista, tag, menu condicional, plano do professor e estado vazio.
- **Robot:** criar o segundo plano e trocar o uso (critérios 1, 2 e 5).

### Fora do escopo

- Reordenar planos. Imagem de capa. Planos prontos e busca de profissionais.

---

## PBI-46 · Detalhe do plano

_Front · R1 · Tela 19_

**História:** Como atleta, quero abrir um plano e ver as suas fichas, para iniciar ou editar qualquer ficha, mesmo que o plano não esteja em uso.

### Contexto

O conteúdo da tela Fichas de hoje continua igual, agora dentro do plano escolhido. Iniciar uma ficha de plano fora de uso é permitido: a sessão fica ligada à ficha, e a sequência da Início continua a do plano em uso (PBI-47).

### Escopo

**Cabeçalho (tela 19)**
- Seta de voltar para a lista, "Plano em uso" com ícone (ou o botão "Definir como plano em uso" quando o plano está fora de uso), nome, "Desde dd/mm/aaaa · N fichas · criado por você".

**Fichas**
- Uma linha por ficha: quadrado com o nome da ficha quando ele tem até 3 caracteres (A, B, C) e, quando é maior, a posição na sequência (1, 2, 3). Depois, o nome, "N exercícios · último em dd/mm" e a seta.
- A ordem da sequência vem de `ordem`, não do nome.
- Tocar abre a ficha (tela 13). A seta de voltar da tela 13 volta para este plano.
- "Nova ficha" em linha tracejada, no fim da lista.

**Ações do plano**
- Duplicar plano (abre a cópia) e Renomear.
- Excluir plano com confirmação: o plano e as fichas saem da lista, as sessões e os gráficos continuam, e, se ele estava em uso, o uso passa para o último plano usado.

### Critérios de aceite

1. **Abrir plano:** tocar em "Hipertrofia" mostra as três fichas com o resumo de cada uma.
2. **Ficha de plano fora de uso:** iniciar uma ficha de "Treino de viagem" (fora de uso) liga a sessão a essa ficha e a Início continua no plano em uso.
3. **Nova ficha:** criar a ficha "D" a coloca no fim da lista com a posição 4.
4. **Nome longo:** "Peito pesado" mostra a posição dela no quadrado.
5. **Duplicar:** abre "Nome (cópia)", fora de uso, com as mesmas fichas.
6. **Excluir em uso:** o aviso explica que o uso passa para o último plano usado, e confirmar leva à lista.
7. **Definir como em uso:** o botão vira "Este plano está em uso".
8. **Voltar:** da ficha (tela 13), a seta volta ao plano de origem.

### Testes

- **Widget:** quadrado da ficha (nome curto e longo), cabeçalho nos dois estados de uso e o aviso de excluir.
- **Robot:** abrir um plano e iniciar uma ficha dele (critérios 1 e 2).

### Fora do escopo

- Estatísticas por plano. Compartilhar/exportar. Reordenar fichas por arrastar (continua como hoje).

---

## PBI-47 · Início segue o plano em uso

_Front · R1 · Telas 2 e 6_

**História:** Como atleta, quero que a Início siga o plano que eu escolhi, para a sequência A, B, C e o "próximo da sequência" refletirem o ciclo atual.

### Escopo (regras)

- "Próximo da sequência" considera só as fichas do plano em uso: a ficha seguinte à última registrada **dentro desse plano**.
- Sessão de ficha de outro plano não muda a sequência do plano em uso. Treino livre também não.
- A faixa semanal continua mostrando os dias treinados de qualquer plano.
- Sem plano em uso (todos excluídos), a Início mostra o Primeiro acesso (tela 6).
- O nome do plano aparece junto do título da lista de fichas.

### Critérios de aceite

1. **Troca de plano:** a Início passa a listar as fichas do novo plano e o "próximo da sequência" dele.
2. **Sequência preservada:** treino de ficha de outro plano ontem não muda o "próximo da sequência".
3. **Faixa semanal:** o dia desse treino aparece marcado.
4. **Sem plano em uso:** a Início mostra o Primeiro acesso.

### Testes

- **Unitário:** `proximaFicha` com sessões de dois planos e com treino livre.
- **Widget:** Início com e sem plano em uso.

---

## PBI-48 · Plano do professor: leitura e cópia

_Front (regra de API já na PBI-44) · R2 · Telas 20 e 18_

**História:** Como atleta com professor, quero ver e seguir o plano que ele montou, sem risco de estragá-lo, e poder copiá-lo para ajustar do meu jeito.

### Escopo

- **Leitura (tela 20):** cabeçalho com cadeado e "Criado por Prof. Nome". Aviso fixo: "Plano montado pelo seu professor. Você treina e registra à vontade, mas só ele edita. Para mudar algo, copie o plano." Fichas só para abrir e treinar. Botão principal "Definir como plano em uso", que vira "Este plano está em uso".
- **Copiar para editar:** botão secundário com confirmação: "Você ganha uma cópia sua, que pode editar. O plano do professor continua como está." Mesma operação de duplicar da PBI-44.
- **Fim do vínculo:** o plano continua com o aluno, listado, somente leitura e copiável.

### Critérios de aceite

1. Leitura: cadeado, aviso e nenhum botão de edição.
2. Treinar: sessão gravada normalmente, ligada à ficha.
3. Em uso: a Início passa a segui-lo.
4. Copiar: surge "Nome (cópia)" editável, e o original continua intacto.
5. Fim do vínculo: o plano continua na lista, somente leitura e copiável.
6. Pela API: editar responde 403 (PBI-44).

---

## PBI-49 · Adicionar exercícios: seletor revisado

_Front (avulsa) · Telas 8 e 21_

**História:** Como atleta montando uma ficha, quero adicionar vários exercícios de uma vez, com botões e ícones que deixem claro o que cada toque faz, para não reabrir o seletor a cada exercício.

### Escopo (tela 21)

- Cabeçalho com seta de voltar (44 px) e título "Adicionar exercícios", com a ficha de destino acima. Sem "Fechar".
- Busca com lupa e botão de limpar (x, 44 px). Filtro "Músculo: Todos" (48 px) abre folha de baixo com uma opção por linha (54 px), contagem e marca na escolhida.
- "Criar exercício novo" como primeira linha da lista (tracejada). Na busca sem resultado, um único "Criar "{busca}"".
- Cada linha é um botão com estado: quadrado do membro, nome, "músculo · forma de medir", "Meu" e um círculo de 44 px ("+" vazado / "✓" cheio). Tocar alterna.
- Rodapé fixo "Adicionar N exercícios"; com N = 0, desabilitado e "Escolha os exercícios".
- O seletor devolve a lista dos escolhidos, na ordem tocada. Falha parcial: as que entraram ficam e o app avisa qual não entrou.
- Criar exercício novo volta ao seletor com ele já marcado.

> **Muda o comportamento do E2E.** Só entra depois do E2E (PBI-26) fechar, ou junto da atualização do Robot. **Sujeita à aprovação do PO.** Versão barata se a seleção múltipla não for aprovada: remover "Fechar", trocar o "+" por seta, unificar o botão de criar e acrescentar o quadrado do membro.

### Critérios de aceite

1. Adicionar vários na ordem tocada. 2. Desfazer. 3. Sem seleção, botão desabilitado. 4. Voltar sem adicionar. 5. Criar exercício volta marcado. 6. Busca sem resultado com um único criar. 7. Filtro mantém as escolhas de outros membros no contador. 8. No registro (PBI-17), entram com série em branco. 9. Cada linha anuncia "Adicionar X" / "Remover X", alvos de 44 px.
