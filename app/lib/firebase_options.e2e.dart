// Opções do Firebase para o build de E2E (PBI-26), que roda contra o Firebase
// Auth Emulator — nunca contra o Firebase real. Como o emulador aceita qualquer
// apiKey, os valores aqui são de demonstração; o que importa é o `projectId`,
// que precisa casar com o `Firebase:ProjectId` da API no E2E (demo-diario-treino),
// para o issuer/audience do token baterem.
//
// O CI copia este arquivo para `firebase_options.dart` antes de `flutter build
// web`, já que o `firebase_options.dart` de verdade é gitignored (um por
// ambiente). Este arquivo NÃO contém segredo nem credencial real.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions (E2E) só cobre Web.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-diario-treino',
    authDomain: 'demo-diario-treino.firebaseapp.com',
    storageBucket: 'demo-diario-treino.appspot.com',
  );
}
