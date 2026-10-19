import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/shared/calendario/calendario_mes.dart';
import 'package:flutter_test/flutter_test.dart';

SessaoResumo _sessao(DateTime data) => SessaoResumo(
      id: 's-${data.toIso8601String()}',
      data: data,
      treinoId: null,
      treinoNome: null,
      quantidadeExercicios: 1,
      duracaoMin: null,
      temObservacao: false,
    );

void main() {
  group('CalendarioMes.semanasDoMes', () {
    test('outubro/2026 começa numa quinta, 31 dias, 5 linhas', () {
      final semanas = CalendarioMes.semanasDoMes(2026, 10,
          hoje: DateTime(2026, 10, 19), datasComTreino: const {});

      expect(semanas.length, 5);
      // Seg a qua (3 primeiras) ficam vazias; o dia 1 cai na quinta (índice 3).
      expect(semanas.first.sublist(0, 3), everyElement(isNull));
      expect(semanas.first[3]!.dia, 1);
      // Último dia é 31; depois dele, preenchimento nulo até fechar a linha.
      final ultimaLinha = semanas.last;
      final ultimoDia = ultimaLinha.where((c) => c != null).last!;
      expect(ultimoDia.dia, 31);
      expect(ultimaLinha.last, isNull); // 31/out/2026 é um sábado
    });

    test('fevereiro/2027 começa numa segunda: 4 linhas completas, sem vazias', () {
      final semanas = CalendarioMes.semanasDoMes(2027, 2,
          hoje: DateTime(2027, 2, 15), datasComTreino: const {});

      expect(semanas.length, 4);
      expect(semanas.first.first!.dia, 1); // sem preenchimento antes
      expect(semanas.expand((l) => l).whereType<CelulaMes>().length, 28);
      // Nenhuma célula nula: 28 dias = 4 × 7 exatos.
      expect(semanas.expand((l) => l).where((c) => c == null), isEmpty);
    });

    test('março/2026 começa num domingo: 6 linhas', () {
      final semanas = CalendarioMes.semanasDoMes(2026, 3,
          hoje: DateTime(2026, 3, 10), datasComTreino: const {});

      expect(semanas.length, 6);
      // 6 primeiras células vazias (seg→sáb); dia 1 no domingo (índice 6).
      expect(semanas.first.sublist(0, 6), everyElement(isNull));
      expect(semanas.first[6]!.dia, 1);
    });

    test('marca treino, hoje e futuro a partir de hoje e das datas com treino', () {
      final hoje = DateTime(2026, 10, 19);
      final datas = CalendarioMes.datasComTreino([
        _sessao(DateTime(2026, 10, 1)),
        _sessao(DateTime(2026, 10, 1, 20, 30)), // mesmo dia, hora ignorada
        _sessao(DateTime(2026, 10, 17)),
      ]);
      final semanas = CalendarioMes.semanasDoMes(2026, 10,
          hoje: hoje, datasComTreino: datas);
      final celulas = {
        for (final c in semanas.expand((l) => l).whereType<CelulaMes>()) c.dia: c,
      };

      expect(celulas[1]!.treinou, isTrue);
      expect(celulas[17]!.treinou, isTrue);
      expect(celulas[2]!.treinou, isFalse);
      expect(celulas[19]!.ehHoje, isTrue);
      expect(celulas[19]!.futuro, isFalse);
      expect(celulas[20]!.futuro, isTrue); // depois de hoje
      expect(celulas[18]!.futuro, isFalse); // antes de hoje
    });

    test('diasTreinados conta só os dias com sessão', () {
      final hoje = DateTime(2026, 10, 19);
      final datas = CalendarioMes.datasComTreino([
        _sessao(DateTime(2026, 10, 1)),
        _sessao(DateTime(2026, 10, 3)),
        _sessao(DateTime(2026, 10, 3)), // repetido no mesmo dia: conta 1
      ]);
      final semanas = CalendarioMes.semanasDoMes(2026, 10,
          hoje: hoje, datasComTreino: datas);

      expect(CalendarioMes.diasTreinados(semanas), 2);
    });
  });

  group('navegação de mês', () {
    test('mesAnterior e mesSeguinte viram o ano', () {
      expect(CalendarioMes.mesAnterior(2026, 1), (2025, 12));
      expect(CalendarioMes.mesSeguinte(2026, 12), (2027, 1));
      expect(CalendarioMes.mesAnterior(2026, 10), (2026, 9));
      expect(CalendarioMes.mesSeguinte(2026, 10), (2026, 11));
    });

    test('ehMesAtual compara ano e mês de hoje', () {
      final hoje = DateTime(2026, 10, 19);
      expect(CalendarioMes.ehMesAtual(2026, 10, hoje), isTrue);
      expect(CalendarioMes.ehMesAtual(2026, 9, hoje), isFalse);
      expect(CalendarioMes.ehMesAtual(2025, 10, hoje), isFalse);
    });

    test('título e iniciais em pt-BR', () {
      expect(CalendarioMes.titulo(2026, 10), 'Outubro de 2026');
      expect(CalendarioMes.titulo(2027, 2), 'Fevereiro de 2027');
      expect(CalendarioMes.iniciaisColunas, ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']);
    });

    test('ultimoDiaDoMes cobre fevereiro bissexto e não', () {
      expect(CalendarioMes.ultimoDiaDoMes(2026, 2).day, 28);
      expect(CalendarioMes.ultimoDiaDoMes(2028, 2).day, 29); // bissexto
      expect(CalendarioMes.ultimoDiaDoMes(2026, 10).day, 31);
    });
  });
}
