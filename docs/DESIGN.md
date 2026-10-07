# Diário de Treino — Guia visual

Guia visual do app, com os dois temas aprovados: **claro (opção A)** e **escuro
(opção B)**. Os valores saem do protótipo navegável do canvas "Telas App de
Treino". Toda cor tem nome por função: o mesmo nome vale nos dois temas e só o
valor muda. O resumo operacional para o código está no steering
`.kiro/steering/design.md`.

## Princípios

- **Registrar rápido, entender depois.** A tela de registro tem o mínimo de
  atrito: valores grandes, campos de 44px, carga pré-preenchida. A tela de
  progresso é onde o app conversa.
- **A observação é a protagonista.** O laranja (`obs`) existe só para a
  observação do dia.
- **Azul é ação.** `primary` marca o que dá pra fazer. Uma ação principal por tela.
- **Borda, não sombra.** Cards e campos se separam do fundo com `line-default`.
- **Cabeçalho escuro para o que é registro.** Telas de lançamento abrem com
  `bg-header`.

## Tipografia

| Família | Uso | Pesos |
|---|---|---|
| Barlow Condensed | Títulos, números, botão principal | 600, 700 |
| Barlow | Todo o resto | 400, 500, 600 |

| Estilo | Família | Tam/altura | Peso | Spacing | Onde |
|---|---|---|---|---|---|
| display-xl | Barlow Condensed | 52 / 0,95 | 700 | 0,5 | Nome do app no login |
| display-l | Barlow Condensed | 38 / 1 | 700 | 0,3 | Título das telas principais |
| display-m | Barlow Condensed | 34 / 1 | 700 | 0 | Título no cabeçalho escuro |
| display-s | Barlow Condensed | 30 / 1 | 700 | 0 | Telas secundárias |
| numeral | Barlow Condensed | 26 / 1 | 700 | 0 | Números de resumo |
| numeral-s | Barlow Condensed | 22 / 1 | 700 | 0 | Número da série, letra da ficha |
| button | Barlow Condensed | 20 / 1 | 700 | 1 | Botão principal |
| title | Barlow | 18 / 1,3 | 600 | 0 | Nome do exercício |
| title-s | Barlow | 17 / 1,3 | 600 | 0 | Itens de lista |
| input-value | Barlow | 17 / 1,2 | 400 | 0 | Valores nos campos de série |
| body | Barlow | 16 / 1,4 | 400 | 0 | Texto corrido e campos |
| body-s | Barlow | 15 / 1,4 | 400 | 0 | Apoio, botões secundários |
| label | Barlow | 14 / 1,3 | 600 | 0 | Rótulo de campo |
| caption | Barlow | 13 / 1,35 | 400 | 0 | Metadados, legendas |
| overline | Barlow | 13 / 1,2 | 600 | 1,2 | Sobretítulo |
| table-head | Barlow | 12 / 1,2 | 600 | 0,6 | Cabeçalho de colunas |

Campo editável nunca usa fonte menor que 16px.

## Cores

| Token | Claro (A) | Escuro (B) | Uso |
|---|---|---|---|
| bg-page | #F3F2EE | #0E0F12 | Fundo das telas |
| bg-surface | #FFFFFF | #1A1C21 | Cards, listas, navegação |
| bg-input | #F8F7F4 | #23262C | Campos de série, blocos de resumo |
| bg-header | #15171C | #141B33 | Cabeçalho de registro, login, destaque |
| bg-header-input | #1F2228 | #1E2642 | Campos no cabeçalho |
| bg-track | #E6E4DD | #23262C | Trilho das abas segmentadas |
| line-default | #DEDCD5 | #2C2F36 | Bordas |
| line-dashed | #B5B2A8 | #4A4E57 | Bordas tracejadas de "adicionar" |
| line-divider | #ECEAE4 | #2A2D34 | Grade do gráfico, divisórias |
| line-header | #3A3E47 | #2C3350 | Bordas no cabeçalho |
| text-primary | #15171C | #F2F2EF | Texto principal |
| text-secondary | #5B5F68 | #A4A8B1 | Legendas e apoio |
| text-strong | #3B3E45 | #C9CCD2 | Rótulos de formulário |
| text-on-header | #F3F2EE | #F2F2EF | Texto no cabeçalho |
| text-on-header-muted | #B9BCC4 | #A4A8B1 | Apoio no cabeçalho |
| text-on-header-label | #D7D9DE | #C9CCD2 | Rótulos no cabeçalho |
| primary | #2552D9 | #2F5BEA | Botão principal |
| on-primary | #FFFFFF | #FFFFFF | Texto sobre o botão principal |
| primary-text | #2552D9 | #8FA9FF | Links, item ativo da navegação |
| primary-hover | #1A3FAF | #B4C5FF | Link pressionado |
| primary-tint | #E7ECFB | #1E2A52 | Avisos, seleção |
| primary-on-tint | #1E3FA8 | #B4C5FF | Texto sobre primary-tint |
| chart-line | #2552D9 | #7B9BFF | Linha do gráfico |
| link-on-header | #8FA9FF | #8FA9FF | Links no cabeçalho |
| obs | #C2410C | #FF8A4C | Marca da observação |
| obs-tint | #FBEDE6 | #33201A | Fundo da observação |
| obs-line | #F0C9B5 | #5A3220 | Borda da observação |
| obs-title | #8A2E08 | #FFB48A | Título da observação |
| obs-body | #3B1A0C | #FFD9C4 | Texto da observação |
| danger | #B42318 | #FF7A6E | Texto de exclusão |
| danger-fill | #B42318 | #C8372B | Botão que confirma exclusão |
| icon-muted | #9A9DA4 | #6E727B | Ícones decorativos |

### Regras de cor

- `obs` e família só para observação.
- `primary` só para a ação principal; secundários usam `bg-surface` + `line-default`.
- `danger` só em ações de exclusão.
- No gráfico, pontos mudam de tamanho quando selecionados (diferença não depende só da cor).

## Espaçamento

Escala: 4, 6, 8, 10, 12, 14, 16, 20, 24, 28. Margem lateral 16 (cabeçalho 20,
login 28). Padding de card 16 (14 compacto). Entre cards 12, entre itens 8.
Grade de séries: colunas `36 · 1fr · 1fr · 1fr · 44` com 6 de espaço.

## Raios

8 (avisos), 10 (campos de série/selects), 12 (listas/campos de formulário),
14 (botão principal), 16 (cards de exercício e seções), 18 (cartão de destaque),
pill 999 (chips).

## Tamanhos

touch-min 44, field-series 44, field-header 46, field-form 50,
button-secondary 48, button-primary 56, nav-bottom 78, icon 24/20.

## Componentes

- Botão principal: `primary`, texto `on-primary` no estilo `button` caixa alta,
  altura 56, raio 14, largura total.
- Botão secundário: `bg-surface`, borda `line-default`, `title-s`, altura 48–52, raio 14.
- Ação de adicionar: transparente, borda 1px tracejada `line-dashed`, `body-s` 600,
  altura 44, raio 10.
- Campo de série: `bg-input`, borda `line-default`, raio 10, altura 44, valor `input-value`.
- Card de exercício: `bg-surface`, borda `line-default`, raio 16.
- Aviso de pré-preenchimento: `primary-tint` com `primary-on-tint`, raio 8.
- Bloco de observação: `obs-tint`, borda `obs-line`, título `obs-title`, corpo `obs-body`, raio 16.
- Chip de filtro: pílula 44. Selecionado: fundo `text-primary`, texto `bg-surface`.
- Abas segmentadas: trilho `bg-track` 4px de respiro, raio 12; aba ativa `bg-surface` raio 9.
- Navegação inferior: Início, Fichas, Progresso; ícone 24 + rótulo 13/600;
  ativo `primary-text`, inativo `text-secondary`.

## Iconografia

Lucide (`lucide_icons`), traço 2px, grade de 24. Ícone sozinho sempre com rótulo
de acessibilidade.

## Acessibilidade

- Toque mínimo 44px, inclusive pontos do gráfico.
- Todo campo com rótulo visível; todo ícone sozinho com rótulo.
- Contraste mínimo 4,5:1 em texto nos dois temas.
- Árvore de semântica habilitada no web.
