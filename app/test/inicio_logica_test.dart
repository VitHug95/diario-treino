import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/inicio/inicio_logica.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:flutter_test/flutter_test.dart';

TreinoResumo _ficha(String id, int ordem) =>
    TreinoResumo(id: id, nome: id, descricao: null, ordem: ordem);

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
  final fichas = [_ficha('A', 1), _ficha('B', 2), _ficha('C', 3)];

  group('PBI-47: sequência segue só o plano em uso', () {
    // Fichas do plano em uso: A, B, C. "V1" é ficha de outro plano (viagem).
    test('sessão de ficha de outro plano não muda a sequência', () {
      final s = [
        _sessao('A', DateTime(2026, 10, 10)),
        _sessao('V1', DateTime(2026, 10, 12)), // outro plano, mais recente
      ];
      // A última DO PLANO EM USO foi A → sugere B.
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'B');
    });

    test('treino livre (sem ficha) não muda a sequência', () {
      final s = [
        _sessao('B', DateTime(2026, 10, 10)),
        _sessao(null, DateTime(2026, 10, 12)), // treino livre, mais recente
      ];
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'C');
    });

    test('só sessões de outro plano e treino livre: começa pela primeira', () {
      final s = [
        _sessao('V1', DateTime(2026, 10, 11)),
        _sessao(null, DateTime(2026, 10, 12)),
      ];
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'A');
    });

    test('faixa semanal marca o dia treinado em qualquer plano', () {
      // Segunda 12/10/2026; treino de outro plano no domingo anterior não
      // entra, o de terça (13/10) entra.
      final s = [_sessao('V1', DateTime(2026, 10, 13))];
      final dias = InicioLogica.diasDaSemana(DateTime(2026, 10, 14), s);
      expect(dias[1].treinou, isTrue); // terça
      expect(dias[0].treinou, isFalse); // segunda
    });
  });

  group('proximaFicha (rotação)', () {
    test('sem histórico sugere a primeira', () {
      expect(InicioLogica.proximaFicha(fichas, const [])!.id, 'A');
    });

    test('após A sugere B', () {
      final s = [_sessao('A', DateTime(2026, 10, 12))];
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'B');
    });

    test('após a última (C) volta para A', () {
      final s = [_sessao('C', DateTime(2026, 10, 12))];
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'A');
    });

    test('considera a sessão mais recente, não a ordem de chegada', () {
      final s = [
        _sessao('A', DateTime(2026, 10, 10)),
        _sessao('C', DateTime(2026, 10, 13)), // mais recente
        _sessao('B', DateTime(2026, 10, 11)),
      ];
      // Última foi C → sugere A.
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'A');
    });

    test('ignora sessões de ficha que não existe mais e treino livre', () {
      final s = [
        _sessao(null, DateTime(2026, 10, 13)), // treino livre, mais recente
        _sessao('removida', DateTime(2026, 10, 12)),
        _sessao('A', DateTime(2026, 10, 11)), // última válida
      ];
      expect(InicioLogica.proximaFicha(fichas, s)!.id, 'B');
    });

    test('sem fichas devolve nulo', () {
      expect(InicioLogica.proximaFicha(const [], const []), isNull);
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
