import 'package:diario_treino/features/progresso/progresso_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SessaoResumo _sessao({
  required String id,
  required DateTime data,
  String? treinoNome,
  int exercicios = 2,
  int? duracao,
  bool obs = false,
}) =>
    SessaoResumo(
      id: id,
      data: data,
      treinoId: treinoNome == null ? null : 't-$id',
      treinoNome: treinoNome,
      quantidadeExercicios: exercicios,
      duracaoMin: duracao,
      temObservacao: obs,
    );

Widget _tela(List<SessaoResumo> sessoes) => ProviderScope(
      overrides: [
        sessoesDoPeriodoProvider.overrideWith((ref) async => sessoes),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: const ProgressoScreen()),
    );

void main() {
  testWidgets('Lista sessões com ficha, detalhes e selo Obs', (tester) async {
    await tester.pumpWidget(_tela([
      _sessao(
        id: '1',
        data: DateTime(2026, 10, 13),
        treinoNome: 'A',
        exercicios: 3,
        duracao: 45,
        obs: true,
      ),
      _sessao(
        id: '2',
        data: DateTime(2026, 10, 11),
        treinoNome: 'B',
        exercicios: 2,
      ),
    ]));
    await tester.pumpAndSettle();

    // Ficha e detalhes.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('3 exercícios · 45 min'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('2 exercícios'), findsOneWidget);
    // Selo de observação só na que tem obs.
    expect(find.text('Obs.'), findsOneWidget);
  });

  testWidgets('Sessão sem ficha aparece como Treino livre', (tester) async {
    await tester.pumpWidget(_tela([
      _sessao(id: '1', data: DateTime(2026, 10, 13), exercicios: 1),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Treino livre'), findsOneWidget);
    expect(find.text('1 exercício'), findsOneWidget);
  });

  testWidgets('Período sem sessões mostra estado vazio', (tester) async {
    await tester.pumpWidget(_tela(const []));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum treino neste período'), findsOneWidget);
  });

  testWidgets('Mostra o seletor de período (15/30/90 dias)', (tester) async {
    await tester.pumpWidget(_tela(const []));
    await tester.pumpAndSettle();

    expect(find.text('15 dias'), findsOneWidget);
    expect(find.text('30 dias'), findsOneWidget);
    expect(find.text('90 dias'), findsOneWidget);
  });
}
