using DiarioTreino.Application.Catalogo;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.UnitTests.Catalogo;

public sealed class ServicoCatalogoTests
{
    // Captura os argumentos repassados ao repositório, para checar a normalização.
    private sealed class RepositorioExercicioFake : IRepositorioExercicio
    {
        public string? BuscaRecebida { get; private set; }
        public string? ModalidadeRecebida { get; private set; }
        public bool Chamado { get; private set; }

        public Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
            Guid usuarioId, string? busca, string? modalidade, CancellationToken ct)
        {
            Chamado = true;
            BuscaRecebida = busca;
            ModalidadeRecebida = modalidade;
            return Task.FromResult<IReadOnlyList<ExercicioResumo>>([]);
        }
    }

    [Fact]
    public async Task Modalidade_vazia_vira_sem_filtro()
    {
        var repo = new RepositorioExercicioFake();
        var servico = new ServicoCatalogo(repo);

        await servico.ListarAsync(Guid.NewGuid(), null, "", CancellationToken.None);

        Assert.Null(repo.ModalidadeRecebida);
    }

    [Fact]
    public async Task Modalidade_todos_vira_sem_filtro()
    {
        var repo = new RepositorioExercicioFake();
        var servico = new ServicoCatalogo(repo);

        await servico.ListarAsync(Guid.NewGuid(), null, "Todos", CancellationToken.None);

        Assert.Null(repo.ModalidadeRecebida);
    }

    [Fact]
    public async Task Modalidade_valida_e_normalizada_para_maiusculas()
    {
        var repo = new RepositorioExercicioFake();
        var servico = new ServicoCatalogo(repo);

        await servico.ListarAsync(Guid.NewGuid(), null, "cardio", CancellationToken.None);

        Assert.Equal(Modalidade.Cardio, repo.ModalidadeRecebida);
    }

    [Fact]
    public async Task Modalidade_invalida_lanca_argumento()
    {
        var servico = new ServicoCatalogo(new RepositorioExercicioFake());

        await Assert.ThrowsAsync<ArgumentException>(
            () => servico.ListarAsync(Guid.NewGuid(), null, "xpto", CancellationToken.None));
    }

    [Fact]
    public async Task Busca_em_branco_vira_nula()
    {
        var repo = new RepositorioExercicioFake();
        var servico = new ServicoCatalogo(repo);

        await servico.ListarAsync(Guid.NewGuid(), "   ", null, CancellationToken.None);

        Assert.Null(repo.BuscaRecebida);
    }
}
