import 'medidas_models.dart';

/// Formatação das medidas em pt-BR (o app não usa `intl`): uma casa decimal com
/// vírgula, datas como dd/MM.

/// 84.0 → "84,0".
String formatarValor(double valor) => valor.toStringAsFixed(1).replaceAll('.', ',');

/// 84.0, cm → "84,0 cm".
String formatarComUnidade(double valor, TipoMedida tipo) =>
    '${formatarValor(valor)} ${tipo.unidade}';

/// Variação com sinal explícito: "−1,5 cm", "+0,5 kg". Zero vira "Igual".
String formatarVariacao(double variacao, TipoMedida tipo) {
  if (_ehZero(variacao)) return 'Igual';
  final sinal = variacao < 0 ? '−' : '+';
  return '$sinal${formatarValor(variacao.abs())} ${tipo.unidade}';
}

/// Para o leitor de tela: "caiu 1,5 centímetros", "subiu 0,5 quilo", "sem variação".
String falarVariacao(double variacao, TipoMedida tipo) {
  if (_ehZero(variacao)) return 'sem variação';
  final verbo = variacao < 0 ? 'caiu' : 'subiu';
  final abs = variacao.abs();
  return '$verbo ${formatarValor(abs)} ${tipo.unidadePorExtenso(plural: _plural(abs))}';
}

/// "84,0 centímetros" para o leitor de tela.
String falarValor(double valor, TipoMedida tipo) =>
    '${formatarValor(valor)} ${tipo.unidadePorExtenso(plural: _plural(valor))}';

/// dd/MM.
String dataCurta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// dd/MM/yyyy.
String dataCompleta(DateTime d) => '${dataCurta(d)}/${d.year}';

/// yyyy-MM-dd, o formato da API.
String dataParaApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Texto do Perfil: "Última em 05/11 · cintura 84,0 cm" ou "Nenhuma medida ainda".
String resumoParaPerfil(ResumoMedidas resumo) {
  if (resumo.vazio) return 'Nenhuma medida ainda';
  if (resumo.historico.isEmpty) return 'Medidas registradas';
  final dia = resumo.historico.first.data;
  UltimaMedida? deHoje;
  for (final u in resumo.ultimas) {
    if (u.data == dia) {
      deHoje = u;
      break;
    }
  }
  if (deHoje == null) return 'Última em ${dataCurta(dia)}';
  return 'Última em ${dataCurta(dia)} · '
      '${deHoje.tipo.rotulo.toLowerCase()} ${formatarComUnidade(deHoje.valor, deHoje.tipo)}';
}

bool _ehZero(double v) => v.abs() < 0.05;

// "1,0 centímetro" no singular; o resto no plural.
bool _plural(double v) => (v - 1).abs() >= 0.05;
