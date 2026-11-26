using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Educador;
using DiarioTreino.Domain.Educador;
using DiarioTreino.UnitTests.Educador;
using DiarioTreino.Domain.Vinculos;

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

        // Membros não usados neste teste de controle de acesso (PBI-85).
        public Task<bool> ExisteVinculoAbertoAsync(Guid educadorId, Guid alunoId, CancellationToken ct)
            => Task.FromResult(false);

        public Task<Vinculo?> ObterPorIdAsync(Guid id, CancellationToken ct)
            => Task.FromResult<Vinculo?>(null);

        public Task<List<Vinculo>> ListarPendentesDoAlunoAsync(Guid alunoId, CancellationToken ct)
            => Task.FromResult(new List<Vinculo>());

        public Task<List<Vinculo>> ListarAtivosDoEducadorAsync(Guid educadorId, CancellationToken ct)
            => Task.FromResult(new List<Vinculo>());

        public Task<List<Vinculo>> ListarAtivosDoAlunoAsync(Guid alunoId, CancellationToken ct)
            => Task.FromResult(new List<Vinculo>());

        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;

        public Task<bool> TentarCriarAsync(Vinculo vinculo, CancellationToken ct)
            => Task.FromResult(true);
    }

    private static ControleAcesso Com(bool vinculoAtivo)
        => new(new RepositorioVinculoFake(vinculoAtivo), new RepositorioEducadorCrefFake(), new ConfiguracaoEducador(false));

    // ---- Trava do CREF (PBI-106) ----

    private static ControleAcesso ComCref(bool vinculoAtivo, Guid? habilitado)
    {
        var cref = new RepositorioEducadorCrefFake();
        if (habilitado is { } id)
        {
            cref.Habilitados.Add(new EducadorCref { UsuarioId = id, Origem = OrigemCref.Legado });
        }
        return new(new RepositorioVinculoFake(vinculoAtivo), cref, new ConfiguracaoEducador(true));
    }

    [Fact]
    public async Task Com_a_chave_ligada_educador_sem_cref_recebe_403_e_nao_pode()
    {
        var educador = Guid.NewGuid();
        var controle = ComCref(vinculoAtivo: true, habilitado: null);

        Assert.False(await controle.PodeAcessarAtletaAsync(educador, Guid.NewGuid(), CancellationToken.None));
        await Assert.ThrowsAsync<EducadorNaoHabilitadoException>(() =>
            controle.GarantirAcessoAtletaAsync(educador, Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Com_a_chave_ligada_sem_vinculo_continua_404_antes_da_trava()
    {
        var controle = ComCref(vinculoAtivo: false, habilitado: null);

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            controle.GarantirAcessoAtletaAsync(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Com_a_chave_ligada_educador_habilitado_e_o_proprio_atleta_passam()
    {
        var educador = Guid.NewGuid();
        var atleta = Guid.NewGuid();
        var controle = ComCref(vinculoAtivo: true, habilitado: educador);

        await controle.GarantirAcessoAtletaAsync(educador, atleta, CancellationToken.None);
        await ComCref(vinculoAtivo: false, habilitado: null)
            .GarantirAcessoAtletaAsync(atleta, atleta, CancellationToken.None);
    }

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
