import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:flutter_test/flutter_test.dart';

RascunhoExercicio _exercicioComAlvos() => RascunhoExercicio(
      treinoExercicioId: 'te1',
      exercicioId: 'e1',
      nome: 'Supino reto',
      grupoMuscular: 'peito',
      modalidade: 'FORCA',
      ordem: 1,
      origemPreenchimento: 'Preenchido com os alvos da ficha',
      series: const [
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
    );

void main() {
  group('RascunhoSessao.doJson', () {
    test('converte o JSON da API com séries e origem', () {
      final json = {
        'treinoId': 't1',
        'treinoNome': 'A',
        'data': '2026-10-02',
        'exercicios': [
          {
            'treinoExercicioId': 'te1',
            'exercicioId': 'e1',
            'nome': 'Prancha',
            'grupoMuscular': 'core',
            'modalidade': 'ISOMETRIA',
            'ordem': 1,
            'origemPreenchimento': 'Preenchido com o último treino (27/09)',
            'series': [
              {
                'rodada': 1,
                'ordem': 1,
                'tipo': 'ESFORCO',
                'intensidadeMetricaId': 2,
                'intensidadeMetricaCodigo': 'PESO_CORPORAL',
                'intensidadeMetricaNome': 'Peso corporal',
                'intensidade': null,
                'volumeMetricaId': 11,
                'volumeMetricaCodigo': 'TEMPO_SEG',
                'volumeMetricaNome': 'Tempo',
                'volume': 45,
                'descansoSeg': null,
              },
            ],
          },
        ],
      };

      final r = RascunhoSessao.doJson(json);
      expect(r.treinoNome, 'A');
      expect(r.data, DateTime(2026, 10, 2));
      final ex = r.exercicios.single;
      expect(ex.origemPreenchimento, 'Preenchido com o último treino (27/09)');
      final s = ex.series.single;
      expect(s.intensidadePorPesoCorporal, isTrue);
      expect(s.intensidade, isNull);
      expect(s.volume, 45);
    });
  });

  group('ExercicioEdicao.doRascunho', () {
    test('começa realizado quando há séries sugeridas', () {
      final ed = ExercicioEdicao.doRascunho(_exercicioComAlvos());
      expect(ed.realizado, isTrue);
      expect(ed.series, hasLength(1));
      expect(ed.series.first.intensidadeTexto, '30');
      expect(ed.series.first.volumeTexto, '10');
      expect(ed.series.first.descansoTexto, '90');
    });

    test('começa não realizado quando não há séries', () {
      final semSeries = RascunhoExercicio(
        treinoExercicioId: 'te2',
        exercicioId: 'e2',
        nome: 'Novo exercício',
        grupoMuscular: null,
        modalidade: 'FORCA',
        ordem: 2,
        origemPreenchimento: null,
        series: const [],
      );
      final ed = ExercicioEdicao.doRascunho(semSeries);
      expect(ed.realizado, isFalse);
      expect(ed.series, isEmpty);
    });

    test('formata valor decimal com vírgula', () {
      final comDecimal = RascunhoExercicio(
        treinoExercicioId: 'te3',
        exercicioId: 'e3',
        nome: 'Agachamento',
        grupoMuscular: 'pernas',
        modalidade: 'FORCA',
        ordem: 1,
        origemPreenchimento: null,
        series: const [
          SerieRascunho(
            rodada: 1,
            ordem: 1,
            tipo: 'ESFORCO',
            intensidadeMetricaId: 1,
            intensidadeMetricaCodigo: 'CARGA_KG',
            intensidadeMetricaNome: 'Carga',
            intensidade: 12.5,
            volumeMetricaId: 10,
            volumeMetricaCodigo: 'REPETICOES',
            volumeMetricaNome: 'Repetições',
            volume: 8,
            descansoSeg: null,
          ),
        ],
      );
      final ed = ExercicioEdicao.doRascunho(comDecimal);
      expect(ed.series.first.intensidadeTexto, '12,5');
    });
  });
}
