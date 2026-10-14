using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Comum;
using DiarioTreino.Domain.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.UnitTests.Catalogo;

public sealed class ServicoCatalogoTests
{
    // Captura os argumentos repassados ao repositório e simula persistência.
    private sealed class RepositorioExercicioFake : IRepositorioExercicio
    {
        public string? BuscaRecebida { get; private set; }
        public string? ModalidadeRecebida { get; private set; }
        public short? MembroRecebido { get; private set; }
        public bool NomeJaExiste { get; set; }
        public Exercicio? Adicionado { get; private set; }

        public Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
            Guid usuarioId, string? busca, string? modalidade, short? membroId, CancellationToken ct)
        {
            BuscaRecebida = busca;
            ModalidadeRecebida = modalidade;
            MembroRecebido = membroId;
            return Task.FromResult<IReadOnlyList<ExercicioResumo>>([]);
        }

        public Task<bool> ExisteNomeNoCatalogoAsync(Guid usuarioId, string nome, CancellationToken ct)
            => Task.FromResult(NomeJaExiste);

        public Task AdicionarAsync(Exercicio exercicio, CancellationToken ct)
        {
            Adicionado = exercicio;
            return Task.CompletedTask;
        }

        public Task<bool> ExisteDisponivelAsync(Guid exercicioId, Guid usuarioId, CancellationToken ct)
            => Task.FromResult(true);

        public Task<IReadOnlyDictionary<Guid, ExercicioBasico>> ObterBasicosPorIdsAsync(
            IReadOnlyCollection<Guid> ids, CancellationToken ct)
            => Task.FromResult<IReadOnlyDictionary<Guid, ExercicioBasico>>(
                new Dictionary<Guid, ExercicioBasico>());

        public Task<ExercicioParaRascunho?> ObterParaRascunhoAsync(
            Guid exercicioId, Guid usuarioId, CancellationToken ct)
            => Task.FromResult<ExercicioParaRascunho?>(null);
    }

    private sealed class RepositorioMetricaFake : IRepositorioMetrica
    {
        public Task<IReadOnlyList<MetricaResumo>> ListarAsync(CancellationToken ct)
            => Task.FromResult<IReadOnlyList<MetricaResumo>>([]);

        // Devolve o eixo conforme a faixa de id do MER (1-3 intensidade, 10+ volume).
        public Task<string?> ObterEixoAsync(short metricaId, CancellationToken ct)
        {
            string? eixo = metricaId switch
            {
                >= 1 and <= 3 => EixoMetrica.Intensidade,
                >= 10 and <= 12 => EixoMetrica.Volume,
                _ => null,
            };
            return Task.FromResult(eixo);
        }
    }

    // Membro válido = qualquer id 1..8; músculo pertence quando (musculo,membro)
    // está no conjunto conhecido (ex.: 1/1 = Peitoral/Peito).
    private sealed class RepositorioMembroFake : IRepositorioMembro
    {
        public Task<IReadOnlyList<MembroResumo>> ListarAsync(CancellationToken ct)
            => Task.FromResult<IReadOnlyList<MembroResumo>>([]);

        public Task<bool> ExisteMembroAsync(short membroId, CancellationToken ct)
            => Task.FromResult(membroId is >= 1 and <= 8);

        public Task<bool> MusculoPertenceAoMembroAsync(short musculoId, short membroId, CancellationToken ct)
            => Task.FromResult(musculoId == 1 && membroId == 1);
    }

    private static ServicoCatalogo Montar(RepositorioExercicioFake? repo = null)
        => new(
            repo ?? new RepositorioExercicioFake(),
            new RepositorioMetricaFake(),
            new RepositorioMembroFake());

    private static CriarExercicioRequest RequisicaoValida() => new(
        Nome: "Rosca direta",
        MembroId: MembroCodigos.Bracos,
        MusculoId: null,
        Modalidade: Modalidade.Forca,
        IntensidadeMetricaId: MetricaCodigos.CargaKg,
        VolumeMetricaId: MetricaCodigos.Repeticoes);

    [Fact]
    public async Task Modalidade_vazia_vira_sem_filtro()
    {
        var repo = new RepositorioExercicioFake();
        await Montar(repo).ListarAsync(Guid.NewGuid(), null, "", null, CancellationToken.None);
        Assert.Null(repo.ModalidadeRecebida);
    }

    [Fact]
    public async Task Modalidade_todos_vira_sem_filtro()
    {
        var repo = new RepositorioExercicioFake();
        await Montar(repo).ListarAsync(Guid.NewGuid(), null, "Todos", null, CancellationToken.None);
        Assert.Null(repo.ModalidadeRecebida);
    }

    [Fact]
    public async Task Modalidade_valida_e_normalizada_para_maiusculas()
    {
        var repo = new RepositorioExercicioFake();
        await Montar(repo).ListarAsync(Guid.NewGuid(), null, "cardio", null, CancellationToken.None);
        Assert.Equal(Modalidade.Cardio, repo.ModalidadeRecebida);
    }

    [Fact]
    public async Task Modalidade_invalida_lanca_argumento()
    {
        await Assert.ThrowsAsync<ArgumentException>(
            () => Montar().ListarAsync(Guid.NewGuid(), null, "xpto", null, CancellationToken.None));
    }

    [Fact]
    public async Task Busca_em_branco_vira_nula()
    {
        var repo = new RepositorioExercicioFake();
        await Montar(repo).ListarAsync(Guid.NewGuid(), "   ", null, null, CancellationToken.None);
        Assert.Null(repo.BuscaRecebida);
    }

    [Fact]
    public async Task Criar_persiste_exercicio_do_proprio_usuario()
    {
        var repo = new RepositorioExercicioFake();
        var usuario = Guid.NewGuid();

        var id = await Montar(repo).CriarAsync(usuario, RequisicaoValida(), CancellationToken.None);

        Assert.NotNull(repo.Adicionado);
        Assert.Equal(usuario, repo.Adicionado!.CriadoPorId);
        Assert.Equal(id, repo.Adicionado.Id);
        Assert.Equal("Rosca direta", repo.Adicionado.Nome);
    }

    [Fact]
    public async Task Criar_com_nome_repetido_lanca_conflito()
    {
        var repo = new RepositorioExercicioFake { NomeJaExiste = true };

        await Assert.ThrowsAsync<ConflitoException>(
            () => Montar(repo).CriarAsync(Guid.NewGuid(), RequisicaoValida(), CancellationToken.None));
    }

    [Fact]
    public async Task Criar_com_metrica_de_intensidade_no_eixo_errado_lanca_argumento()
    {
        // Passa uma métrica de VOLUME (repetições) no campo de intensidade.
        var request = RequisicaoValida() with { IntensidadeMetricaId = MetricaCodigos.Repeticoes };

        await Assert.ThrowsAsync<ArgumentException>(
            () => Montar().CriarAsync(Guid.NewGuid(), request, CancellationToken.None));
    }

    [Fact]
    public async Task Criar_com_metrica_inexistente_lanca_argumento()
    {
        var request = RequisicaoValida() with { VolumeMetricaId = 99 };

        await Assert.ThrowsAsync<ArgumentException>(
            () => Montar().CriarAsync(Guid.NewGuid(), request, CancellationToken.None));
    }
}
