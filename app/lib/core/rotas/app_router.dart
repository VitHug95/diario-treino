import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_service.dart';
import '../../features/auth/cadastro_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/inicio/inicio_screen.dart';

/// Nomes de rota centralizados, para navegação sem strings mágicas.
abstract final class Rotas {
  const Rotas._();

  static const inicio = '/';
  static const login = '/login';
  static const cadastro = '/cadastro';
}

/// Configuração do go_router. O redirecionamento depende do estado de
/// autenticação: sem sessão, o usuário vai para o login; com sessão, não fica
/// preso nas telas de auth.
final routerProvider = Provider<GoRouter>((ref) {
  // Reavalia o redirect sempre que o estado de autenticação muda.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: Rotas.inicio,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);

      // Enquanto carrega o estado inicial, não redireciona.
      if (auth.isLoading) {
        return null;
      }

      final logado = auth.value != null;
      final emTelaDeAuth =
          state.matchedLocation == Rotas.login || state.matchedLocation == Rotas.cadastro;

      if (!logado && !emTelaDeAuth) {
        return Rotas.login;
      }
      if (logado && emTelaDeAuth) {
        return Rotas.inicio;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Rotas.inicio,
        name: 'inicio',
        builder: (context, state) => const InicioScreen(),
      ),
      GoRoute(
        path: Rotas.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Rotas.cadastro,
        name: 'cadastro',
        builder: (context, state) => const CadastroScreen(),
      ),
    ],
  );
});
