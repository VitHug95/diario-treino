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

    // ---- Ver / editar / excluir (PBI-18) ----

    /// <summary>Atleta dono da sessão, ou nulo se a sessão não existe.</summary>
    public Task<Guid?> ObterAtletaDaSessaoAsync(Guid sessaoId, CancellationToken ct);

    /// <summary>Sessão com as séries carregadas (ordenadas), ou nulo.</summary>
    public Task<Sessao?> ObterSessaoComSeriesAsync(Guid sessaoId, CancellationToken ct);

    public void RemoverSessao(Sessao sessao);

    public void RemoverSerie(SerieExecutada serie);

    public void AdicionarSerie(SerieExecutada serie);

    public Task SalvarAsync(CancellationToken ct);
}
