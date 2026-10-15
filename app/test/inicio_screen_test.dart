import 'dart:async';

import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/inicio/inicio_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

TreinoResumo _ficha(String nome, int ordem, {String? descricao}) =>
    TreinoResumo(id: nome, nome: nome, descricao: descricao, ordem: ordem);

Future<Widget> _tela(
  PlanoAtivo? plano, {
  List<SessaoResumo> sessoes = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      planoAtivoProvider.overrideWith((ref) async => plano),
      sessoesRecentesProvider.overrideWith((ref) async => sessoes),
    ],
    child: MaterialApp(
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      home: const InicioScreen(),
    ),
  );
}

void main() {
  testWidgets('Saúda o atleta e alterna o tema', (tester) async {
    // Com ao menos uma ficha, fica na tela inicial (não cai no primeiro acesso).
    final plano = PlanoAtivo(
      id: 'p1',
      nome: 'Plano',
      treinos: [_ficha('A', 1, descricao: 'Peito')],
    );
    await tester.pumpWidget(await _tela(plano));
    await tester.pumpAndSettle();

    expect(find.text('BORA, ATLETA'), findsOneWidget);

    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tema_modo'), 'escuro');
  });

  testWidgets('Primeiro acesso: sem ficha e sem sessão mostra a tela 6 (PBI-09)',
      (tester) async {
    await tester.pumpWidget(await _tela(null));
    await tester.pumpAndSettle();

    // Tela de boas-vindas com os dois caminhos.
    expect(find.text('Seu diário de treino'), findsOneWidget);
    expect(find.text('MONTAR MINHAS FICHAS'), findsOneWidget);
    expect(find.text('Registrar sem ficha'), findsOneWidget);
  });

  testWidgets('Com sessão mas sem ficha, mostra a inicial (não o primeiro acesso)',
      (tester) async {
    // Já treinou (treino livre), então o primeiro acesso não aparece mais.
    final sessoes = [
      SessaoResumo(
        id: 's1',
        data: DateTime.now().subtract(const Duration(days: 1)),
        treinoId: null,
        treinoNome: null,
        quantidadeExercicios: 2,
        duracaoMin: 30,
        temObservacao: false,
      ),
    ];
    await tester.pumpWidget(await _tela(null, sessoes: sessoes));
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsNothing);
    expect(find.text('Monte suas fichas'), findsOneWidget);
  });

  testWidgets('Sem histórico, sugere a primeira ficha da ordem', (tester) async {
    final plano = PlanoAtivo(
      id: 'p1',
      nome: 'Plano',
      treinos: [
        _ficha('B', 2, descricao: 'Costas'),
        _ficha('A', 1, descricao: 'Peito'),
      ],
    );

    await tester.pumpWidget(await _tela(plano));
    await tester.pumpAndSettle();

    // Cartão de sugestão com a primeira da ordem (A), e texto de recomendação.
    expect(find.text('SUGESTÃO DE HOJE'), findsOneWidget);
    expect(find.text('A · Peito'), findsOneWidget);
    expect(find.text('SUAS FICHAS'), findsOneWidget);
    // PBI-50: o botão do cartão de sugestão agora diz o que faz.
    expect(find.text('INICIAR TREINO'), findsOneWidget);
    // Fichas nunca registradas mostram o aviso.
    expect(find.text('Ainda não registrada'), findsNWidgets(2));
  });

  testWidgets(
      'PBI-50: tocar no cartão de ficha abre Fichas sem iniciar treino',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final plano = PlanoAtivo(
      id: 'p1',
      nome: 'Plano',
      treinos: [
        _ficha('A', 1, descricao: 'Peito'),
        _ficha('B', 2, descricao: 'Costas'),
      ],
    );
    // Já há histórico (sessão do A) para a Início montar o estado completo com
    // os cartões de ficha e sem cair no primeiro acesso.
    final sessoes = [
      SessaoResumo(
        id: 's1',
        data: DateTime.now().subtract(const Duration(days: 1)),
        treinoId: 'A',
        treinoNome: 'A',
        quantidadeExercicios: 3,
        duracaoMin: 45,
        temObservacao: false,
      ),
    ];

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const InicioScreen()),
        GoRoute(
          path: '/fichas',
          builder: (_, state) => Scaffold(
            body: Text('FICHAS ficha=${state.uri.queryParameters['ficha']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          planoAtivoProvider.overrideWith((ref) async => plano),
          sessoesRecentesProvider.overrideWith((ref) async => sessoes),
        ],
        child: MaterialApp.router(
          theme: AppTheme.claro,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Confirma o rótulo de acessibilidade PBI-50 do cartão da ficha B.
    final semB = find.bySemanticsLabel(RegExp(r'^Abrir ficha B,'));
    expect(semB, findsOneWidget);

    // Toca no InkWell do cartão (alvo real do gesto). Garante que está visível
    // — a lista pode rolar no tamanho de teste.
    final inkB = find.descendant(of: semB, matching: find.byType(InkWell));
    await tester.ensureVisible(inkB);
    await tester.pumpAndSettle();
    await tester.tap(inkB);
    await tester.pumpAndSettle();

    // Navegou para Fichas com o id da ficha; nenhum treino foi iniciado
    // (não há como gravar rascunho sem passar pela ação explícita).
    expect(find.text('FICHAS ficha=B'), findsOneWidget);
  });

  testWidgets('Com histórico, sugere a próxima da sequência', (tester) async {
    final plano = PlanoAtivo(
      id: 'p1',
      nome: 'Plano',
      treinos: [
        _ficha('A', 1, descricao: 'Peito'),
        _ficha('B', 2, descricao: 'Costas'),
      ],
    );
    // Última sessão foi do A → sugere o B.
    final sessoes = [
      SessaoResumo(
        id: 's1',
        data: DateTime.now().subtract(const Duration(days: 1)),
        treinoId: 'A',
        treinoNome: 'A',
        quantidadeExercicios: 3,
        duracaoMin: 45,
        temObservacao: false,
      ),
    ];

    await tester.pumpWidget(await _tela(plano, sessoes: sessoes));
    await tester.pumpAndSettle();

    expect(find.text('B · Costas'), findsOneWidget);
  });

  // Regressão do bug PBI-23A: enquanto o histórico ainda não carregou, a tela
  // NÃO pode fabricar uma sugestão (era isso que fazia "sempre Treino A").
  testWidgets('Enquanto o histórico carrega, não mostra sugestão', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final plano = PlanoAtivo(
      id: 'p1',
      nome: 'Plano',
      treinos: [_ficha('A', 1, descricao: 'Peito'), _ficha('B', 2)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          planoAtivoProvider.overrideWith((ref) async => plano),
          // Sessões "penduradas" em loading: nunca completam neste teste.
          sessoesRecentesProvider.overrideWith((ref) => Completer<List<SessaoResumo>>().future),
        ],
        child: MaterialApp(theme: AppTheme.claro, home: const InicioScreen()),
      ),
    );
    // pump (não pumpAndSettle: o future fica pendente de propósito).
    await tester.pump();

    // Fichas aparecem (dá para registrar), mas sem o cartão de sugestão.
    expect(find.text('SUAS FICHAS'), findsOneWidget);
    expect(find.text('SUGESTÃO DE HOJE'), findsNothing);
    expect(find.text('INICIAR TREINO'), findsNothing);
  });

}
