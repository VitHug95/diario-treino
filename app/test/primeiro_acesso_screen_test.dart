import 'package:dio/dio.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/inicio/primeiro_acesso_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Repositório que só cria o plano e guarda o nome pedido.
class _RepoCriaPlano extends FichasRepository {
  _RepoCriaPlano() : super(Dio());
  String? criado;

  @override
  Future<String> criarPlano(String nome) async {
    criado = nome;
    return 'novo';
  }
}

/// Bem-vindo com rotas de verdade: os destinos só mostram o que receberam.
Widget _tela({PlanoAtivo? plano, _RepoCriaPlano? repo, ThemeData? tema}) {
  final router = GoRouter(
    initialLocation: Rotas.inicio,
    routes: [
      GoRoute(
        path: Rotas.inicio,
        builder: (_, __) => Scaffold(body: PrimeiroAcessoScreen(plano: plano)),
      ),
      GoRoute(
        path: Rotas.planoDetalhe,
        builder: (_, s) => Text('Plano ${s.uri.queryParameters['id']}'),
      ),
      GoRoute(
        path: Rotas.treinoLivre,
        builder: (_, __) => const Text('Treino livre'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      if (repo != null) fichasRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(theme: tema ?? AppTheme.claro, routerConfig: router),
  );
}

void main() {
  testWidgets('Conta nova sem plano: "Criar meu plano" e "Registrar treino"',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsOneWidget);
    expect(find.text('CRIAR MEU PLANO'), findsOneWidget);
    expect(find.text('Registrar treino'), findsOneWidget);
    // O nome antigo saiu (Robot: o passo passa a tocar em "Registrar treino").
    expect(find.text('Registrar sem ficha'), findsNothing);
    expect(find.text('MONTAR MINHAS FICHAS'), findsNothing);

    // Os três passos do "como funciona".
    expect(find.text('Monte seu plano'), findsOneWidget);
    expect(find.text('Registre o treino'), findsOneWidget);
    expect(find.text('Acompanhe a evolução'), findsOneWidget);
  });

  testWidgets('PBI-69: "Criar meu plano" pede só o nome e abre o plano criado',
      (tester) async {
    final repo = _RepoCriaPlano();
    await tester.pumpWidget(_tela(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CRIAR MEU PLANO'));
    await tester.pumpAndSettle();
    // Diálogo "Novo plano" com o nome sugerido, sem passar por outra tela.
    expect(find.text('Novo plano'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Meu plano'), findsOneWidget);

    await tester.tap(find.text('CRIAR PLANO'));
    await tester.pumpAndSettle();
    expect(repo.criado, 'Meu plano');
    expect(find.text('Plano novo'), findsOneWidget);
  });

  testWidgets('Plano sem fichas: "Montar a primeira ficha" abre o plano',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: const PlanoAtivo(id: 'p1', nome: 'Meu plano', treinos: []),
      tema: AppTheme.escuro,
    ));
    await tester.pumpAndSettle();

    expect(find.text('CRIAR MEU PLANO'), findsNothing);
    await tester.tap(find.text('MONTAR A PRIMEIRA FICHA'));
    await tester.pumpAndSettle();
    expect(find.text('Plano p1'), findsOneWidget);
  });

  testWidgets('"Registrar treino" abre o treino livre direto (PBI-71)',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar treino'));
    await tester.pumpAndSettle();
    expect(find.text('Treino livre'), findsOneWidget);
  });
}
