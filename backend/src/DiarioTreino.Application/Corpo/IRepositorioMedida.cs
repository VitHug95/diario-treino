using DiarioTreino.Domain.Corpo;

namespace DiarioTreino.Application.Corpo;

public interface IRepositorioMedida
{
    /// <summary>Até as duas medições mais recentes de cada tipo (para o valor atual e a variação).</summary>
    public Task<List<MedidaCorporal>> UltimasDuasPorTipoAsync(Guid usuarioId, CancellationToken ct);

    /// <summary>Dias com medida e a quantidade de tipos em cada um, do mais recente ao mais antigo.</summary>
    public Task<List<DiaHistoricoMedidas>> HistoricoAsync(Guid usuarioId, CancellationToken ct);

    /// <summary>Medidas do dia, rastreadas para edição.</summary>
    public Task<List<MedidaCorporal>> ListarDoDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct);

    public void Adicionar(MedidaCorporal medida);

    public void Remover(MedidaCorporal medida);

    public Task SalvarAsync(CancellationToken ct);

    /// <summary>Valor mais recente de um tipo (nulo se nunca foi medido).</summary>
    public Task<decimal?> UltimoValorAsync(Guid usuarioId, string tipo, CancellationToken ct);

    /// <summary>Apaga o dia inteiro; devolve quantas linhas foram removidas.</summary>
    public Task<int> ExcluirDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct);
}
