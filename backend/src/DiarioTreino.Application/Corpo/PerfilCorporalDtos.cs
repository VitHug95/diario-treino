namespace DiarioTreino.Application.Corpo;

/// <summary>
/// Corpo do <c>PUT /me/perfil-corporal</c>: sexo, nascimento e altura são
/// substituídos (nulo limpa). <see cref="PesoKg"/>, se vier, grava a medida PESO
/// do dia <see cref="DataPeso"/> (sem ela, hoje no servidor); nulo não mexe no
/// histórico de peso. <see cref="DataPeso"/> existe para o app mandar o dia
/// local, que à noite no Brasil já é "amanhã" em UTC.
/// </summary>
public sealed record SalvarPerfilCorporalRequest(
    string? Sexo,
    DateOnly? DataNascimento,
    short? AlturaCm,
    decimal? PesoKg,
    DateOnly? DataPeso);

/// <summary>
/// Dados corporais e a TMB já calculada. <see cref="PesoKg"/> é a medida PESO
/// mais recente (o peso mora nas medidas). <see cref="MotivoSemTmb"/> é nulo
/// quando há <see cref="TmbKcal"/>.
/// </summary>
public sealed record PerfilCorporalResposta(
    string? Sexo,
    DateOnly? DataNascimento,
    short? AlturaCm,
    decimal? PesoKg,
    int? Idade,
    int? TmbKcal,
    string? MotivoSemTmb);
