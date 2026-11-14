namespace DiarioTreino.Application.Corpo;

/// <summary>
/// O que o atleta compartilha com os educadores de vínculo ativo (PBI-95,
/// <c>GET /me/compartilhamento-corporal</c>). Dois cadeados independentes,
/// trancados por padrão; <see cref="Educadores"/> diz quem vê hoje.
/// </summary>
public sealed record CompartilhamentoCorporalResposta(
    bool DadosCorporais,
    DateTimeOffset? DadosCorporaisDesde,
    bool Medidas,
    DateTimeOffset? MedidasDesde,
    IReadOnlyList<EducadorQueVe> Educadores);

/// <summary>Educador com vínculo ativo: quem vê o que estiver destrancado.</summary>
public sealed record EducadorQueVe(Guid EducadorId, string Nome);

/// <summary>Corpo de <c>PUT /me/compartilhamento-corporal</c>: os dois cadeados, sempre os dois.</summary>
public sealed record DefinirCompartilhamentoRequest(bool? DadosCorporais, bool? Medidas);

/// <summary>
/// O corpo do aluno visto pelo educador (<c>GET /alunos/{atletaId}/corpo</c>).
/// Seção trancada volta nula: o educador sabe que existe o cadeado, mas não
/// vê nenhum valor.
/// </summary>
public sealed record CorpoDoAluno(
    bool DadosCorporaisCompartilhados,
    PerfilCorporalResposta? DadosCorporais,
    bool MedidasCompartilhadas,
    ResumoMedidas? Medidas);
