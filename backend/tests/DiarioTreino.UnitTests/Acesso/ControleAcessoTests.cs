using DiarioTreino.Application.Acesso;

namespace DiarioTreino.UnitTests.Acesso;

public sealed class ControleAcessoTests
{
    // Fake de repositório: devolve se há vínculo ativo para o par informado.
    private sealed class RepositorioVinculoFake : IRepositorioVinculo
    {
        private readonly bool _temVinculoAtivo;

        public RepositorioVinculoFake(bool temVinculoAtivo)
        {
            _temVinculoAtivo = temVinculoAtivo;
        }

        public Task<bool> ExisteVinculoAtivoAsync(Guid educadorId, Guid alunoId, CancellationToken ct)
            => Task.FromResult(_temVinculoAtivo);
    }

    private static ControleAcesso Com(bool vinculoAtivo)
        => new(new RepositorioVinculoFake(vinculoAtivo));

    [Fact]
    public async Task Dono_pode_acessar_os_proprios_dados()
    {
        var atleta = Guid.NewGuid();
        var controle = Com(vinculoAtivo: false);

        var pode = await controle.PodeAcessarAtletaAsync(atleta, atleta, CancellationToken.None);

        Assert.True(pode);
    }

    [Fact]
    public async Task Educador_com_vinculo_ativo_pode_acessar()
    {
        var educador = Guid.NewGuid();
        var aluno = Guid.NewGuid();
        var controle = Com(vinculoAtivo: true);

        var pode = await controle.PodeAcessarAtletaAsync(educador, aluno, CancellationToken.None);

        Assert.True(pode);
    }

    [Fact]
    public async Task Educador_com_vinculo_encerrado_nao_pode_acessar()
    {
        var educador = Guid.NewGuid();
        var aluno = Guid.NewGuid();
        // Vínculo encerrado => repositório não encontra vínculo ATIVO.
        var controle = Com(vinculoAtivo: false);

        var pode = await controle.PodeAcessarAtletaAsync(educador, aluno, CancellationToken.None);

        Assert.False(pode);
    }

    [Fact]
    public async Task Terceiro_sem_vinculo_nao_pode_acessar()
    {
        var terceiro = Guid.NewGuid();
        var atleta = Guid.NewGuid();
        var controle = Com(vinculoAtivo: false);

        var pode = await controle.PodeAcessarAtletaAsync(terceiro, atleta, CancellationToken.None);

        Assert.False(pode);
    }

    [Fact]
    public async Task Garantir_acesso_lanca_recurso_nao_encontrado_para_terceiro()
    {
        var terceiro = Guid.NewGuid();
        var atleta = Guid.NewGuid();
        var controle = Com(vinculoAtivo: false);

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(
            () => controle.GarantirAcessoAtletaAsync(terceiro, atleta, CancellationToken.None));
    }

    [Fact]
    public async Task Garantir_acesso_nao_lanca_para_o_dono()
    {
        var atleta = Guid.NewGuid();
        var controle = Com(vinculoAtivo: false);

        // Não deve lançar.
        await controle.GarantirAcessoAtletaAsync(atleta, atleta, CancellationToken.None);
    }
}
