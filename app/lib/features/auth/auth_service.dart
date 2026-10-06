import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Erro de autenticação já traduzido para mensagem amigável.
class AuthException implements Exception {
  const AuthException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Encapsula o firebase_auth. No web, o login com Google usa
/// signInWithPopup (não precisa do pacote google_sign_in).
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  /// Emite o usuário atual a cada mudança de sessão (login, logout, refresh).
  Stream<User?> get mudancasDeAutenticacao => _auth.authStateChanges();

  User? get usuarioAtual => _auth.currentUser;

  /// ID token atual, usado pelo interceptor do Dio para falar com a API.
  Future<String?> obterIdToken() async => _auth.currentUser?.getIdToken();

  Future<void> cadastrar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: senha,
      );
      await cred.user?.updateDisplayName(nome.trim());
      await cred.user?.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traduzir(e));
    }
  }

  Future<void> entrarComEmail({
    required String email,
    required String senha,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: senha);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traduzir(e));
    }
  }

  Future<void> entrarComGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      await _auth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traduzir(e));
    }
  }

  Future<void> enviarRedefinicaoSenha(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_traduzir(e));
    }
  }

  Future<void> sair() => _auth.signOut();

  /// Traduz os códigos do Firebase para mensagens claras (critério do PBI-08).
  static String _traduzir(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'E-mail ou senha incorretos.',
      'invalid-email' => 'E-mail inválido.',
      'email-already-in-use' => 'Este e-mail já está cadastrado.',
      'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
      'user-disabled' => 'Esta conta está desativada.',
      'too-many-requests' => 'Muitas tentativas. Tente de novo em instantes.',
      'network-request-failed' =>
        'Sem conexão. Verifique sua internet e tente de novo.',
      'popup-closed-by-user' ||
      'cancelled-popup-request' =>
        'Login com Google cancelado.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }
}

/// Instância do FirebaseAuth. Sobrescrevível em testes.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(firebaseAuthProvider)),
);

/// Estado de autenticação observável pelas telas e pelo roteador.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).mudancasDeAutenticacao,
);
