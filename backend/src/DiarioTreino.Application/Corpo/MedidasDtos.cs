namespace DiarioTreino.Application.Corpo;

/// <summary>Corpo do <c>PUT /me/medidas/{data}</c>: valor nulo remove só aquele tipo do dia.</summary>
public sealed record SalvarMedidasRequest(Dictionary<string, decimal?>? Valores);

/// <summary>Entrada validada: a data vem da rota, os valores do corpo.</summary>
public sealed record SalvarMedidasEntrada(DateOnly Data, IReadOnlyDictionary<string, decimal?>? Valores);

/// <summary>Valores de um dia, por tipo.</summary>
public sealed record DiaMedidas(IReadOnlyDictionary<string, decimal> Valores);

/// <summary>
/// Última medida de um tipo. <see cref="Variacao"/> é a diferença para o registro
/// anterior DO MESMO tipo (nula se só existe um).
/// </summary>
public sealed record UltimaMedida(string Tipo, decimal Valor, DateOnly Data, decimal? Variacao);

/// <summary>Um dia com medidas e quantas foram registradas nele.</summary>
public sealed record DiaHistoricoMedidas(DateOnly Data, int Quantidade);

public sealed record ResumoMedidas(
    IReadOnlyList<UltimaMedida> Ultimas,
    IReadOnlyList<DiaHistoricoMedidas> Historico);
