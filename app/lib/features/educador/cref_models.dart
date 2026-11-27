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
    this.declaradoEm,
  });

  final String? uf;
  final String? numero;
  final String? situacao;
  final String? categoria;
  final String origem;
  final DateTime? consultadoEm;

  /// Quando o educador enviou número, UF e foto (origem DECLARADA).
  final DateTime? declaradoEm;

  bool get legado => origem == 'LEGADO';
  bool get declarada => origem == 'DECLARADA';

  factory RegistroCref.doJson(Map<String, dynamic> json) {
    final em = json['consultadoEm'] as String?;
    final declarado = json['declaradoEm'] as String?;
    return RegistroCref(
      uf: json['uf'] as String?,
      numero: json['numero'] as String?,
      situacao: json['situacao'] as String?,
      categoria: json['categoria'] as String?,
      origem: json['origem'] as String,
      consultadoEm: em == null ? null : DateTime.parse(em).toLocal(),
      declaradoEm: declarado == null ? null : DateTime.parse(declarado).toLocal(),
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

/// Tamanho máximo da foto da carteira (o mesmo do servidor).
const tamanhoMaximoFotoCref = 5 * 1024 * 1024;

/// Tipo da foto pelo conteúdo, como o servidor confere: JPEG começa com FF D8 FF
/// e PNG com 89 50 4E 47 0D 0A 1A 0A. Nulo se não for nenhum dos dois.
String? tipoDaFotoCref(List<int> b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length >= png.length) {
    for (var i = 0; i < png.length; i++) {
      if (b[i] != png[i]) return null;
    }
    return 'image/png';
  }
  return null;
}

/// CPF com 11 dígitos e os verificadores certos (a mesma conta do servidor).
/// Usado pela consulta por CPF, guardada para quando os leitores do site do CREF
/// existirem.
bool cpfValido(String? texto) {
  final d = (texto ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length != 11 || d.split('').toSet().length == 1) return false;
  int verificador(int quantos) {
    var soma = 0;
    for (var i = 0; i < quantos; i++) {
      soma += int.parse(d[i]) * (quantos + 1 - i);
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  return verificador(9) == int.parse(d[9]) && verificador(10) == int.parse(d[10]);
}