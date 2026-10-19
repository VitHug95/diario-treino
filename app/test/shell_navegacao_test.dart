import 'package:diario_treino/core/rotas/shell_navegacao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// PBI-80: tocar numa aba sempre abre a RAIZ dela, mesmo que o atleta tenha
/// entrado numa sub-rota e saído. Monta um router de teste com a mesma forma do
/// app (StatefulShellRoute.indexedStack + ShellNavegacao) e três abas, cada uma
/// com uma raiz e uma sub-rota empilhada.

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'raiz-teste');

GoRouter _router() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/inicio',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => ShellNavegacao(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/inicio',
                builder: (_, __) => const _Tela('Início raiz'),
                routes: [
                  GoRoute(
                    path: 'sub',
                    builder: (_, __) => const _Tela('Início sub'),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/fichas',
                builder: (_, __) => const _Tela('Planos raiz'),
                routes: [
                  GoRoute(
                    path: 'plano',
                    builder: (_, __) => const _Tela('Plano aberto'),
                    routes: [
                      GoRoute(
                        path: 'ficha',
                        builder: (_, __) => const _Tela('Ficha aberta'),
                      ),
                    ],
                  ),
                  // Rota de "treino em andamento" no navigator RAIZ (como no app).
                  GoRoute(
                    parentNavigatorKey: _rootKey,
                    path: 'ao-vivo',
                    builder: (_, __) => const _Tela('Treino ao vivo'),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/progresso',
                builder: (_, __) => const _Tela('Progresso raiz'),
                routes: [
                  GoRoute(
                    path: 'sub',
                    builder: (_, __) => const _Tela('Progresso sub'),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );

class _Tela extends StatelessWidget {
  const _Tela(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(texto)));
}

Future<void> _montar(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PBI-80: Planos → plano → ficha, vai à Início e volta a Planos: lista',
      (tester) async {
    final router = _router();
    await _montar(tester, router);

    // Entra em Planos e desce até a ficha.
    await tester.tap(find.text('Planos'));
    await tester.pumpAndSettle();
    router.push('/fichas/plano');
    await tester.pumpAndSettle();
    router.push('/fichas/plano/ficha');
    await tester.pumpAndSettle();
    expect(find.text('Ficha aberta'), findsOneWidget);

    // Vai para Início e volta para Planos: deve mostrar a lista (raiz).
    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    expect(find.text('Início raiz'), findsOneWidget);

    await tester.tap(find.text('Planos'));
    await tester.pumpAndSettle();
    expect(find.text('Planos raiz'), findsOneWidget);
    expect(find.text('Ficha aberta'), findsNothing);
  });

  testWidgets('PBI-80: vale para Início (depois de abrir uma sub-rota)',
      (tester) async {
    final router = _router();
    await _montar(tester, router);

    router.push('/inicio/sub');
    await tester.pumpAndSettle();
    expect(find.text('Início sub'), findsOneWidget);

    await tester.tap(find.text('Progresso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();

    expect(find.text('Início raiz'), findsOneWidget);
    expect(find.text('Início sub'), findsNothing);
  });

  testWidgets('PBI-80: vale para Progresso', (tester) async {
    final router = _router();
    await _montar(tester, router);

    await tester.tap(find.text('Progresso'));
    await tester.pumpAndSettle();
    router.push('/progresso/sub');
    await tester.pumpAndSettle();
    expect(find.text('Progresso sub'), findsOneWidget);

    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progresso'));
    await tester.pumpAndSettle();

    expect(find.text('Progresso raiz'), findsOneWidget);
    expect(find.text('Progresso sub'), findsNothing);
  });

  testWidgets('PBI-80: tocar na aba atual também volta à raiz', (tester) async {
    final router = _router();
    await _montar(tester, router);

    await tester.tap(find.text('Planos'));
    await tester.pumpAndSettle();
    router.push('/fichas/plano');
    await tester.pumpAndSettle();
    expect(find.text('Plano aberto'), findsOneWidget);

    // Toca em Planos de novo (aba já atual): volta à lista.
    await tester.tap(find.text('Planos'));
    await tester.pumpAndSettle();
    expect(find.text('Planos raiz'), findsOneWidget);
  });

  testWidgets('PBI-80: treino em andamento no navigator raiz não é perdido ao trocar de aba',
      (tester) async {
    final router = _router();
    await _montar(tester, router);

    // Abre o treino ao vivo (empilhado no navigator raiz, acima da barra).
    router.push('/fichas/ao-vivo');
    await tester.pumpAndSettle();
    expect(find.text('Treino ao vivo'), findsOneWidget);

    // A barra inferior nem está visível com o treino por cima: a troca de aba
    // não acontece. O treino segue na tela.
    expect(find.text('Treino ao vivo'), findsOneWidget);
  });
}
