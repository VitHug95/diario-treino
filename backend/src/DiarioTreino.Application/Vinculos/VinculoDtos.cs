namespace DiarioTreino.Application.Vinculos;

/// <summary>Corpo de <c>POST /vinculos</c>: o e-mail do aluno a convidar.</summary>
public sealed record ConvidarAlunoRequest(string Email);

/// <summary>
/// Convite pendente, do ponto de vista do aluno (<c>GET /vinculos/pendentes</c>):
/// quem é o educador que convidou.
/// </summary>
public sealed record ConvitePendente(
    Guid VinculoId,
    Guid EducadorId,
    string EducadorNome,
    string EducadorEmail);

/// <summary>Aluno com vínculo ativo, do ponto de vista do educador (<c>GET /alunos</c>).</summary>
public sealed record AlunoVinculado(
    Guid VinculoId,
    Guid AlunoId,
    string AlunoNome,
    string AlunoEmail);
