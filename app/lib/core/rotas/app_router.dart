import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_service.dart';
import '../../features/auth/cadastro_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/catalogo/catalogo_screen.dart';
import '../../features/catalogo/criar_exercicio_screen.dart';
import '../../features/educador/aluno_detalhe_screen.dart';
import '../../features/educador/alunos_screen.dart';
import '../../features/educador/convites_screen.dart';
import '../../features/fichas/fichas_screen.dart';
import '../../features/auth/perfil_screen.dart';
import '../../features/inicio/calendario_mes_screen.dart';
import '../../features/inicio/inicio_screen.dart';
import '../../features/planos/plano_detalhe_screen.dart';
import '../../features/planos/planos_screen.dart';
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

  /// Raiz da aba Planos: a lista de planos (PBI-45). O caminho continua
  /// `/fichas` para não mexer nas rotas de registro e treino ao vivo.
  static const fichas = '/fichas';

  /// Detalhe de um plano, tela 19 (`?id=<plano>`; sem id = plano em uso).
  static const planoDetalhe = '/fichas/plano';

  /// Uma ficha do plano, tela 13 (`?plano=<id>&ficha=<id>`; sem plano = em
  /// uso). Empilhada sobre o detalhe: a seta volta ao plano de origem.
  static const fichaDoPlano = '/fichas/plano/ficha';
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

  /// Modo educador (PBI-88), empilhados sobre a Início a partir do Perfil.
  static const alunos = '/perfil/alunos';
  static const alunoDetalhe = '/perfil/alunos/aluno';
  static const convites = '/perfil/convites';

  /// Calendário do mês (PBI-82), empilhado sobre a aba Início.
  static const mes = '/mes';
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
                    routes: [
                      // Modo educador (PBI-88), empilhados sobre o Perfil.
                      GoRoute(
                        path: 'alunos',
                        name: 'alunos',
                        builder: (context, state) => const AlunosScreen(),
                        routes: [
                          // Detalhe de um aluno (PBI-88c): evolução + sessões.
                          GoRoute(
                            path: 'aluno',
                            name: 'alunoDetalhe',
                            builder: (context, state) {
                              final args = state.extra as AlunoDetalheArgs?;
                              return AlunoDetalheScreen(
                                key: ValueKey('aluno:${args?.atletaId}'),
                                atletaId: args?.atletaId ?? '',
                                alunoNome: args?.alunoNome ?? 'Aluno',
                              );
                            },
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'convites',
                        name: 'convites',
                        builder: (context, state) => const ConvitesScreen(),
                      ),
                    ],
                  ),
                  // Calendário do mês (PBI-82), empilhado sobre a Início.
                  GoRoute(
                    path: 'mes',
                    name: 'mes',
                    builder: (context, state) => const CalendarioMesScreen(),
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
                // Lista de planos (PBI-45, tela 18).
                builder: (context, state) => const PlanosScreen(),
                routes: [
                  // Detalhe do plano (PBI-46, tela 19). `?id=` escolhe o
                  // plano; sem id, o plano em uso.
                  GoRoute(
                    path: 'plano',
                    name: 'planoDetalhe',
                    builder: (context, state) {
                      final id = state.uri.queryParameters['id'];
                      return PlanoDetalheScreen(
                        key: ValueKey('plano:$id'),
                        planoId: id,
                      );
                    },
                    routes: [
                      // Uma ficha do plano (tela 22, PBI-57): só edição da
                      // ficha `?ficha=<id>`, sem iniciar treino. A chave
                      // recria a tela quando o plano ou a ficha mudam.
                      GoRoute(
                        path: 'ficha',
                        name: 'fichaDoPlano',
                        builder: (context, state) {
                          final plano = state.uri.queryParameters['plano'];
                          final ficha = state.uri.queryParameters['ficha'];
                          return FichasScreen(
                            key: ValueKey('plano:$plano|ficha:$ficha'),
                            planoId: plano,
                            fichaInicialId: ficha,
                          );
                        },
                      ),
                    ],
                  ),
                  // Registro de sessão em TELA CHEIA (PBI-55): empilha no
                  // navigator raiz, sem a barra de abas, para o "FINALIZAR
                  // TREINO" não competir com a navegação inferior. Igual às
                  // rotas do treino ao vivo.
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
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
                  // Treino livre (PBI-19) em tela cheia (PBI-55), no navigator
                  // raiz, sem a barra de abas.
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'treino-livre',
                    name: 'treinoLivre',
                    // `extra`: dia escolhido na folha do dia (PBI-59).
                    builder: (context, state) => TreinoLivreScreen(
                        dataInicial: state.extra is DateTime
                            ? state.extra! as DateTime
                            : null),
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
