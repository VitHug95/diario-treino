import 'medidas_models.dart';

/// Sexo usado só no cálculo da TMB (E12 / PBI-93). A API guarda M ou F.
enum SexoBiologico {
  masculino('M', 'Masculino'),
  feminino('F', 'Feminino');

  const SexoBiologico(this.codigo, this.rotulo);

  final String codigo;
  final String rotulo;

  static SexoBiologico? doCodigo(String? codigo) {
    for (final s in values) {
      if (s.codigo == codigo) return s;
    }
    return null;
  }
}

/// Por que não há TMB: faltou dado ou é menor de 18 anos.
enum MotivoSemTmb {
  dadosIncompletos('DADOS_INCOMPLETOS'),
  menorDeIdade('MENOR_DE_IDADE');

  const MotivoSemTmb(this.codigo);

  final String codigo;

  static MotivoSemTmb? doCodigo(String? codigo) {
    for (final m in values) {
      if (m.codigo == codigo) return m;
    }
    return null;
  }
}

/// Dados corporais e a TMB, como a API devolve. A conta da TMB é do back: o app
/// só mostra o número recebido. O [pesoKg] é a medida PESO mais recente.
class PerfilCorporal {
  const PerfilCorporal({
    this.sexo,
    this.nascimento,
    this.alturaCm,
    this.pesoKg,
    this.idade,
    this.tmbKcal,
    this.motivoSemTmb,
  });

  final SexoBiologico? sexo;
  final DateTime? nascimento;
  final int? alturaCm;
  final double? pesoKg;
  final int? idade;
  final int? tmbKcal;
  final MotivoSemTmb? motivoSemTmb;

  /// Nada preenchido (nem o peso das medidas).
  bool get vazio =>
      sexo == null && nascimento == null && alturaCm == null && pesoKg == null;

  factory PerfilCorporal.doJson(Map<String, dynamic> json) => PerfilCorporal(
        sexo: SexoBiologico.doCodigo(json['sexo'] as String?),
        nascimento: json['dataNascimento'] == null
            ? null
            : dataDoJson(json['dataNascimento'] as String),
        alturaCm: (json['alturaCm'] as num?)?.toInt(),
        pesoKg: (json['pesoKg'] as num?)?.toDouble(),
        idade: (json['idade'] as num?)?.toInt(),
        tmbKcal: (json['tmbKcal'] as num?)?.toInt(),
        motivoSemTmb: MotivoSemTmb.doCodigo(json['motivoSemTmb'] as String?),
      );
}
