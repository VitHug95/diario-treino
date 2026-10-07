---
inclusion: fileMatch
fileMatchPattern: 'app/**'
---

# Design system — Diário de Treino

Referência visual do app. O guia completo (com a tabela de contraste e a voz do
texto) está em `docs/DESIGN.md`. Isto é o resumo operacional para o código.

## Regra de ouro

Nenhuma cor, tamanho de fonte, raio ou espaçamento escrito direto no widget.
Tudo vem do tema: `Theme.of(context).colorScheme`, a `ThemeExtension`
`AppColors`, os estilos de `AppText`, e as constantes `AppRadius`/`AppSpacing`/
`AppSizes`. Se faltar um token, adicione ao tema — não use literal na tela.

## Tipografia (Google Fonts, OFL)

- **Barlow Condensed** (600/700): títulos, números, botão principal.
- **Barlow** (400/500/600): todo o resto.
- Caixa alta só em `display-*`, `button`, `overline`, `table-head`. Texto
  corrido nunca em caixa alta.
- Campo editável nunca abaixo de 16px (evita zoom no mobile).
- Estilos nomeados em `theme/app_typography.dart` (display-xl/l/m/s, numeral,
  numeral-s, button, title, title-s, input-value, body, body-s, label, caption,
  overline, table-head).

## Cores (tokens por função, mesmo nome nos dois temas)

O `ColorScheme` cobre primary/on-primary/surface/background/error. O resto vem
da `AppColors` (ThemeExtension): família `obs` (obs, obsTint, obsLine, obsTitle,
obsBody), `bgHeader`/`bgHeaderInput`/`bgInput`/`bgTrack`, `lineDefault`/
`lineDashed`/`lineDivider`/`lineHeader`, `textSecondary`/`textStrong`,
`primaryTint`/`primaryText`, `chartLine`, `danger`/`dangerFill`, `iconMuted`,
cores "on-header".

Regras: `obs` (laranja) só para observação. `primary` (azul) só para a ação
principal — uma por tela; secundários usam surface + borda. `danger` só em
exclusão. Borda, não sombra: cards e campos separam do fundo com `lineDefault`.

## Raios (AppRadius)

8 (avisos), 10 (campos de série/selects), 12 (listas/campos de formulário),
14 (botão principal), 16 (cards), 18 (cartão de destaque), pill 999 (chips).

## Espaçamento (AppSpacing) — escala 4,6,8,10,12,14,16,20,24,28

Margem lateral 16 (cabeçalho 20, login 28). Padding de card 16 (14 compacto).
Entre cards 12, entre itens 8.

## Tamanhos (AppSizes)

touch-min 44, field-series 44, field-header 46, field-form 50,
button-secondary 48, button-primary 56, nav-bottom 78, icon 24/20.

## Componentes

- Botão principal: `primary`/`onPrimary`, estilo `button` caixa alta, altura 56,
  raio 14, largura total.
- Botão secundário: surface, borda `lineDefault`, `title-s`, altura 48–52, raio 14.
- Ação "adicionar": transparente, borda tracejada `lineDashed`, `body-s` 600,
  altura 44, raio 10.
- Card de exercício: surface + `lineDefault`, raio 16, sem sombra.
- Aviso de pré-preenchimento: `primaryTint` + `primaryOnTint`, raio 8.
- Bloco de observação: `obsTint` + borda `obsLine`, título `obsTitle`, corpo
  `obsBody`, raio 16.
- Chip de filtro: pílula 44. Selecionado: fundo `text-primary`, texto surface.
- Cabeçalho de registro/login/destaque: fundo `bgHeader`, texto on-header.
- Navegação inferior: Início / Fichas / Progresso, ícone 24 + rótulo 13/600,
  ativo `primaryText`, inativo `textSecondary`.

## Ícones

Lucide (`lucide_icons`), traço 2px. Ícone sem texto sempre com rótulo de
acessibilidade (Semantics).

## Tema

`ThemeMode.system` por padrão; botão sol/lua na tela inicial; opção em Perfil.
Conferir cada componente nos dois temas.
