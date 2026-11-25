/// Convite de vínculo pendente, do ponto de vista do aluno (quem convidou).
/// Espelha o `ConvitePendente` da API (GET /vinculos/pendentes).
class ConvitePendente {
  const ConvitePendente({
    required this.vinculoId,
    required this.educadorId,
    required this.educadorNome,
    required this.educadorEmail,
  });

  final String vinculoId;
  final String educadorId;
  final String educadorNome;
  final String educadorEmail;

  factory ConvitePendente.doJson(Map<String, dynamic> json) => ConvitePendente(
        vinculoId: json['vinculoId'] as String,
        educadorId: json['educadorId'] as String,
        educadorNome: json['educadorNome'] as String,
        educadorEmail: json['educadorEmail'] as String,
      );
}

/// Aluno com vínculo ativo, do ponto de vista do educador (GET /alunos).
class AlunoVinculado {
  const AlunoVinculado({
    required this.vinculoId,
    required this.alunoId,
    required this.alunoNome,
    required this.alunoEmail,
  });

  final String vinculoId;
  final String alunoId;
  final String alunoNome;
  final String alunoEmail;

  factory AlunoVinculado.doJson(Map<String, dynamic> json) => AlunoVinculado(
        vinculoId: json['vinculoId'] as String,
        alunoId: json['alunoId'] as String,
        alunoNome: json['alunoNome'] as String,
        alunoEmail: json['alunoEmail'] as String,
      );
}

/// Educador com vínculo ativo, do ponto de vista do aluno (GET /educadores,
/// PBI-104). [desde] é o dia do aceite (nulo só em dado antigo sem início).
class EducadorVinculado {
  const EducadorVinculado({
    required this.vinculoId,
    required this.educadorId,
    required this.educadorNome,
    required this.educadorEmail,
    this.desde,
  });

  final String vinculoId;
  final String educadorId;
  final String educadorNome;
  final String educadorEmail;
  final DateTime? desde;

  factory EducadorVinculado.doJson(Map<String, dynamic> json) {
    final desde = json['desde'] as String?;
    return EducadorVinculado(
      vinculoId: json['vinculoId'] as String,
      educadorId: json['educadorId'] as String,
      educadorNome: json['educadorNome'] as String,
      educadorEmail: json['educadorEmail'] as String,
      desde: desde == null ? null : DateTime.parse(desde).toLocal(),
    );
  }
}

/// Subtítulo da linha "Meus educadores" no Perfil (PBI-104).
String resumoMeusEducadores(List<EducadorVinculado> educadores) => switch (educadores.length) {
      0 => 'Ninguém acompanha você agora',
      1 => '1 educador',
      final n => '$n educadores',
    };
