/// Habilitação do educador pelo CREF (PBI-106). Nenhum destes modelos guarda o
/// CPF: ele só vai no corpo do pedido de verificação.
library;

/// As 27 UFs, para o seletor.
const ufsBrasil = [
  'AC', 'AL', 'AM', 'AP', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MG', 'MS', 'MT', 'PA',
  'PB', 'PE', 'PI', 'PR', 'RJ', 'RN', 'RO', 'RR', 'RS', 'SC', 'SE', 'SP', 'TO',
];

/// Registro guardado de quem foi habilitado. No LEGADO, UF e número ficam vazios.
class RegistroCref {
  const RegistroCref({
    this.uf,
    this.numero,
    this.situacao,
    this.categoria,
    required this.origem,
    this.consultadoEm,
  });

  final String? uf;
  final String? numero;
  final String? situacao;
  final String? categoria;
  final String origem;
  final DateTime? consultadoEm;

  bool get legado => origem == 'LEGADO';

  factory RegistroCref.doJson(Map<String, dynamic> json) {
    final em = json['consultadoEm'] as String?;
    return RegistroCref(
      uf: json['uf'] as String?,
      numero: json['numero'] as String?,
      situacao: json['situacao'] as String?,
      categoria: json['categoria'] as String?,
      origem: json['origem'] as String,
      consultadoEm: em == null ? null : DateTime.parse(em).toLocal(),
    );
  }
}

/// `GET /me/educador/cref`: se a verificação é exigida e o registro, se houver.
class SituacaoCref {
  const SituacaoCref({required this.verificacaoExigida, this.registro});

  /// Chave do servidor: desligada, o modo educador ativa como antes.
  final bool verificacaoExigida;
  final RegistroCref? registro;

  bool get habilitado => registro != null;

  factory SituacaoCref.doJson(Map<String, dynamic> json) => SituacaoCref(
        verificacaoExigida: json['verificacaoExigida'] as bool? ?? false,
        registro: json['registro'] == null
            ? null
            : RegistroCref.doJson(json['registro'] as Map<String, dynamic>),
      );
}

/// Resposta da verificação.
class ResultadoVerificacaoCref {
  const ResultadoVerificacaoCref({required this.resultado, this.motivo, this.situacao});

  final String resultado;
  final String? motivo;

  /// A situação que o CREF devolveu (vem da consulta, nunca do que foi digitado).
  final String? situacao;

  bool get habilitado => resultado == 'HABILITADO';

  factory ResultadoVerificacaoCref.doJson(Map<String, dynamic> json) => ResultadoVerificacaoCref(
        resultado: json['resultado'] as String,
        motivo: json['motivo'] as String?,
        situacao: json['situacao'] as String?,
      );

  /// A mensagem de cada resultado (PBI-106). O CPF nunca entra aqui.
  String get mensagem => switch ((resultado, motivo)) {
        ('HABILITADO', _) => 'Registro ativo confirmado. Modo educador liberado.',
        ('RECUSADO', 'SITUACAO_NAO_ATIVA') =>
          'Seu registro consta como ${situacao ?? 'não ativo'} no CREF. Regularize e tente de novo.',
        ('RECUSADO', 'NUMERO_NAO_CONFERE') =>
          'O CPF tem registro no CREF dessa UF, mas com outro número. Confira o número.',
        ('NAO_ENCONTRADO', _) => 'Não encontramos esse CPF no CREF dessa UF. Confira a UF e o número.',
        ('INDISPONIVEL', 'UF_SEM_CONSULTA') =>
          'Ainda não conseguimos consultar o CREF dessa UF automaticamente.',
        ('INDISPONIVEL', _) => 'A consulta do CREF está fora do ar agora, tente em alguns minutos.',
        _ => 'Não foi possível verificar agora. Tente de novo.',
      };
}
