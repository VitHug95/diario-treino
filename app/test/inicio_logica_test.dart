import 'package:diario_treino/features/inicio/inicio_logica.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:flutter_test/flutter_test.dart';

SessaoResumo _sessao(String? treinoId, DateTime data) => SessaoResumo(
      id: 's-${data.millisecondsSinceEpoch}-$treinoId',
      data: data,
      treinoId: treinoId,
      treinoNome: treinoId,
      quantidadeExercicios: 1,
      duracaoMin: null,
      temObservacao: false,
    );

void main() {
  group('ultimaSessao (PBI-59)', () {
    test('a mais recente pela data, não pela ordem de chegada', () {
      final s = [
        _sessao('A', DateTime(2026, 10, 10)),
        _sessao(null, DateTime(2026, 10, 13)), // treino livre, mais recente
        _sessao('B', DateTime(2026, 10, 11)),
      ];
      expect(InicioLogica.ultimaSessao(s)!.treinoId, isNull);
    });

    test('sem sessões devolve nulo', () {
      expect(InicioLogica.ultimaSessao(const []), isNull);
    });
  });

  group('sessoesDoDia (PBI-59)', () {
    test('pega as sessões do dia, qualquer hora', () {
      final s = [
        _sessao('A', DateTime(2026, 10, 14, 7)),
        _sessao('B', DateTime(2026, 10, 14, 19)),
        _sessao('C', DateTime(2026, 10, 13)),
      ];
      final dia = InicioLogica.sessoesDoDia(DateTime(2026, 10, 14), s);
      expect(dia.map((e) => e.treinoId), ['A', 'B']);
    });
  });

  group('ultimaVezPorFicha', () {
    test('guarda a data mais recente por ficha e ignora treino livre', () {
      final s = [
        _sessao('A', DateTime(2026, 10, 10)),
        _sessao('A', DateTime(2026, 10, 13)),
        _sessao(null, DateTime(2026, 10, 12)),
      ];
      final mapa = InicioLogica.ultimaVezPorFicha(s);
      expect(mapa['A'], DateTime(2026, 10, 13));
      expect(mapa.containsKey(null), isFalse);
    });
  });

  group('diasDaSemana (seg→dom)', () {
    test('começa na segunda e marca o dia com treino', () {
      // 2026-10-14 é uma quarta-feira; a semana começa em 2026-10-12 (segunda).
      final quarta = DateTime(2026, 10, 14);
      final sessoes = [_sessao('A', DateTime(2026, 10, 12))]; // segunda
      final dias = InicioLogica.diasDaSemana(quarta, sessoes);

      expect(dias, hasLength(7));
      expect(dias.first.data, DateTime(2026, 10, 12)); // segunda
      expect(dias.first.inicial, 'S');
      expect(dias.first.treinou, isTrue); // treinou na segunda
      expect(dias[1].treinou, isFalse); // terça sem treino
      expect(dias.last.data, DateTime(2026, 10, 18)); // domingo
    });

    test('marca o dia treinado em qualquer plano e no treino livre', () {
      final s = [_sessao('V1', DateTime(2026, 10, 13)), _sessao(null, DateTime(2026, 10, 14))];
      final dias = InicioLogica.diasDaSemana(DateTime(2026, 10, 14), s);
      expect(dias[0].treinou, isFalse); // segunda
      expect(dias[1].treinou, isTrue); // terça, outro plano
      expect(dias[2].treinou, isTrue); // quarta, treino livre
    });

    test('marca hoje e dias futuros', () {
      final quarta = DateTime(2026, 10, 14);
      final dias = InicioLogica.diasDaSemana(quarta, const []);
      final hoje = dias.firstWhere((d) => d.ehHoje);
      expect(hoje.data, DateTime(2026, 10, 14));
      // Quinta em diante é futuro.
      expect(dias[3].futuro, isTrue); // quinta
      expect(dias[2].futuro, isFalse); // quarta = hoje, não futuro
    });
  });
}
