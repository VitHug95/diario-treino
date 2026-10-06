import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_service.dart';

/// Fonte do ID token a ser anexado nas requisições. Devolve o ID token do
/// usuário logado no Firebase, ou nulo quando não há sessão.
typedef ProvedorToken = Future<String?> Function();

final provedorTokenProvider = Provider<ProvedorToken>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.obterIdToken;
});

/// URL base da API (prefixo /api/v1 do MAS 12). Ajustável por ambiente.
final urlBaseApiProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5289/api/v1',
  );
});

/// Interceptor que anexa o Bearer token quando houver, e propaga o
/// identificador de correlação para casar com os logs da API.
class TokenInterceptor extends Interceptor {
  TokenInterceptor(this._obterToken);

  final ProvedorToken _obterToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _obterToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ref.watch(urlBaseApiProvider),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(TokenInterceptor(ref.watch(provedorTokenProvider)));
  return dio;
});
