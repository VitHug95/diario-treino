import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/iniciar_treino_ao_vivo.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RelogioFixo implements Relogio {
  _RelogioFixo(this.valor);
  final DateTime valor;
  @override
  DateTime agora() => valor;
}

SerieEdicao _serie() => SerieEdicao(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      intensidadeTexto: '30',
      volumeMetricaId: 10,
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      volumeTexto: '10',
      descansoTexto: '',
    );

ExercicioEdicao _ex() => ExercicioEdicao(
      treinoExercicioId: 'te1',
      exercicioId: 'ex1',
      nome: 'Supino',
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: false,
      series: [_serie()],
    );

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// Router mínimo: uma tela com um botão que chama retomarTreinoAoVivo e a tela
/// alvo /fichas/ao-vivo, para checar a navegação de verdade.
GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => retomarTreinoAoVivo(context, ref),
                child: const Text('retomar'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/fichas/ao-vivo',
          builder: (context, state) =>
              const Scaffold(body: Text('TELA AO VIVO')),
        ),
      ],
    );

void main() {
  testWidgets('retomarTreinoAoVivo abre a tela 14 quando há rascunho salvo',
      (tester) async {
    final prefs = await _prefs();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15))),
    ]);
    addTearDown(container.dispose);

    // Simula um treino em andamento salvo no aparelho.
    await container.read(rascunhoTreinoServiceProvider).salvar(
          TreinoEmAndamento(
            treinoId: 'A',
            treinoNome: 'Treino A',
            treinoLivre: false,
            dataIso: '2026-10-15',
            inicioMillis: DateTime(2026, 10, 15, 19, 0).millisecondsSinceEpoch,
            exercicios: [exercicioParaRascunho(_ex())],
          ),
        );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router()),
    ));

    await tester.tap(find.text('retomar'));
    await tester.pumpAndSettle();

    // Navegou para a tela ao vivo e o controller carregou o estado.
    expect(find.text('TELA AO VIVO'), findsOneWidget);
    expect(container.read(treinoAoVivoControllerProvider), isNotNull);
  });

  testWidgets('retomarTreinoAoVivo não navega quando não há rascunho',
      (tester) async {
    final prefs = await _prefs();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15))),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: _router()),
    ));

    await tester.tap(find.text('retomar'));
    await tester.pumpAndSettle();

    // Continua na tela inicial; nada foi iniciado.
    expect(find.text('TELA AO VIVO'), findsNothing);
    expect(container.read(treinoAoVivoControllerProvider), isNull);
  });
}
