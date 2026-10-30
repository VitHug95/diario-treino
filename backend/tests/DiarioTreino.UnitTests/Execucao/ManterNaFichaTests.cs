using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Execucao;
using DiarioTreino.Domain.Planejamento;
using Fakes = DiarioTreino.UnitTests.Planejamento.ServicoPlanejamentoTests;

namespace DiarioTreino.UnitTests.Execucao;

/// <summary>
/// PBI-72: "Manter na ficha?" no <see cref="ServicoSessao.CriarSessaoAsync"/>.
/// Os exercícios mantidos entram no fim da ficha com as séries e o alvo da
/// última série; pedido inconsistente não grava nada.
/// </summary>
public sealed class ManterNaFichaTests
{
    private sealed class RepositorioSessaoFake : IRepositorioSessao
    {
        public readonly List<Sessao> Sessoes = [];
        public int Salvamentos;

        public void AdicionarSessao(Sessao sessao) => Sessoes.Add(sessao);

        public Task<(DateOnly Data, IReadOnlyList<SerieExecutada> Series)?> ObterUltimaExecucaoAsync(
            Guid atletaId, Guid exercicioId, CancellationToken ct)
            => Task.FromResult<(DateOnly, IReadOnlyList<SerieExecutada>)?>(null);

        public Task<IReadOnlyList<(Guid SessaoId, DateOnly Data, string? Observacao,
            bool ObservacaoPrivada, IReadOnlyList<SerieExecutada> Series)>> ObterHistoricoExercicioAsync(
            Guid atletaId, Guid exercicioId, int limite, CancellationToken ct)
            => Task.FromResult<IReadOnlyList<(Guid, DateOnly, string?, bool, IReadOnlyList<SerieExecutada>)>>([]);

        public Task<IReadOnlyList<SessaoResumo>> ListarPorPeriodoAsync(
            Guid atletaId, DateOnly? de, DateOnly? ate, CancellationToken ct)
            => Task.FromResult<IReadOnlyList<SessaoResumo>>([]);

        public Task<Guid?> ObterAtletaDaSessaoAsync(Guid sessaoId, CancellationToken ct)
            => Task.FromResult<Guid?>(null);

        public Task<Sessao?> ObterSessaoComSeriesAsync(Guid sessaoId, CancellationToken ct)
            => Task.FromResult<Sessao?>(null);

        public void RemoverSessao(Sessao sessao) { }
        public void RemoverSerie(SerieExecutada serie) { }
        public void AdicionarSerie(SerieExecutada serie) { }

        public Task SalvarAsync(CancellationToken ct)
        {
            Salvamentos++;
            return Task.CompletedTask;
        }
    }

    private static readonly Guid Supino = Guid.NewGuid();
    private static readonly Guid Agachamento = Guid.NewGuid();

    private sealed record Cenario(
        ServicoSessao Servico,
        Fakes.RepositorioPlanoFake Planos,
        RepositorioSessaoFake Sessoes,
        Guid AtletaId,
        Guid TreinoId,
        Guid TeSupino);

    private static Cenario Montar(bool doProfessor = false)
    {
        var atleta = Guid.NewGuid();
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AtletaId = atleta,
            AutorId = doProfessor ? Guid.NewGuid() : atleta,
            Nome = "Hipertrofia",
        };
        var teSupino = new TreinoExercicio
        {
            Id = Guid.NewGuid(), ExercicioId = Supino, Ordem = 1, Rodadas = 3,
        };
        var treino = new Treino
        {
            Id = Guid.NewGuid(), PlanoId = plano.Id, Nome = "B", Ordem = 1, Ativo = true,
            Exercicios = [teSupino],
        };
        teSupino.TreinoId = treino.Id;

        var planos = new Fakes.RepositorioPlanoFake
        {
            AtletaDoTreino = atleta,
            MaiorOrdemExercicio = 1,
        };
        planos.Planos.Add(plano);
        planos.Treinos.Add(treino);

        var sessoes = new RepositorioSessaoFake();
        var servico = new ServicoSessao(
            sessoes,
            planos,
            new ControleAcesso(new Fakes.RepositorioVinculoFake()),
            new Fakes.RepositorioExercicioFake(),
            new Fakes.RepositorioMetricaFake());
        return new Cenario(servico, planos, sessoes, atleta, treino.Id, teSupino.Id);
    }

    private static SerieRequest Serie(short rodada, decimal? carga, decimal volume,
        short intensidadeId = MetricaCodigos.CargaKg, short volumeId = MetricaCodigos.Repeticoes,
        short? descanso = 60) =>
        new(rodada, 1, TipoEtapa.Esforco, intensidadeId, carga, volumeId, volume, descanso);

    private static CriarSessaoRequest Pedido(Cenario c, IReadOnlyList<Guid>? manter,
        IReadOnlyList<SerieRequest>? seriesAgachamento = null) =>
        new(
            c.TreinoId,
            DateOnly.FromDateTime(DateTime.UtcNow.Date),
            40,
            null,
            [
                new ExercicioSessaoRequest(Supino, c.TeSupino, [Serie(1, 30, 10)]),
                new ExercicioSessaoRequest(Agachamento, null,
                    seriesAgachamento ?? [Serie(1, 18, 12), Serie(2, 20, 10, descanso: 90)]),
            ],
            manter);

    [Fact]
    public async Task Manter_poe_no_fim_com_as_series_e_o_alvo_da_ultima()
    {
        var c = Montar();

        await c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, [Agachamento]), CancellationToken.None);

        var te = Assert.Single(c.Planos.TreinoExercicios);
        Assert.Equal(c.TreinoId, te.TreinoId);
        Assert.Equal(Agachamento, te.ExercicioId);
        Assert.Equal((short)2, te.Ordem);   // depois do supino
        Assert.Equal((short)2, te.Rodadas); // duas séries salvas
        Assert.Equal((short)90, te.DescansoAlvoSeg);
        var etapa = Assert.Single(c.Planos.Etapas);
        Assert.Equal(te.Id, etapa.TreinoExercicioId);
        Assert.Equal(TipoEtapa.Esforco, etapa.Tipo);
        Assert.Equal(20m, etapa.IntensidadeAlvo);
        Assert.Equal(10m, etapa.VolumeAlvo);
        Assert.Null(etapa.VolumeAlvoMax);

        // Uma gravação só: sessão e ficha na mesma transação.
        Assert.Single(c.Sessoes.Sessoes);
        Assert.Equal(1, c.Sessoes.Salvamentos);
    }

    [Fact]
    public async Task Isometria_guarda_o_tempo_e_intensidade_livre()
    {
        var c = Montar();
        var pedido = Pedido(c, [Agachamento], seriesAgachamento:
        [
            Serie(1, null, 30, MetricaCodigos.PesoCorporal, MetricaCodigos.TempoSeg),
            Serie(2, null, 45, MetricaCodigos.PesoCorporal, MetricaCodigos.TempoSeg),
        ]);

        await c.Servico.CriarSessaoAsync(c.AtletaId, pedido, CancellationToken.None);

        var etapa = Assert.Single(c.Planos.Etapas);
        Assert.Equal(MetricaCodigos.PesoCorporal, etapa.IntensidadeMetricaId);
        Assert.Null(etapa.IntensidadeAlvo);
        Assert.Equal(MetricaCodigos.TempoSeg, etapa.VolumeMetricaId);
        Assert.Equal(45m, etapa.VolumeAlvo);
    }

    [Fact]
    public async Task Sem_manter_a_ficha_fica_igual()
    {
        var c = Montar();

        await c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, []), CancellationToken.None);
        await c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, null), CancellationToken.None);

        Assert.Empty(c.Planos.TreinoExercicios);
        Assert.Empty(c.Planos.Etapas);
        Assert.Equal(2, c.Sessoes.Sessoes.Count);
    }

    [Fact]
    public async Task Exercicio_que_nao_e_da_sessao_recusa_sem_gravar()
    {
        var c = Montar();

        await Assert.ThrowsAsync<ArgumentException>(() =>
            c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, [Guid.NewGuid()]), CancellationToken.None));

        Assert.Empty(c.Sessoes.Sessoes);
        Assert.Equal(0, c.Sessoes.Salvamentos);
        Assert.Empty(c.Planos.TreinoExercicios);
    }

    [Fact]
    public async Task Exercicio_da_ficha_ou_sem_series_recusa()
    {
        var c = Montar();

        await Assert.ThrowsAsync<ArgumentException>(() =>
            c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, [Supino]), CancellationToken.None));
        await Assert.ThrowsAsync<ArgumentException>(() =>
            c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, [Agachamento], seriesAgachamento: []),
                CancellationToken.None));

        Assert.Equal(0, c.Sessoes.Salvamentos);
    }

    [Fact]
    public async Task Ficha_do_professor_responde_somente_leitura()
    {
        var c = Montar(doProfessor: true);

        await Assert.ThrowsAsync<PlanoSomenteLeituraException>(() =>
            c.Servico.CriarSessaoAsync(c.AtletaId, Pedido(c, [Agachamento]), CancellationToken.None));

        Assert.Equal(0, c.Sessoes.Salvamentos);
        Assert.Empty(c.Planos.TreinoExercicios);
    }

    [Fact]
    public async Task Ficha_de_outro_usuario_responde_404_antes_de_tudo()
    {
        var c = Montar();
        var outro = Guid.NewGuid();

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            c.Servico.CriarSessaoAsync(outro, Pedido(c, [Agachamento]), CancellationToken.None));

        Assert.Equal(0, c.Sessoes.Salvamentos);
        Assert.Empty(c.Planos.TreinoExercicios);
    }
}
