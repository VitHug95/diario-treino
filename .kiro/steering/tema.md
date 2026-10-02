---
inclusion: fileMatch
fileMatchPattern: 'app/**'
---

# Tema claro e escuro (padrão de mercado) — ADR-08

O app tem tema claro e escuro. O padrão de mercado para Flutter, e o mais
eficiente, é usar `ThemeData` (um claro, um escuro) alimentado por **tokens**,
com `ThemeExtension` para cores próprias do produto que não cabem no
`ColorScheme` padrão (ex.: a cor do destaque de observação no gráfico).

## Regras

- **Nenhuma cor escrita direto no widget.** Nada de `Color(0xFF...)`,
  `Colors.blue` ou hex em tela. Toda cor vem de:
  - `Theme.of(context).colorScheme.*` (cores padrão do Material 3), ou
  - uma `ThemeExtension` própria (`Theme.of(context).extension<AppColors>()`).
- Um único `ColorScheme` por tema, derivado de `ColorScheme.fromSeed` quando
  possível, ajustado para as cores aprovadas (opções A clara e B escura do
  protótipo). Material 3 (`useMaterial3: true`).
- `ThemeMode` controlado por estado (Riverpod) e persistido com
  `shared_preferences`. Padrão: `ThemeMode.system`. Troca manual por botão na
  tela inicial e opção em Perfil (Sistema / Claro / Escuro).
- Tipografia e espaçamentos também por tokens (`TextTheme`), não valores soltos.
- Contraste mínimo de 4,5:1 em texto; conferir cada componente nos dois temas.

## Estrutura sugerida em `app/lib/theme/`

```
theme/
  app_colors.dart     ThemeExtension<AppColors> (cores próprias do produto)
  app_theme.dart       ThemeData claro e escuro montados a partir dos tokens
  theme_tokens.dart    sementes/paleta base (opções A e B)
```

A escolha do `ThemeMode` fica em `core/` (controller Riverpod + persistência),
porque é estado da aplicação, não definição de cor.
