using DiarioTreino.Application.Comum;
using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Application.Catalogo;

/// <summary>Casos de uso do catálogo de exercícios (PBI-10 e PBI-11).</summary>
public sealed class ServicoCatalogo
{
    private readonly IRepositorioExercicio _repositorio;
    private readonly IRepositorioMetrica _metricas;
    private readonly IRepositorioMembro _membros;

    public ServicoCatalogo(
        IRepositorioExercicio repositorio,
        IRepositorioMetrica metricas,
        IRepositorioMembro membros)
    {
        _repositorio = repositorio;
        _metricas = metricas;
        _membros = membros;
    }

    public async Task<IReadOnlyList<ExercicioResumo>> ListarAsync(
        Guid usuarioId,
        string? busca,
        string? modalidade,
        short? membroId,
        CancellationToken ct)
    {
        var modalidadeNormalizada = NormalizarModalidade(modalidade);
        var buscaNormalizada = string.IsNullOrWhiteSpace(busca) ? null : busca.Trim();

        return await _repositorio.BuscarAsync(
            usuarioId,
            buscaNormalizada,
            modalidadeNormalizada,
            membroId,
            ct);
    }

    /// <summary>Membros com seus músculos, para os chips e o cadastro (PBI-31).</summary>
    public Task<IReadOnlyList<MembroResumo>> ListarMembrosAsync(CancellationToken ct) =>
        _membros.ListarAsync(ct);

    /// <summary>
    /// Aceita vazio/"TODOS" como "sem filtro" (null). Qualquer outro valor
    /// precisa ser uma modalidade válida.
    /// </summary>
    private static string? NormalizarModalidade(string? modalidade)
    {
        if (string.IsNullOrWhiteSpace(modalidade))
        {
            return null;
        }

        var valor = modalidade.Trim().ToUpperInvariant();
        if (valor == "TODOS")
        {
            return null;
        }

        if (!Modalidade.Todos.Contains(valor))
        {
            throw new ArgumentException(
                $"Modalidade inválida: '{modalidade}'. Use Força, Isometria, Cardio ou Todos.",
                nameof(modalidade));
        }

        return valor;
    }

    /// <summary>Métricas disponíveis para o usuário escolher (PBI-11, tela 9).</summary>
    public Task<IReadOnlyList<MetricaResumo>> ListarMetricasAsync(CancellationToken ct) =>
        _metricas.ListarAsync(ct);

    /// <summary>
    /// Cria um exercício próprio do usuário (PBI-11). Garante: modalidade válida,
    /// métricas no eixo correto (intensidade em INTENSIDADE, volume em VOLUME —
    /// MER 5.7) e nome não repetido no catálogo do próprio usuário.
    /// </summary>
    public async Task<Guid> CriarAsync(
        Guid usuarioId,
        CriarExercicioRequest request,
        CancellationToken ct)
    {
        var modalidade = request.Modalidade.Trim().ToUpperInvariant();
        if (!Modalidade.Todos.Contains(modalidade))
        {
            throw new ArgumentException("Modalidade inválida.", nameof(request));
        }

        await ValidarEixoAsync(request.IntensidadeMetricaId, EixoMetrica.Intensidade, ct);
        await ValidarEixoAsync(request.VolumeMetricaId, EixoMetrica.Volume, ct);

        // Membro obrigatório; músculo opcional, mas tem de pertencer ao membro
        // (a FK composta do banco também protege, mas validamos antes para dar
        // mensagem clara, não erro de constraint).
        if (!await _membros.ExisteMembroAsync(request.MembroId, ct))
        {
            throw new ArgumentException("Membro inválido.", nameof(request));
        }
        if (request.MusculoId is { } musculoId &&
            !await _membros.MusculoPertenceAoMembroAsync(musculoId, request.MembroId, ct))
        {
            throw new ArgumentException(
                "O músculo escolhido não pertence ao membro.", nameof(request));
        }

        var nome = request.Nome.Trim();
        if (await _repositorio.ExisteNomeNoCatalogoAsync(usuarioId, nome, ct))
        {
            throw new ConflitoException(
                $"Você já tem um exercício chamado \"{nome}\".");
        }

        var exercicio = new Exercicio
        {
            Id = Guid.NewGuid(),
            Nome = nome,
            MembroId = request.MembroId,
            MusculoId = request.MusculoId,
            GrupoMuscular = string.IsNullOrWhiteSpace(request.GrupoMuscular)
                ? null
                : request.GrupoMuscular.Trim(),
            Modalidade = modalidade,
            IntensidadeMetricaPadraoId = request.IntensidadeMetricaId,
            VolumeMetricaPadraoId = request.VolumeMetricaId,
            CriadoPorId = usuarioId,
            Ativo = true,
        };

        await _repositorio.AdicionarAsync(exercicio, ct);
        return exercicio.Id;
    }

    private async Task ValidarEixoAsync(short metricaId, string eixoEsperado, CancellationToken ct)
    {
        var eixo = await _metricas.ObterEixoAsync(metricaId, ct);
        if (eixo is null)
        {
            throw new ArgumentException($"Métrica {metricaId} não existe.");
        }
        if (eixo != eixoEsperado)
        {
            throw new ArgumentException(
                $"A métrica {metricaId} não é do eixo {eixoEsperado}.");
        }
    }
}
