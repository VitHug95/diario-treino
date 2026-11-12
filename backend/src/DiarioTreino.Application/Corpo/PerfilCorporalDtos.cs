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
/// Dados corporais e a TMB. <see cref="PesoKg"/> é a medida PESO mais recente (o
/// peso mora nas medidas). <see cref="TmbKcal"/> é o valor EFETIVO (PBI-98): o
/// informado pelo atleta, se houver; senão o calculado. <see cref="TmbCalculadaKcal"/>
/// é sempre o da fórmula e <see cref="MotivoSemTmb"/> explica a falta dele (pode vir
/// preenchido mesmo com <see cref="TmbKcal"/> manual). <see cref="TmbManual"/> diz
/// se o efetivo é o informado.
/// </summary>
public sealed record PerfilCorporalResposta(
    string? Sexo,
    DateOnly? DataNascimento,
    short? AlturaCm,
    decimal? PesoKg,
    int? Idade,
    int? TmbKcal,
    string? MotivoSemTmb,
    int? TmbCalculadaKcal,
    bool TmbManual);

/// <summary>
/// Corpo do <c>PUT /me/perfil-corporal/tmb-manual</c> (PBI-98). Decimal para o
/// valor quebrado chegar à validação (e virar 400 com mensagem) em vez de falhar
/// na leitura do JSON.
/// </summary>
public sealed record DefinirTmbManualRequest(decimal? Kcal);
