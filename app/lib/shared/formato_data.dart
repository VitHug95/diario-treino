// Texto e leitura de datas no formato do app, dd/mm/aaaa (sem `intl`).

/// 05/11/2026.
String formatarDataCompleta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Lê "dd/mm/aaaa". Devolve nulo se faltar parte (incompleta) ou se o dia não
/// existe (31/02, mês 13). O resultado é a meia-noite local do dia.
DateTime? lerDataCompleta(String texto) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  final ano = int.parse(m.group(3)!);
  final data = DateTime(ano, mes, dia);
  // DateTime "rola" datas impossíveis (31/02 vira 03/03): confere o que voltou.
  if (data.year != ano || data.month != mes || data.day != dia) return null;
  return data;
}

/// A mesma data à meia-noite local (tira a hora).
DateTime soDia(DateTime d) => DateTime(d.year, d.month, d.day);
