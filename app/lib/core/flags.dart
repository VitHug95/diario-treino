/// Flags de recurso do app. Ligadas por `--dart-define` no build.
library;

/// Épico "Treino ao vivo" (Release 2, TV-3..TV-6). LIGADA por padrão: "Iniciar
/// treino agora" e "Continuar treino" abrem a tela de treino ao vivo (tela 14).
/// Para voltar ao fluxo antigo (registro em andamento na tela 3), compile com
/// `--dart-define=TREINO_AO_VIVO=false` (é o que o job de E2E usa enquanto o
/// Robot ainda percorre a tela antiga).
///
/// O default é `true` de propósito: assim o fluxo novo não depende de nenhum
/// `--dart-define` no Netlify nem no `flutter run` local.
const bool treinoAoVivoHabilitado =
    bool.fromEnvironment('TREINO_AO_VIVO', defaultValue: true);

/// Conecta o app ao Firebase Auth Emulator em vez do Firebase real. Usada só
/// no E2E (Robot) do CI, que sobe o emulator local: ligada por
/// `--dart-define=USE_AUTH_EMULATOR=true` no `flutter build web` do pipeline.
/// Em produção fica falsa, então o app fala com o Firebase real (nada muda).
const bool usarAuthEmulator =
    bool.fromEnvironment('USE_AUTH_EMULATOR', defaultValue: false);

/// Host do Auth Emulator (padrão localhost). Ajustável por
/// `--dart-define=AUTH_EMULATOR_HOST=...` se o emulator rodar em outro host.
const String authEmulatorHost =
    String.fromEnvironment('AUTH_EMULATOR_HOST', defaultValue: 'localhost');

/// Porta do Auth Emulator (padrão 9099, a do Firebase Emulator Suite).
const int authEmulatorPorta =
    int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
