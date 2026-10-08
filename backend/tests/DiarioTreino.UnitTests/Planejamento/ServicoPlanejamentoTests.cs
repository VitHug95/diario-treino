using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Planejamento;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.UnitTests.Planejamento;

public sealed class ServicoPlanejamentoTests
{
    private sealed class RepositorioPlanoFake : IRepositorioPlano
    {
        public PlanoTreino? PlanoAtivo;
        public readonly List<PlanoTreino> Planos = [];
        public readonly List<Treino> Treinos = [];
        public readonly List<TreinoExercicio> TreinoExercicios = [];
        public Guid? AtletaDoTreino;
        public short MaiorOrdem;
        public short MaiorOrdemExercicio;

        public Task<PlanoTreino?> ObterPlanoAtivoAsync(Guid atletaId, CancellationToken ct)
            => Task.FromResult(PlanoAtivo);

        public void AdicionarPlano(PlanoTreino plano)
        {
            Planos.Add(plano);
            PlanoAtivo = plano;
        }

        public void AdicionarTreino(Treino treino) => Treinos.Add(treino);

        public Task<Treino?> ObterTreinoAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(Treinos.FirstOrDefault(t => t.Id == treinoId));

        public Task<Guid?> ObterAtletaDoTreinoAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(AtletaDoTreino);

        public Task<short> ObterMaiorOrdemAsync(Guid planoId, CancellationToken ct)
            => Task.FromResult(MaiorOrdem);

        public Task<Treino?> ObterTreinoComExerciciosAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(Treinos.FirstOrDefault(t => t.Id == treinoId));

        public void AdicionarTreinoExercicio(TreinoExercicio te) => TreinoExercicios.Add(te);

        public void RemoverTreinoExercicio(TreinoExercicio te) => TreinoExercicios.Remove(te);

        public Task<TreinoExercicio?> ObterTreinoExercicioAsync(Guid id, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.FirstOrDefault(te => te.Id == id));

        public Task<List<TreinoExercicio>> ObterExerciciosDaFichaAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.Where(te => te.TreinoId == treinoId).ToList());

        public Task<short> ObterMaiorOrdemExercicioAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(MaiorOrdemExercicio);

        public Task<TreinoExercicio?> ObterTreinoExercicioComEtapasAsync(Guid id, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.FirstOrDefault(te => te.Id == id));

        public Task<(string Codigo, string Nome)?> ObterMetricaAsync(short metricaId, CancellationToken ct)
            => Task.FromResult<(string, string)?>(("COD", "Métrica"));

        public readonly List<EtapaPrescrita> Etapas = [];
        public void AdicionarEtapa(EtapaPrescrita etapa) => Etapas.Add(etapa);
        public void RemoverEtapa(EtapaPrescrita etapa) => Etapas.Remove(etapa);

        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;
    }

    // Métricas: eixo por faixa de id (1-3 intensidade, 10-12 volume).
    private sealed class RepositorioMetricaFake : IRepositorioMetrica
    {
        public Task<IReadOnlyList<MetricaResumo>> ListarAsync(CancellationToken ct)
            => Task.FromResult<IReadOnlyList<MetricaResumo>>([]);

        public Task<string?> ObterEixoAsync(short metricaId, CancellationToken ct)
        {
            string? eixo = metricaId switch
            {
                >= 1 and <= 3 => DiarioTreino.Domain.Comum.EixoMetrica.Intensidade,
                >= 10 and <= 12 => DiarioTreino.Domain.Comum.EixoMetrica.Volume,
                _ => null,
            };
            return Task.FromResult(eixo);
        }
    }

    private sealed class RepositorioVinculoFake : IRepositorioVinculo
    {
        public Task<bool> ExisteVinculoAtivoAsync(Guid e, Guid a, CancellationToken ct)
            => Task.FromResult(false);
    }

    // Repositório de exercício: só o necessário para o planejamento.
    private sealed class RepositorioExercicioFake : IRepositorioExercicio
    {
        public bool Disponivel = true;

        public Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
            Guid u, string? b, string? m, CancellationToken ct)
            => Task.FromResult<IReadOnlyList<ExercicioResumo>>([]);

        public Task<bool> ExisteNomeNoCatalogoAsync(Guid u, string n, CancellationToken ct)
            => Task.FromResult(false);

        public Task AdicionarAsync(DiarioTreino.Domain.Catalogo.Exercicio e, CancellationToken ct)
            => Task.CompletedTask;

        public Task<bool> ExisteDisponivelAsync(Guid exercicioId, Guid usuarioId, CancellationToken ct)
            => Task.FromResult(Disponivel);
    }

    private static ServicoPlanejamento Montar(
        RepositorioPlanoFake repo,
        RepositorioExercicioFake? exercicios = null)
        => new(
            repo,
            new ControleAcesso(new RepositorioVinculoFake()),
            exercicios ?? new RepositorioExercicioFake(),
            new RepositorioMetricaFake());

    [Fact]
    public async Task Primeira_ficha_cria_plano_com_autor_igual_atleta()
    {
        var repo = new RepositorioPlanoFake();
        var atleta = Guid.NewGuid();

        await Montar(repo).AdicionarFichaAsync(
            atleta, new SalvarTreinoRequest("A", "Peito"), CancellationToken.None);

        Assert.Single(repo.Planos);
        Assert.Equal(atleta, repo.Planos[0].AutorId);
        Assert.Equal(atleta, repo.Planos[0].AtletaId);
        Assert.Single(repo.Treinos);
        Assert.Equal("A", repo.Treinos[0].Nome);
    }

    [Fact]
    public async Task Ficha_recebe_ordem_seguinte()
    {
        var atleta = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            PlanoAtivo = new PlanoTreino { Id = Guid.NewGuid(), AtletaId = atleta, AutorId = atleta },
            MaiorOrdem = 2,
        };

        await Montar(repo).AdicionarFichaAsync(
            atleta, new SalvarTreinoRequest("C", null), CancellationToken.None);

        Assert.Equal((short)3, repo.Treinos.Single().Ordem);
    }

    [Fact]
    public async Task Editar_ficha_de_outro_usuario_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            Treinos = { new Treino { Id = treinoId, Nome = "A" } },
        };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).EditarFichaAsync(
                terceiro, treinoId, new SalvarTreinoRequest("X", null), CancellationToken.None));
    }

    [Fact]
    public async Task Arquivar_marca_ativo_falso_sem_remover()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var treino = new Treino { Id = treinoId, Nome = "A", Ativo = true };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            Treinos = { treino },
        };

        await Montar(repo).ArquivarFichaAsync(dono, treinoId, CancellationToken.None);

        Assert.False(treino.Ativo);
        Assert.Contains(treino, repo.Treinos);
    }

    [Fact]
    public async Task Arquivar_treino_inexistente_lanca_recurso_nao_encontrado()
    {
        var repo = new RepositorioPlanoFake { AtletaDoTreino = null };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).ArquivarFichaAsync(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Adicionar_exercicio_na_ficha_recebe_ordem_seguinte()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            MaiorOrdemExercicio = 1,
        };

        await Montar(repo).AdicionarExercicioAsync(
            dono, treinoId, Guid.NewGuid(), CancellationToken.None);

        var te = Assert.Single(repo.TreinoExercicios);
        Assert.Equal((short)2, te.Ordem);
        Assert.Equal(treinoId, te.TreinoId);
    }

    [Fact]
    public async Task Adicionar_exercicio_indisponivel_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var repo = new RepositorioPlanoFake { AtletaDoTreino = dono };
        var exercicios = new RepositorioExercicioFake { Disponivel = false };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo, exercicios).AdicionarExercicioAsync(
                dono, Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Reordenar_aplica_a_nova_ordem()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var a = new TreinoExercicio { Id = Guid.NewGuid(), TreinoId = treinoId, Ordem = 1 };
        var b = new TreinoExercicio { Id = Guid.NewGuid(), TreinoId = treinoId, Ordem = 2 };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { a, b },
        };

        // Inverte a ordem: b primeiro, a depois.
        await Montar(repo).ReordenarExerciciosAsync(
            dono, treinoId, [b.Id, a.Id], CancellationToken.None);

        Assert.Equal((short)1, b.Ordem);
        Assert.Equal((short)2, a.Ordem);
    }

    [Fact]
    public async Task Remover_exercicio_de_outro_usuario_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { new TreinoExercicio { Id = teId, TreinoId = treinoId } },
        };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).RemoverExercicioAsync(terceiro, teId, CancellationToken.None));
    }

    [Fact]
    public async Task Definir_alvos_grava_series_descanso_instrucao_e_etapa()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var te = new TreinoExercicio { Id = teId, TreinoId = treinoId, Rodadas = 1 };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { te },
        };

        await Montar(repo).DefinirAlvosAsync(
            dono, teId,
            new DefinirAlvosRequest(
                Series: 3,
                IntensidadeMetricaId: 1,  // CARGA_KG (intensidade)
                IntensidadeAlvo: 30,
                VolumeMetricaId: 10,      // REPETICOES (volume)
                VolumeAlvo: 10,
                DescansoSeg: 90,
                Instrucao: "descer devagar"),
            CancellationToken.None);

        Assert.Equal((short)3, te.Rodadas);
        Assert.Equal((short)90, te.DescansoAlvoSeg);
        Assert.Equal("descer devagar", te.Observacao);
        var etapa = Assert.Single(repo.Etapas);
        Assert.Equal(30m, etapa.IntensidadeAlvo);
        Assert.Equal(10m, etapa.VolumeAlvo);
    }

    [Fact]
    public async Task Definir_alvos_com_metrica_de_eixo_errado_lanca_argumento()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { new TreinoExercicio { Id = teId, TreinoId = Guid.NewGuid() } },
        };

        // Intensidade recebendo métrica de VOLUME (10).
        await Assert.ThrowsAsync<ArgumentException>(() =>
            Montar(repo).DefinirAlvosAsync(
                dono, teId,
                new DefinirAlvosRequest(3, 10, null, 10, null, null, null),
                CancellationToken.None));
    }

    [Fact]
    public async Task Definir_alvos_em_exercicio_de_outro_usuario_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { new TreinoExercicio { Id = teId, TreinoId = Guid.NewGuid() } },
        };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).DefinirAlvosAsync(
                terceiro, teId,
                new DefinirAlvosRequest(3, 1, 30, 10, 10, 90, null),
                CancellationToken.None));
    }
}
