import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_service.dart';
import '../../features/auth/cadastro_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/catalogo/catalogo_screen.dart';
import '../../features/catalogo/criar_exercicio_screen.dart';
import '../../features/fichas/fichas_screen.dart';
import '../../features/auth/perfil_screen.dart';
import '../../features/inicio/inicio_screen.dart';
import '../../features/progresso/progresso_screen.dart';
import '../../features/sessao/detalhe_sessao_screen.dart';
import '../../features/sessao/registrar_sessao_screen.dart';
import '../../features/sessao/resumo_treino_screen.dart';
import '../../features/sessao/treino_ao_vivo_screen.dart';
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
  static const registrarSessao = '/fichas/registrar';
  static const treinoLivre = '/fichas/treino-livre';

  /// Treino ao vivo (TV-3, Release 2), empilhado sobre a aba Fichas.
  static const treinoAoVivo = '/fichas/ao-vivo';

  /// Tela de um exercício no treino ao vivo (TV-4), série por série.
  static const exercicioAoVivo = '/fichas/ao-vivo/exercicio';

  /// Resumo do treino ao vivo antes de salvar (TV-6).
  static const resumoTreino = '/fichas/ao-vivo/resumo';
  static const detalheSessao = '/sessoes';
  static const perfil = '/perfil';
  static const primeiroAcesso = '/primeiro-acesso';
}

/// Dados passados ao abrir o registro de sessão (via `extra`).
class RegistrarSessaoArgs {
  const RegistrarSessaoArgs({
    required this.treinoId,
    required this.treinoNome,
    this.data,
    this.registroPosterior = false,
  });
  final String treinoId;
  final String treinoNome;

  /// Dia pré-selecionado (faixa semanal da tela inicial). Nulo = hoje.
  final DateTime? data;

  /// "Registrar treino já feito" (PBI-37): data editável, duração digitada, sem
  /// treino em andamento. Falso = iniciar treino agora (em andamento).
  final bool registroPosterior;
}

/// Dados passados ao abrir o detalhe de uma sessão (via `extra`).
class DetalheSessaoArgs {
  const DetalheSessaoArgs({required this.sessaoId, this.treinoNome});
  final String sessaoId;
  final String? treinoNome;
}

/// Navigator raiz: as telas do treino ao vivo são empilhadas nele (e não no
/// navigator da aba Fichas) para ocupar a tela toda, sem a barra inferior,
/// como nos protótipos 14 a 16.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'raiz');

/// go_router com casca de navegação inferior (Início/Fichas/Progresso) e
/// redirecionamento por estado de autenticação.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, __) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
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
                  // Detalhe de uma sessão registrada (PBI-18).
                  GoRoute(
                    path: 'sessoes',
                    name: 'detalheSessao',
                    builder: (context, state) {
                      final args = state.extra as DetalheSessaoArgs?;
                      return DetalheSessaoScreen(
                        sessaoId: args?.sessaoId ?? '',
                        treinoNome: args?.treinoNome,
                      );
                    },
                  ),
                  // Perfil e conta (PBI-25), empilhado sobre a Início.
                  GoRoute(
                    path: 'perfil',
                    name: 'perfil',
                    builder: (context, state) => const PerfilScreen(),
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
                // `?ficha=<id>` (PBI-50): abre a ficha selecionada vinda do
                // cartão da Início, sem iniciar treino. Id inexistente cai na
                // primeira ficha (tratado na FichasScreen).
                builder: (context, state) => FichasScreen(
                  fichaInicialId: state.uri.queryParameters['ficha'],
                ),
                routes: [
                  // Registro de sessão empilhado sobre a aba Fichas.
                  GoRoute(
                    path: 'registrar',
                    name: 'registrarSessao',
                    builder: (context, state) {
                      final args = state.extra as RegistrarSessaoArgs?;
                      return RegistrarSessaoScreen(
                        treinoId: args?.treinoId ?? '',
                        treinoNome: args?.treinoNome ?? 'treino',
                        dataInicial: args?.data,
                        registroPosterior: args?.registroPosterior ?? false,
                      );
                    },
                  ),
                  // Treino livre (PBI-19), empilhado sobre a aba Fichas.
                  GoRoute(
                    path: 'treino-livre',
                    name: 'treinoLivre',
                    builder: (context, state) => const TreinoLivreScreen(),
                  ),
                  // Treino ao vivo (TV-3), empilhado sobre a aba Fichas.
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'ao-vivo',
                    name: 'treinoAoVivo',
                    builder: (context, state) => const TreinoAoVivoScreen(),
                    routes: [
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
                        path: 'exercicio',
                        name: 'exercicioAoVivo',
                        builder: (context, state) => ExercicioAoVivoScreen(
                          indice: (state.extra as int?) ?? 0,
                        ),
                      ),
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
                        path: 'resumo',
                        name: 'resumoTreino',
                        builder: (context, state) => const ResumoTreinoScreen(),
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
