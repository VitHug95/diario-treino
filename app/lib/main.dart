import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/tema/tema_controller.dart';
import 'firebase_options.dart';

/// Liga o Firebase Auth Emulator (SOMENTE no E2E do CI, PBI-26). Passado por
/// `--dart-define=USE_AUTH_EMULATOR=true`. Em produção fica falso e o app usa o
/// Firebase real, sem qualquer efeito deste trecho.
const _usarAuthEmulator =
    bool.fromEnvironment('USE_AUTH_EMULATOR', defaultValue: false);

/// Host do emulador (padrão localhost:9099), ajustável por dart-define.
const _authEmulatorHost =
    String.fromEnvironment('AUTH_EMULATOR_HOST', defaultValue: 'localhost');
const _authEmulatorPort =
    int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Árvore de semântica habilitada no web (ADR-07): sem ela o Flutter web
  // desenha em canvas e os testes E2E (Robot) não acham elementos no DOM.
  SemanticsBinding.instance.ensureSemantics();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (_usarAuthEmulator) {
    await FirebaseAuth.instance
        .useAuthEmulator(_authEmulatorHost, _authEmulatorPort);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DiarioTreinoApp(),
    ),
  );
}
