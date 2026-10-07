using DiarioTreino.Application.Acesso;
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
        public Guid? AtletaDoTreino;
        public short MaiorOrdem;

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

        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;
    }

    // Controle de acesso real, com um repositório de vínculo fake.
    private sealed class RepositorioVinculoFake : IRepositorioVinculo
    {
        public Task<bool> ExisteVinculoAtivoAsync(Guid e, Guid a, CancellationToken ct)
            => Task.FromResult(false);
    }

    private static ServicoPlanejamento Montar(RepositorioPlanoFake repo)
        => new(repo, new ControleAcesso(new RepositorioVinculoFake()));

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
        Assert.Contains(treino, repo.Treinos); // continua no repositório
    }

    [Fact]
    public async Task Arquivar_treino_inexistente_lanca_recurso_nao_encontrado()
    {
        var repo = new RepositorioPlanoFake { AtletaDoTreino = null };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).ArquivarFichaAsync(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
    }
}
