import 'package:diario_treino/features/catalogo/exercicio_resumo.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
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

  group('Editar séries (PBI-16)', () {
    test('adicionar série copia os valores da última e numera a próxima rodada', () {
      final ed = ExercicioEdicao.doRascunho(_exercicioComAlvos());
      ed.series.first.intensidade.text = '35';
      ed.series.first.volume.text = '8';

      ed.adicionarSerie();

      expect(ed.series, hasLength(2));
      expect(ed.series[1].rodada, 2);
      expect(ed.series[1].intensidade.text, '35');
      expect(ed.series[1].volume.text, '8');
    });

    test('remover série renumera as rodadas na sequência', () {
      final ed = ExercicioEdicao.doRascunho(_exercicioComAlvos());
      ed.adicionarSerie();
      ed.adicionarSerie();
      expect(ed.series.map((s) => s.rodada), [1, 2, 3]);

      ed.removerSerie(0);

      expect(ed.series, hasLength(2));
      expect(ed.series.map((s) => s.rodada), [1, 2]);
    });

    test('resumo lista as séries preenchidas', () {
      final ed = ExercicioEdicao.doRascunho(_exercicioComAlvos());
      ed.adicionarSerie();
      ed.series[0].intensidade.text = '30';
      ed.series[0].volume.text = '10';
      ed.series[1].intensidade.text = '35';
      ed.series[1].volume.text = '8';

      expect(ed.resumo, '2 séries · 30 × 10, 35 × 8');
    });

    test('resumo de exercício não realizado', () {
      final ed = ExercicioEdicao.doRascunho(_exercicioComAlvos());
      ed.realizado = false;
      expect(ed.resumo, 'Não realizado');
    });

    test('resumo de peso corporal mostra só o volume', () {
      final prancha = RascunhoExercicio(
        treinoExercicioId: 'te4',
        exercicioId: 'e4',
        nome: 'Prancha',
        grupoMuscular: 'core',
        modalidade: 'ISOMETRIA',
        ordem: 1,
        origemPreenchimento: null,
        series: const [
          SerieRascunho(
            rodada: 1,
            ordem: 1,
            tipo: 'ESFORCO',
            intensidadeMetricaId: 2,
            intensidadeMetricaCodigo: 'PESO_CORPORAL',
            intensidadeMetricaNome: 'Peso corporal',
            intensidade: null,
            volumeMetricaId: 11,
            volumeMetricaCodigo: 'TEMPO_SEG',
            volumeMetricaNome: 'Tempo',
            volume: 45,
            descansoSeg: null,
          ),
        ],
      );
      final ed = ExercicioEdicao.doRascunho(prancha);
      expect(ed.resumo, '1 série · 45');
    });
  });

  group('Exercício fora da ficha (PBI-17)', () {
    final metricas = {
      'CARGA_KG': const Metrica(
          id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE'),
      'REPETICOES': const Metrica(
          id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: 'rep', eixo: 'VOLUME'),
    };

    ExercicioResumo _item() => const ExercicioResumo(
          id: 'ex-novo',
          nome: 'Rosca direta',
          grupoMuscular: 'bíceps',
          modalidade: 'FORCA',
          intensidadeMetricaCodigo: 'CARGA_KG',
          intensidadeMetricaNome: 'Carga',
          volumeMetricaCodigo: 'REPETICOES',
          volumeMetricaNome: 'Repetições',
          proprio: false,
        );

    test('monta sem vínculo com o prescrito e resolve as métricas por código', () {
      final ed = ExercicioEdicao.foraDaFichaDoCatalogo(_item(), metricas);

      expect(ed.treinoExercicioId, isNull);
      expect(ed.foraDaFicha, isTrue);
      expect(ed.realizado, isTrue);
      expect(ed.exercicioId, 'ex-novo');
      final s = ed.series.single;
      expect(s.intensidadeMetricaId, 1);
      expect(s.volumeMetricaId, 10);
      expect(s.intensidadeTexto, '');
      expect(s.volumeTexto, '');
    });

    test('começa com uma série vazia', () {
      final ed = ExercicioEdicao.foraDaFichaDoCatalogo(_item(), metricas);
      expect(ed.series, hasLength(1));
      expect(ed.series.first.rodada, 1);
    });
  });
}
