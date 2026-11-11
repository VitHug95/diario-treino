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

/// <summary>Um ponto da evolução: o valor medido naquele dia.</summary>
public sealed record PontoMedida(DateOnly Data, decimal Valor);

/// <summary>
/// Evolução de uma medida no período (E12 / PBI-94), em ordem de data.
/// <see cref="Primeira"/> e <see cref="Ultima"/> são o primeiro e o último ponto;
/// <see cref="Variacao"/> é ultima − primeira (nula com menos de dois pontos).
/// Período sem registro devolve lista vazia, não erro.
/// </summary>
public sealed record EvolucaoMedida(
    string Tipo,
    string Unidade,
    IReadOnlyList<PontoMedida> Pontos,
    PontoMedida? Primeira,
    PontoMedida? Ultima,
    decimal? Variacao);
