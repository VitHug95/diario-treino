import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_service.dart';
import '../../features/auth/cadastro_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/catalogo/catalogo_screen.dart';
import '../../features/catalogo/criar_exercicio_screen.dart';
import '../../features/fichas/fichas_screen.dart';
import '../../features/inicio/inicio_screen.dart';
import '../../features/progresso/progresso_screen.dart';
import 'shell_navegacao.dart';

/// Nomes de rota centralizados, para navegação sem strings mágicas.
abstract final class Rotas {
  const Rotas._();

  static const inicio = '/';
  static const fichas = '/fichas';
  static const progresso = '/progresso';
  static const login = '/login';
  static const cadastro = '/cadastro';
  static const exercicios = '/exercicios';
  static const criarExercicio = '/exercicios/novo';
}

/// go_router com casca de navegação inferior (Início/Fichas/Progresso) e
/// redirecionamento por estado de autenticação.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: Rotas.inicio,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (auth.isLoading) return null;

      final logado = auth.value != null;
      final emTelaDeAuth = state.matchedLocation == Rotas.login ||
          state.matchedLocation == Rotas.cadastro;

      if (!logado && !emTelaDeAuth) return Rotas.login;
      if (logado && emTelaDeAuth) return Rotas.inicio;
      return null;
    },
    routes: [
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

      // Abas principais com navegação inferior.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellNavegacao(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.inicio,
                name: 'inicio',
                builder: (context, state) => const InicioScreen(),
                routes: [
                  // Catálogo e criação são empilhados sobre a aba Início.
                  GoRoute(
                    path: 'exercicios',
                    name: 'exercicios',
                    builder: (context, state) => const CatalogoScreen(),
                    routes: [
                      GoRoute(
                        path: 'novo',
                        name: 'criarExercicio',
                        builder: (context, state) =>
                            const CriarExercicioScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.fichas,
                name: 'fichas',
                builder: (context, state) => const FichasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotas.progresso,
                name: 'progresso',
                builder: (context, state) => const ProgressoScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
