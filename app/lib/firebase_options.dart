// Opções do Firebase para o app (plataforma Web).
//
// Montado a partir do firebaseConfig do console (projeto diario-treino-c21b6).
// As credenciais de web do Firebase são públicas por design (vão embutidas no
// cliente); a segurança vem da validação do token na API e das regras do
// Firebase, não de esconder estes valores.
//
// Este arquivo fica fora do versionamento (.gitignore): cada ambiente gera o
// seu. Para regenerar com a FlutterFire CLI: `flutterfire configure`.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // O app começa como Web (ADR-07). Outras plataformas entram quando o
    // respectivo app for registrado no Firebase.
    throw UnsupportedError(
      'DefaultFirebaseOptions ainda não configurado para '
      '$defaultTargetPlatform. Rode `flutterfire configure` para adicionar.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyARSpJ8oI2tMcXvMTkJ4MsQkp7k7G3eCAE',
    appId: '1:182423230129:web:358c49d7748eac4ee3b490',
    messagingSenderId: '182423230129',
    projectId: 'diario-treino-c21b6',
    authDomain: 'diario-treino-c21b6.firebaseapp.com',
    storageBucket: 'diario-treino-c21b6.firebasestorage.app',
    measurementId: 'G-OKZTYD7D6T',
  );
}
