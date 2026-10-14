using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Application.Progresso;

/// <summary>
/// Evolução de um exercício ao longo do tempo (PBI-20). O progresso é sempre do
/// atleta logado: filtra as sessões por ele, então sessões de terceiros nunca
/// entram. Exercício inexistente/indisponível responde 404.
/// </summary>
public sealed class ServicoProgresso
{
    private readonly IRepositorioProgresso _progresso;
    private readonly IRepositorioExercicio _exercicios;

    public ServicoProgresso(
        IRepositorioProgresso progresso,
        IRepositorioExercicio exercicios)
    {
        _progresso = progresso;
        _exercicios = exercicios;
    }

    /// <summary>Exercícios que o atleta logado já treinou (seletor do gráfico).</summary>
    public Task<IReadOnlyList<ExercicioComHistorico>> ListarExerciciosComHistoricoAsync(
        Guid usuarioLogadoId, CancellationToken ct) =>
        _progresso.ListarExerciciosComHistoricoAsync(usuarioLogadoId, ct);

    public async Task<ProgressoExercicio> ObterProgressoAsync(
        Guid usuarioLogadoId,
        Guid exercicioId,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct)
    {
        // Exercício precisa existir e estar disponível ao usuário (global ou
        // próprio). Caso contrário, 404 (não revela existência de terceiros).
        if (!await _exercicios.ExisteDisponivelAsync(exercicioId, usuarioLogadoId, ct))
        {
            throw new RecursoNaoEncontradoException("Exercício não encontrado.");
        }

        var basicos = await _exercicios.ObterBasicosPorIdsAsync([exercicioId], ct);
        var exercicio = basicos.GetValueOrDefault(exercicioId)
            ?? throw new RecursoNaoEncontradoException("Exercício não encontrado.");

        var metrica = MetricaDaModalidade(exercicio.Modalidade);
        if (metrica is null)
        {
            // Modalidade sem gráfico de evolução no MVP (ex.: cardio): devolve
            // vazio em vez de erro, para a tela mostrar estado vazio.
            return new ProgressoExercicio(
                exercicio.Id, exercicio.Nome, exercicio.Modalidade, null,
                [], new ResumoProgresso(0, null, 0));
        }

        var forca = exercicio.Modalidade == Modalidade.Forca;
        var brutos = await _progresso.ObterPontosAsync(
            usuarioLogadoId, exercicioId, forca, de, ate, ct);

        var pontos = brutos
            .Select(b => new PontoProgresso(
                b.Data, b.Valor, b.Repeticoes, b.SessaoId, b.Observacao))
            .ToList();

        var variacao = pontos.Count >= 2
            ? pontos[^1].Valor - pontos[0].Valor
            : (decimal?)null;
        var comObs = brutos.Count(b => b.TemObservacao);

        return new ProgressoExercicio(
            exercicio.Id,
            exercicio.Nome,
            exercicio.Modalidade,
            metrica,
            pontos,
            new ResumoProgresso(pontos.Count, variacao, comObs));
    }

    /// <summary>Grandeza do gráfico pela modalidade: força = CARGA, isometria =
    /// TEMPO; demais (cardio) ainda não têm gráfico no MVP.</summary>
    private static string? MetricaDaModalidade(string modalidade) => modalidade switch
    {
        Modalidade.Forca => "CARGA",
        Modalidade.Isometria => "TEMPO",
        _ => null,
    };
}
