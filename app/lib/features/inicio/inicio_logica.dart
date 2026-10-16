import '../sessao/sessao_models.dart';

/// Regras puras da tela inicial, separadas da UI para teste.
///
/// Desde a PBI-59 a Início não sugere ficha (a "próxima da sequência" saiu):
/// mostra a semana e o último treino. Treinar fica nas telas de plano.
abstract final class InicioLogica {
  /// Sessão mais recente (pela data; empate fica a primeira da lista). Nulo
  /// sem sessões: o cartão "Último treino" não aparece.
  static SessaoResumo? ultimaSessao(List<SessaoResumo> sessoes) {
    SessaoResumo? ultima;
    for (final s in sessoes) {
      if (ultima == null || s.data.isAfter(ultima.data)) ultima = s;
    }
    return ultima;
  }

  /// Sessões registradas no dia [dia] (a hora não conta), para a folha do dia.
  static List<SessaoResumo> sessoesDoDia(DateTime dia, List<SessaoResumo> sessoes) =>
      sessoes
          .where((s) =>
              s.data.year == dia.year && s.data.month == dia.month && s.data.day == dia.day)
          .toList();

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
