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
