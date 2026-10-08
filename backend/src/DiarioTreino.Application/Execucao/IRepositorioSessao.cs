using DiarioTreino.Domain.Execucao;

namespace DiarioTreino.Application.Execucao;

/// <summary>Persistência de sessões e séries (PBI-15).</summary>
public interface IRepositorioSessao
{
    public void AdicionarSessao(Sessao sessao);

    /// <summary>
    /// Séries da sessão MAIS RECENTE do atleta que contenha aquele exercício
    /// (MER 5.1, pré-preenchimento). Vazio se o atleta nunca fez o exercício.
    /// Também devolve a data da sessão, para o aviso de origem.
    /// </summary>
    public Task<(DateOnly Data, IReadOnlyList<SerieExecutada> Series)?> ObterUltimaExecucaoAsync(
        Guid atletaId, Guid exercicioId, CancellationToken ct);

    public Task SalvarAsync(CancellationToken ct);
}
