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
    // Atalho de login do E2E (SOMENTE com o emulador): entra já autenticado,
    // sem passar pela digitação na tela de cadastro. O teste E2E do PBI-26 roda
    // com integration_test (tester.enterText na árvore de widgets) e não exerce
    // a tela de login — por isso o usuário é provisionado aqui no boot. Com o
    // usuário logado, o redirect do go_router cai direto na Início e o
    // TokenInterceptor anexa o ID token do emulador às chamadas da API.
    // Em produção (usarAuthEmulator=false) nada disto roda.
    await _autenticarParaE2E();
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

/// Login automático do E2E (PBI-26), usado só com o Firebase Auth Emulator.
/// Tenta entrar com um usuário fixo de teste; se ele ainda não existe no
/// emulador, cria e entra. Qualquer falha é apenas registrada (o app abre na
/// tela de login e o teste falha de forma visível) — nunca derruba o boot.
Future<void> _autenticarParaE2E() async {
  const email = 'e2e@teste.local';
  const senha = 'Teste@12345';
  final auth = FirebaseAuth.instance;
  try {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: senha);
      debugPrint('E2E auto-login: signIn OK');
    } on FirebaseAuthException catch (e) {
      // Primeira execução: o usuário ainda não existe no emulador.
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        final cred = await auth.createUserWithEmailAndPassword(
            email: email, password: senha);
        await cred.user?.updateDisplayName('Atleta E2E');
        await cred.user?.reload();
        debugPrint('E2E auto-login: createUser OK');
      } else {
        rethrow;
      }
    }
    debugPrint('E2E auto-login: currentUser=${auth.currentUser?.uid}');
  } catch (e) {
    debugPrint('E2E auto-login FALHOU: $e');
  }
}
