import '../../features/sessao/sessao_models.dart';

/// Uma célula preenchida da grade do mês: um dia com seu estado (PBI-82).
/// Os estados são os mesmos da faixa semanal (treinou / hoje / futuro) para a
/// marca visual ([MarcaDia]) ser idêntica.
class CelulaMes {
  const CelulaMes({
    required this.data,
    required this.treinou,
    required this.ehHoje,
    required this.futuro,
  });

  final DateTime data;
  final bool treinou;
  final bool ehHoje;
  final bool futuro;

  int get dia => data.day;
}

/// Regras puras do calendário do mês (PBI-82), sem UI, para teste direto.
abstract final class CalendarioMes {
  /// Nomes dos meses em pt-BR (índice 1 = janeiro).
  static const nomesMes = [
    '', // placeholder para alinhar índice 1..12
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  /// Iniciais das colunas, seg→dom (S T Q Q S S D).
  static const iniciaisColunas = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  /// Título "Outubro de 2026".
  static String titulo(int ano, int mes) => '${nomesMes[mes]} de $ano';

  /// Mês (ano, mês) normalizado ao primeiro dia, para comparar e navegar.
  static DateTime primeiroDiaDoMes(int ano, int mes) => DateTime(ano, mes, 1);

  /// Último dia do mês (28 a 31). `DateTime(ano, mes + 1, 0)` dá o último dia
  /// do mês atual — o truque do "dia 0" do mês seguinte.
  static DateTime ultimoDiaDoMes(int ano, int mes) => DateTime(ano, mes + 1, 0);

  /// Monta as linhas (semanas) do mês, cada uma com 7 células seg→dom. As
  /// células antes do dia 1 e depois do último dia ficam nulas (preenchimento),
  /// sem marca e sem toque.
  ///
  /// [hoje] e [datasComTreino] definem o estado de cada dia, igual à semana:
  /// treinou = a data está no conjunto; ehHoje = é o dia de hoje; futuro = está
  /// depois de hoje. [datasComTreino] deve conter datas normalizadas (00:00).
  static List<List<CelulaMes?>> semanasDoMes(
    int ano,
    int mes, {
    required DateTime hoje,
    required Set<DateTime> datasComTreino,
  }) {
    final hojeNorm = DateTime(hoje.year, hoje.month, hoje.day);
    final primeiro = primeiroDiaDoMes(ano, mes);
    final ultimo = ultimoDiaDoMes(ano, mes);

    // Quantas células vazias antes do dia 1 (seg=1 → 0 vazias; dom=7 → 6).
    final vaziasAntes = primeiro.weekday - 1;

    final celulas = <CelulaMes?>[];
    for (var i = 0; i < vaziasAntes; i++) {
      celulas.add(null);
    }
    for (var d = 1; d <= ultimo.day; d++) {
      final data = DateTime(ano, mes, d);
      celulas.add(CelulaMes(
        data: data,
        treinou: datasComTreino.contains(data),
        ehHoje: data == hojeNorm,
        futuro: data.isAfter(hojeNorm),
      ));
    }
    // Completa a última linha até fechar 7 colunas.
    while (celulas.length % 7 != 0) {
      celulas.add(null);
    }

    // Fatia em linhas de 7.
    final linhas = <List<CelulaMes?>>[];
    for (var i = 0; i < celulas.length; i += 7) {
      linhas.add(celulas.sublist(i, i + 7));
    }
    return linhas;
  }

  /// Conjunto de datas (normalizadas) com ao menos uma sessão, para [semanasDoMes].
  static Set<DateTime> datasComTreino(List<SessaoResumo> sessoes) => {
        for (final s in sessoes) DateTime(s.data.year, s.data.month, s.data.day),
      };

  /// Quantos dias do mês têm treino (para "N dias treinados").
  static int diasTreinados(List<List<CelulaMes?>> semanas) => semanas
      .expand((linha) => linha)
      .where((c) => c != null && c.treinou)
      .length;

  /// É o mês atual de [hoje]? (desabilita a seta "mês seguinte" e o botão "Hoje").
  static bool ehMesAtual(int ano, int mes, DateTime hoje) =>
      ano == hoje.year && mes == hoje.month;

  /// Mês anterior a (ano, mes), como par.
  static (int ano, int mes) mesAnterior(int ano, int mes) =>
      mes == 1 ? (ano - 1, 12) : (ano, mes - 1);

  /// Mês seguinte a (ano, mes), como par.
  static (int ano, int mes) mesSeguinte(int ano, int mes) =>
      mes == 12 ? (ano + 1, 1) : (ano, mes + 1);
}
