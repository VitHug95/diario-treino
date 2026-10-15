import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/flags.dart';
import 'core/tema/tema_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Árvore de semântica habilitada no web (ADR-07): sem ela o Flutter web
  // desenha em canvas e os testes E2E (Robot) não acham elementos no DOM.
  SemanticsBinding.instance.ensureSemantics();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // E2E (PBI-26): quando ligada por --dart-define, aponta o auth para o
  // Firebase Auth Emulator local do CI, para o cadastro/login funcionar sem o
  // Firebase real. Em produção a flag é falsa e o app usa o Firebase real.
  if (usarAuthEmulator) {
    await FirebaseAuth.instance
        .useAuthEmulator(authEmulatorHost, authEmulatorPorta);
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
