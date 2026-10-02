import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inicio/inicio_screen.dart';

/// Nomes de rota centralizados, para navegação sem strings mágicas.
abstract final class Rotas {
  const Rotas._();

  static const inicio = '/';
}

/// Configuração do go_router. As demais rotas (login, fichas, sessão,
/// progresso) entram nas PBIs das respectivas features.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Rotas.inicio,
    routes: [
      GoRoute(
        path: Rotas.inicio,
        name: 'inicio',
        builder: (context, state) => const InicioScreen(),
      ),
    ],
  );
});
