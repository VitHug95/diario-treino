import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relógio fixo para o teste não depender do tempo real.
class _RelogioFixo implements Relogio {
  _RelogioFixo(this._agora);
  final DateTime _agora;
  @override
  DateTime agora() => _agora;
}

SerieEdicao _serie({bool feita = false}) => SerieEdicao(
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
      descansoTexto: '90',
      feita: feita,
    );

ExercicioEdicao _exercicio({int series = 2}) => ExercicioEdicao(
      treinoExercicioId: 'te1',
      exercicioId: 'ex1',
      nome: 'Supino reto',
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: false,
      series: [for (var i = 0; i < series; i++) _serie()],
    );

Future<ProviderContainer> _container(DateTime agora) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(agora)),
  ]);
}

void main() {
  test('iniciar grava o estado e persiste o rascunho', () async {
    final c = await _container(DateTime(2026, 10, 15, 19, 4));
    final ctrl = c.read(treinoAoVivoControllerProvider.notifier);

    ctrl.iniciar(
      treinoId: 'A',
      treinoNome: 'Treino A',
      treinoLivre: false,
      data: DateTime(2026, 10, 15),
      exercicios: [_exercicio()],
    );

    final estado = c.read(treinoAoVivoControllerProvider)!;
    expect(estado.treinoNome, 'Treino A');
    expect(estado.inicio, DateTime(2026, 10, 15, 19, 4));
    expect(estado.totalSeries, 2);
    expect(estado.seriesFeitas, 0);

    // Autosave: o rascunho foi gravado e pode ser retomado.
    expect(c.read(rascunhoTreinoServiceProvider).carregar(), isNotNull);
  });

  test('completar série atualiza o contador e marca o exercício realizado', () async {
    final c = await _container(DateTime(2026, 10, 15, 19, 4));
    final ctrl = c.read(treinoAoVivoControllerProvider.notifier);
    final ex = _exercicio();
    ctrl.iniciar(
      treinoId: 'A', treinoNome: 'A', treinoLivre: false,
      data: DateTime(2026, 10, 15), exercicios: [ex],
    );

    ctrl.definirSerieFeita(ex, ex.series.first, true);

    final estado = c.read(treinoAoVivoControllerProvider)!;
    expect(estado.seriesFeitas, 1);
    expect(estado.exerciciosConcluidos, 0); // ainda falta a 2ª série
    expect(ex.realizado, isTrue);

    ctrl.definirSerieFeita(ex, ex.series[1], true);
    expect(c.read(treinoAoVivoControllerProvider)!.exerciciosConcluidos, 1);
  });

  test('retomar do rascunho reabre o estado salvo', () async {
    final c = await _container(DateTime(2026, 10, 15, 20, 0));
    // Simula um rascunho salvo por uma sessão anterior.
    await c.read(rascunhoTreinoServiceProvider).salvar(TreinoEmAndamento(
          treinoId: 'B',
          treinoNome: 'Treino B',
          treinoLivre: false,
          dataIso: '2026-10-15',
          inicioMillis: DateTime(2026, 10, 15, 19, 0).millisecondsSinceEpoch,
          exercicios: [exercicioParaRascunho(_exercicio()..series.first.feita = true)],
        ));

    final ctrl = c.read(treinoAoVivoControllerProvider.notifier);
    final retomou = ctrl.retomarDoRascunho();

    expect(retomou, isTrue);
    final estado = c.read(treinoAoVivoControllerProvider)!;
    expect(estado.treinoNome, 'Treino B');
    expect(estado.inicio, DateTime(2026, 10, 15, 19, 0));
    expect(estado.seriesFeitas, 1); // o check sobrevive ao round-trip
  });

  test('encerrar apaga o rascunho e zera o estado', () async {
    final c = await _container(DateTime(2026, 10, 15, 19, 4));
    final ctrl = c.read(treinoAoVivoControllerProvider.notifier);
    ctrl.iniciar(
      treinoId: 'A', treinoNome: 'A', treinoLivre: false,
      data: DateTime(2026, 10, 15), exercicios: [_exercicio()],
    );
    expect(c.read(rascunhoTreinoServiceProvider).carregar(), isNotNull);

    ctrl.encerrar();

    expect(c.read(treinoAoVivoControllerProvider), isNull);
    expect(c.read(rascunhoTreinoServiceProvider).carregar(), isNull);
  });
}
