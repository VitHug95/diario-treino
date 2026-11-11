import 'medidas_models.dart';
import 'perfil_corporal_models.dart';

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

/// 1755 → "1.755" (separador de milhar pt-BR, sem intl).
String formatarMilhar(int n) {
  final texto = n.abs().toString();
  final buf = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < texto.length; i++) {
    if (i > 0 && (texto.length - i) % 3 == 0) buf.write('.');
    buf.write(texto[i]);
  }
  return buf.toString();
}

/// Peso sem casa decimal quando é inteiro: 78.0 → "78 kg", 78.5 → "78,5 kg".
String formatarPesoCurto(double kg) {
  final inteiro = (kg - kg.roundToDouble()).abs() < 0.05;
  return inteiro ? '${kg.round()} kg' : '${formatarValor(kg)} kg';
}

/// Texto do Perfil: "78 kg · 180 cm · TMB 1.755 kcal por dia" ou
/// "Preencha para calcular sua TMB".
String resumoDadosParaPerfil(PerfilCorporal p) {
  final partes = [
    if (p.pesoKg != null) formatarPesoCurto(p.pesoKg!),
    if (p.alturaCm != null) '${p.alturaCm} cm',
  ];
  if (p.tmbKcal != null) {
    partes.add('TMB ${formatarMilhar(p.tmbKcal!)} kcal por dia');
  }
  if (partes.isEmpty) return 'Preencha para calcular sua TMB';
  if (p.tmbKcal == null) {
    partes.add(p.motivoSemTmb == MotivoSemTmb.menorDeIdade
        ? 'TMB só para adultos'
        : 'preencha para calcular a TMB');
  }
  return partes.join(' · ');
}
