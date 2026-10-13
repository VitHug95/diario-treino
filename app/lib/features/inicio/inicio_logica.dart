import '../fichas/plano_models.dart';
import '../sessao/sessao_models.dart';

/// Regras puras da tela inicial (PBI-23A), separadas da UI para teste.
///
/// O app não trava ficha por dia: a sequência é só uma RECOMENDAÇÃO. A próxima
/// ficha sugerida é a seguinte (na ordem) à última ficha registrada; sem
/// histórico, sugere a primeira.
abstract final class InicioLogica {
  /// Ficha recomendada para o próximo treino. [fichas] deve vir ordenada por
  /// `ordem`. [sessoes] são as sessões recentes (qualquer ordem). Devolve nulo
  /// só se não houver fichas.
  static TreinoResumo? proximaFicha(
    List<TreinoResumo> fichas,
    List<SessaoResumo> sessoes,
  ) {
    if (fichas.isEmpty) return null;

    // Última sessão (mais recente) que foi de uma ficha que ainda existe.
    final idsFichas = {for (final f in fichas) f.id};
    final comFicha = sessoes
        .where((s) => s.treinoId != null && idsFichas.contains(s.treinoId))
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));

    if (comFicha.isEmpty) {
      return fichas.first; // sem histórico: começa pela primeira
    }

    final ultimoId = comFicha.first.treinoId;
    final idx = fichas.indexWhere((f) => f.id == ultimoId);
    // Próxima na rotação (volta para a primeira após a última).
    final proximo = (idx + 1) % fichas.length;
    return fichas[proximo];
  }

  /// Data da última vez que cada ficha foi registrada (treinoId -> data).
  /// Fichas nunca registradas não entram no mapa.
  static Map<String, DateTime> ultimaVezPorFicha(List<SessaoResumo> sessoes) {
    final mapa = <String, DateTime>{};
    for (final s in sessoes) {
      final id = s.treinoId;
      if (id == null) continue;
      final atual = mapa[id];
      if (atual == null || s.data.isAfter(atual)) {
        mapa[id] = s.data;
      }
    }
    return mapa;
  }

  /// Segunda-feira (00:00) da semana que contém [referencia]. Semana começa na
  /// segunda (ISO: weekday 1 = segunda).
  static DateTime inicioDaSemana(DateTime referencia) {
    final dia = DateTime(referencia.year, referencia.month, referencia.day);
    return dia.subtract(Duration(days: dia.weekday - 1));
  }

  /// Os 7 dias da semana (seg→dom) de [referencia], com marcação de treino.
  /// Um dia é marcado quando há ao menos uma sessão naquela data.
  static List<DiaSemana> diasDaSemana(
    DateTime referencia,
    List<SessaoResumo> sessoes,
  ) {
    final segunda = inicioDaSemana(referencia);
    final hoje = DateTime(referencia.year, referencia.month, referencia.day);

    // Datas (sem hora) com sessão registrada.
    final datasComTreino = <DateTime>{
      for (final s in sessoes) DateTime(s.data.year, s.data.month, s.data.day),
    };

    return [
      for (var i = 0; i < 7; i++)
        () {
          final dia = segunda.add(Duration(days: i));
          return DiaSemana(
            data: dia,
            treinou: datasComTreino.contains(dia),
            ehHoje: dia == hoje,
            futuro: dia.isAfter(hoje),
          );
        }(),
    ];
  }
}

/// Um dia na faixa semanal da tela inicial.
class DiaSemana {
  const DiaSemana({
    required this.data,
    required this.treinou,
    required this.ehHoje,
    required this.futuro,
  });

  final DateTime data;
  final bool treinou;
  final bool ehHoje;
  final bool futuro;

  /// Inicial do dia da semana em pt-BR (S T Q Q S S D), seg→dom.
  String get inicial => const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][data.weekday - 1];
}
