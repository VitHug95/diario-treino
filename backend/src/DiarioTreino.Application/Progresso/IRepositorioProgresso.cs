namespace DiarioTreino.Application.Progresso;

/// <summary>Consultas de evolução por exercício (PBI-20).</summary>
public interface IRepositorioProgresso
{
    /// <summary>
    /// Um ponto por sessão do atleta que tem o exercício (séries de esforço),
    /// no período, em ordem crescente de data.
    /// <list type="bullet">
    /// <item>Força (<c>forca = true</c>): <c>Valor</c> = maior carga da sessão e
    /// <c>Repeticoes</c> = repetições daquela série de maior carga.</item>
    /// <item>Isometria (<c>forca = false</c>): <c>Valor</c> = maior tempo
    /// sustentado da sessão; <c>Repeticoes</c> = nulo.</item>
    /// </list>
    /// </summary>
    public Task<IReadOnlyList<PontoBruto>> ObterPontosAsync(
        Guid atletaId,
        Guid exercicioId,
        bool forca,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct);

    /// <summary>
    /// Exercícios que o atleta já treinou (têm séries de esforço em alguma
    /// sessão dele), com nome e modalidade, em ordem alfabética. Base do seletor
    /// do gráfico de progresso.
    /// </summary>
    public Task<IReadOnlyList<ExercicioComHistorico>> ListarExerciciosComHistoricoAsync(
        Guid atletaId, CancellationToken ct);
}

/// <summary>Ponto bruto vindo do banco, antes de virar DTO.</summary>
public sealed record PontoBruto(
    DateOnly Data,
    decimal Valor,
    decimal? Repeticoes,
    bool TemObservacao);
