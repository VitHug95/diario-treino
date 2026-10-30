using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Application.Progresso;

/// <summary>
/// Evolução de um exercício ao longo do tempo (PBI-20). O progresso é do
/// atleta-alvo: o próprio usuário logado ou, no modo educador (PBI-86), um
/// aluno com vínculo ativo — a regra do MAS 11.3 (<see cref="IControleAcesso"/>)
/// é aplicada sempre. Exercício inexistente/indisponível ao alvo responde 404.
/// </summary>
public sealed class ServicoProgresso
{
    private readonly IRepositorioProgresso _progresso;
    private readonly IRepositorioExercicio _exercicios;
    private readonly IControleAcesso _acesso;

    public ServicoProgresso(
        IRepositorioProgresso progresso,
        IRepositorioExercicio exercicios,
        IControleAcesso acesso)
    {
        _progresso = progresso;
        _exercicios = exercicios;
        _acesso = acesso;
    }

    /// <summary>
    /// Exercícios que o atleta-alvo já treinou (seletor do gráfico). O educador
    /// com vínculo ativo passa o <paramref name="atletaId"/> do aluno.
    /// </summary>
    public async Task<IReadOnlyList<ExercicioComHistorico>> ListarExerciciosComHistoricoAsync(
        Guid usuarioLogadoId, Guid atletaId, CancellationToken ct)
    {
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId, ct);
        return await _progresso.ListarExerciciosComHistoricoAsync(atletaId, ct);
    }

    public async Task<ProgressoExercicio> ObterProgressoAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        Guid exercicioId,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct)
    {
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId, ct);

        // Exercício precisa existir e estar disponível ao atleta-alvo (global ou
        // próprio dele). Caso contrário, 404. Avaliado pelo alvo (PBI-86): o
        // educador enxerga os exercícios privados do aluno que está vendo.
        if (!await _exercicios.ExisteDisponivelAsync(exercicioId, atletaId, ct))
        {
            throw new RecursoNaoEncontradoException("Exercício não encontrado.");
        }

        var basicos = await _exercicios.ObterBasicosPorIdsAsync([exercicioId], ct);
        var exercicio = basicos.GetValueOrDefault(exercicioId)
            ?? throw new RecursoNaoEncontradoException("Exercício não encontrado.");

        // A grandeza do gráfico é decidida POR EXERCÍCIO (PBI-73), não só pela
        // modalidade: força com carga usa a carga; força sem carga (ex.: peso
        // corporal, abdominais) cai para repetições; isometria usa o tempo;
        // cardio ainda não tem gráfico no MVP.
        var metrica = await DecidirMetricaAsync(
            atletaId, exercicioId, exercicio.Modalidade, de, ate, ct);
        if (metrica is null)
        {
            // Modalidade sem gráfico de evolução no MVP (ex.: cardio): devolve
            // vazio em vez de erro, para a tela mostrar estado vazio.
            return new ProgressoExercicio(
                exercicio.Id, exercicio.Nome, exercicio.Modalidade, null,
                [], new ResumoProgresso(0, null, 0));
        }

        var brutos = await _progresso.ObterPontosAsync(
            atletaId, exercicioId, metrica.Value, de, ate, ct);

        // Observação privada (PBI-87): o educador (logado ≠ alvo) não vê o texto
        // nem a conta do resumo. O próprio atleta vê tudo.
        var ehEducador = usuarioLogadoId != atletaId;
        bool PodeVer(PontoBruto b) => !(ehEducador && b.ObservacaoPrivada);

        var pontos = brutos
            .Select(b => new PontoProgresso(
                b.Data, b.Valor, b.Repeticoes, b.SessaoId, PodeVer(b) ? b.Observacao : null))
            .ToList();

        var variacao = pontos.Count >= 2
            ? pontos[^1].Valor - pontos[0].Valor
            : (decimal?)null;
        var comObs = brutos.Count(b => b.TemObservacao && PodeVer(b));

        return new ProgressoExercicio(
            exercicio.Id,
            exercicio.Nome,
            exercicio.Modalidade,
            RotuloMetrica(metrica.Value),
            pontos,
            new ResumoProgresso(pontos.Count, variacao, comObs));
    }

    /// <summary>
    /// Escolhe a grandeza do gráfico (PBI-73). Força: usa a carga só se houver
    /// alguma série com carga no período; sem carga, repetições. Isometria:
    /// tempo. Cardio (ou outra sem gráfico): nulo.
    /// </summary>
    private async Task<MetricaProgresso?> DecidirMetricaAsync(
        Guid atletaId,
        Guid exercicioId,
        string modalidade,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct)
    {
        if (modalidade == Modalidade.Isometria)
        {
            return MetricaProgresso.Tempo;
        }
        if (modalidade == Modalidade.Forca)
        {
            var temCarga = await _progresso.ExercicioTemCargaAsync(
                atletaId, exercicioId, de, ate, ct);
            return temCarga ? MetricaProgresso.Carga : MetricaProgresso.Repeticoes;
        }
        return null;
    }

    /// <summary>Rótulo da métrica no DTO, consumido pelo app para eixo/unidade.</summary>
    private static string RotuloMetrica(MetricaProgresso metrica) => metrica switch
    {
        MetricaProgresso.Carga => "CARGA",
        MetricaProgresso.Repeticoes => "REPETICOES",
        MetricaProgresso.Tempo => "TEMPO",
        _ => "CARGA",
    };
}
