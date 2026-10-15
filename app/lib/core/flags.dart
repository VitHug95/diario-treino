/// Flags de recurso do app. Ligadas por `--dart-define` no build.
library;

/// Épico "Treino ao vivo" (Release 2, TV-3..TV-6). Enquanto falso, "Iniciar
/// treino agora" e "Continuar treino" mantêm o fluxo atual (registro em
/// andamento na tela 3). Quando ligada (`--dart-define=TREINO_AO_VIVO=true`),
/// esses caminhos abrem a tela de treino ao vivo (tela 14). Fica atrás da flag
/// porque TV-3/4/5/6 só fecham um treino quando estão todas prontas.
const bool treinoAoVivoHabilitado =
    bool.fromEnvironment('TREINO_AO_VIVO', defaultValue: false);
