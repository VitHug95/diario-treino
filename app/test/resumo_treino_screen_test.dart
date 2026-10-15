import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/resumo_treino_screen.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RelogioFixo implements Relogio {
  _RelogioFixo(this.valor);
  final DateTime valor;
  @override
  DateTime agora() => valor;
}

SerieEdicao _serie({required bool feita, String carga = '30', String reps = '10'}) =>
    SerieEdicao(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      intensidadeTexto: carga,
      volumeMetricaId: 10,
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      volumeTexto: reps,
      descansoTexto: '',
      feita: feita,
    );

ExercicioEdicao _ex(String nome, List<SerieEdicao> series) => ExercicioEdicao(
      treinoExercicioId: 'te-$nome',
      exercicioId: 'ex-$nome',
      nome: nome,
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: series.any((s) => s.feita),
      series: series,
    );

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15, 20, 0))),
  ]);
}

void main() {
  testWidgets('status por exercício e volume total (TV-6)', (tester) async {
    final c = await _container();
    c.read(treinoAoVivoControllerProvider.notifier).iniciar(
      treinoId: 'A',
      treinoNome: 'Treino A',
      treinoLivre: false,
      data: DateTime(2026, 10, 15),
      inicio: DateTime(2026, 10, 15, 19, 0),
      exercicios: [
        // Completo: 2 séries feitas (2×30×10 = 600).
        _ex('Supino', [_serie(feita: true), _serie(feita: true)]),
        // Incompleto: 1 de 2 (mais 30×10 = 300 → volume 900 no total).
        _ex('Remada', [_serie(feita: true), _serie(feita: false)]),
        // Não realizado: nenhuma feita.
        _ex('Agachamento', [_serie(feita: false)]),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.claro, home: const ResumoTreinoScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Treino A'), findsOneWidget);
    expect(find.text('Completo'), findsOneWidget);
    expect(find.text('Incompleto 1/2'), findsOneWidget);
    // Volume: 600 (Supino) + 300 (Remada feita) = 900 kg.
    expect(find.text('900 kg'), findsOneWidget);
    // Ações da tela.
    expect(find.text('SALVAR TREINO'), findsOneWidget);
    expect(find.text('Voltar ao treino'), findsOneWidget);

    // Agachamento fica abaixo da dobra: rola até ele aparecer.
    await tester.scrollUntilVisible(find.text('Não realizado'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Não realizado'), findsOneWidget);

    c.dispose();
  });

  testWidgets('sem séries feitas, salvar avisa e não encerra o treino',
      (tester) async {
    final c = await _container();
    c.read(treinoAoVivoControllerProvider.notifier).iniciar(
      treinoId: 'A',
      treinoNome: 'Treino A',
      treinoLivre: false,
      data: DateTime(2026, 10, 15),
      inicio: DateTime(2026, 10, 15, 19, 0),
      exercicios: [_ex('Supino', [_serie(feita: false)])],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.claro, home: const ResumoTreinoScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pump();

    expect(find.textContaining('Marque ao menos uma série'), findsOneWidget);
    // O treino continua em andamento (não encerrou).
    expect(c.read(treinoAoVivoControllerProvider), isNotNull);

    c.dispose();
  });
}
