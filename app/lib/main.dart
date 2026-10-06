import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
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
