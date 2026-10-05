using DiarioTreino.Application.Acesso;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Vinculos;
using DiarioTreino.IntegrationTests.Infraestrutura;
using Microsoft.Extensions.DependencyInjection;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// Exercita a regra do MAS 11.3 ponta a ponta contra o Postgres real, com os
/// vínculos lidos do banco. Resolve o <see cref="IControleAcesso"/> do mesmo
/// contêiner de DI usado pela API.
/// </summary>
[Collection(PostgresCollection.Nome)]
public sealed class ControleAcessoIntegracaoTests
{
    private readonly PostgresFixture _postgres;

    public ControleAcessoIntegracaoTests(PostgresFixture postgres)
    {
        _postgres = postgres;
    }

    [Fact]
    public async Task Educador_com_vinculo_ativo_no_banco_pode_acessar_o_aluno()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var (educador, aluno) = await SemearVinculoAsync(StatusVinculo.Ativo);

        var pode = await ResolverEExecutar(api, educador, aluno);

        Assert.True(pode);
    }

    [Fact]
    public async Task Educador_com_vinculo_encerrado_no_banco_nao_pode_acessar()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var (educador, aluno) = await SemearVinculoAsync(StatusVinculo.Encerrado);

        var pode = await ResolverEExecutar(api, educador, aluno);

        Assert.False(pode);
    }

    [Fact]
    public async Task Terceiro_sem_vinculo_nao_pode_acessar_e_garantir_responde_404()
    {
        await using var api = new ApiFactory(_postgres.ConnectionString);
        var terceiro = Guid.NewGuid();
        var atleta = Guid.NewGuid();

        using var escopo = api.Services.CreateScope();
        var controle = escopo.ServiceProvider.GetRequiredService<IControleAcesso>();

        Assert.False(await controle.PodeAcessarAtletaAsync(terceiro, atleta, CancellationToken.None));
        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(
            () => controle.GarantirAcessoAtletaAsync(terceiro, atleta, CancellationToken.None));
    }

    private static async Task<bool> ResolverEExecutar(ApiFactory api, Guid logado, Guid atleta)
    {
        using var escopo = api.Services.CreateScope();
        var controle = escopo.ServiceProvider.GetRequiredService<IControleAcesso>();
        return await controle.PodeAcessarAtletaAsync(logado, atleta, CancellationToken.None);
    }

    private async Task<(Guid educador, Guid aluno)> SemearVinculoAsync(string status)
    {
        await using var db = _postgres.CriarContexto();

        var educador = NovoUsuario("edu");
        var aluno = NovoUsuario("alu");
        educador.Papeis.Add(new UsuarioPapel { UsuarioId = educador.Id, Papel = Papeis.Educador });
        db.Usuarios.Add(educador);
        db.Usuarios.Add(aluno);

        db.Vinculos.Add(new Vinculo
        {
            Id = Guid.NewGuid(),
            EducadorId = educador.Id,
            AlunoId = aluno.Id,
            Status = status,
            Inicio = DateTimeOffset.UtcNow,
            Fim = status == StatusVinculo.Encerrado ? DateTimeOffset.UtcNow : null,
        });

        await db.SaveChangesAsync();
        return (educador.Id, aluno.Id);
    }

    private static Usuario NovoUsuario(string prefixo)
    {
        var id = Guid.NewGuid();
        return new Usuario
        {
            Id = id,
            FirebaseUid = $"{prefixo}-{id:n}",
            Nome = prefixo,
            Email = $"{prefixo}-{id:n}@teste.local",
            Papeis = [],
        };
    }
}
