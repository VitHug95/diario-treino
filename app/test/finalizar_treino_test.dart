import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/registrar_sessao_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

RascunhoSessao _rascunho() => RascunhoSessao(
      treinoId: 'A',
      treinoNome: 'Treino A',
      data: DateTime.now(),
      exercicios: const [
        RascunhoExercicio(
          treinoExercicioId: 'te1',
          exercicioId: 'ex1',
          nome: 'Supino reto',
          grupoMuscular: 'peito',
          modalidade: 'FORCA',
          ordem: 1,
          origemPreenchimento: 'Preenchido com os alvos da ficha',
          series: [
            SerieRascunho(
              rodada: 1,
              ordem: 1,
              tipo: 'ESFORCO',
              intensidadeMetricaId: 1,
              intensidadeMetricaCodigo: 'CARGA_KG',
              intensidadeMetricaNome: 'Carga',
              intensidade: 30,
              volumeMetricaId: 10,
              volumeMetricaCodigo: 'REPETICOES',
              volumeMetricaNome: 'Repetições',
              volume: 10,
              descansoSeg: 90,
            ),
          ],
        ),
      ],
    );

Future<Widget> _tela() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      rascunhoSessaoProvider('A').overrideWith((ref) async => _rascunho()),
    ],
    child: MaterialApp(
      theme: AppTheme.claro,
      home: const RegistrarSessaoScreen(treinoId: 'A', treinoNome: 'Treino A'),
    ),
  );
}

void main() {
  testWidgets('Exercício começa desmarcado, com a série como sugestão (PBI-37)',
      (tester) async {
    await tester.pumpWidget(await _tela());
    await tester.pumpAndSettle();

    // Não vem "Realizado"; vem o convite para marcar e a sugestão.
    expect(find.text('Marcar como feito'), findsOneWidget);
    expect(find.textContaining('Sugestão:'), findsOneWidget);
    // Botão de finalizar (não "salvar").
    expect(find.text('FINALIZAR TREINO'), findsOneWidget);
  });

  testWidgets('Finalizar com exercício sem marcar mostra o aviso (PBI-37)',
      (tester) async {
    await tester.pumpWidget(await _tela());
    await tester.pumpAndSettle();

    await tester.tap(find.text('FINALIZAR TREINO'));
    await tester.pumpAndSettle();

    // Aviso de exercício não marcado.
    expect(find.text('Finalizar treino?'), findsOneWidget);
    expect(find.textContaining('sem marcar'), findsOneWidget);
  });

  testWidgets('Tocar na sugestão marca como feito e abre os campos (PBI-37)',
      (tester) async {
    await tester.pumpWidget(await _tela());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marcar'));
    await tester.pumpAndSettle();

    // Passa a mostrar "Realizado" e os campos de série ficam editáveis.
    expect(find.text('Realizado'), findsOneWidget);
    expect(find.text('Adicionar série'), findsOneWidget);
  });
}
