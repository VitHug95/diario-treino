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

    /// <summary>
    /// As <paramref name="limite"/> sessões mais recentes do atleta que contêm
    /// o exercício (TV-4, aba Histórico), em ordem de data decrescente. Cada
    /// item traz a data, a observação do dia e as séries daquele exercício.
    /// </summary>
    public Task<IReadOnlyList<(Guid SessaoId, DateOnly Data, string? Observacao,
        bool ObservacaoPrivada, IReadOnlyList<SerieExecutada> Series)>> ObterHistoricoExercicioAsync(
        Guid atletaId, Guid exercicioId, int limite, CancellationToken ct);

    /// <summary>
    /// Sessões do atleta no período (PBI-22), em ordem de data decrescente.
    /// `de`/`ate` são limites opcionais e inclusivos. Cada item já traz o nome
    /// da ficha, a contagem de exercícios distintos e se tem observação.
    /// </summary>
    public Task<IReadOnlyList<SessaoResumo>> ListarPorPeriodoAsync(
        Guid atletaId, DateOnly? de, DateOnly? ate, CancellationToken ct);

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
