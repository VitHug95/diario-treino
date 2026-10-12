import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/inicio/inicio_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TreinoResumo _ficha(String nome, int ordem, {String? descricao}) =>
    TreinoResumo(id: nome, nome: nome, descricao: descricao, ordem: ordem);

Future<Widget> _tela(PlanoAtivo? plano) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      planoAtivoProvider.overrideWith((ref) async => plano),
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
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          planoAtivoProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          darkTheme: AppTheme.escuro,
          home: const InicioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sem usuário, o nome cai no padrão "Atleta".
    expect(find.text('BORA, ATLETA'), findsOneWidget);

    // Alterna o tema pelo botão e confirma que persistiu.
    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();

    expect(prefs.getString('tema_modo'), 'escuro');
  });

  testWidgets('Sem fichas, convida a montar', (tester) async {
    await tester.pumpWidget(await _tela(null));
    await tester.pumpAndSettle();

    expect(find.text('Monte suas fichas'), findsOneWidget);
    expect(find.text('MONTAR FICHAS'), findsOneWidget);
  });

  testWidgets('Com fichas, lista na ordem e destaca a primeira',
      (tester) async {
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

    // Destaque "comece por aqui" com a primeira da ordem (A).
    expect(find.text('COMECE POR AQUI'), findsOneWidget);
    expect(find.text('A · Peito'), findsOneWidget);

    // A seção de fichas lista as duas, e há botão de registrar.
    expect(find.text('SUAS FICHAS'), findsOneWidget);
    expect(find.text('REGISTRAR TREINO'), findsOneWidget);
    // As duas fichas aparecem como cartões (nome em título).
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
