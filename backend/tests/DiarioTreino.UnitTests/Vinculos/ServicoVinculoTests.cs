using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Educador;
using DiarioTreino.Application.Vinculos;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Identidade;
using DiarioTreino.Domain.Vinculos;

namespace DiarioTreino.UnitTests.Vinculos;

/// <summary>PBI-104: <see cref="ServicoVinculo.ListarEducadoresAtivosAsync"/>.</summary>
public sealed class ServicoVinculoTests
{
    private sealed class VinculosFake : IRepositorioVinculo
    {
        public List<Vinculo> Ativos { get; } = [];

        public Task<List<Vinculo>> ListarAtivosDoAlunoAsync(Guid alunoId, CancellationToken ct)
            => Task.FromResult(Ativos.Where(v => v.AlunoId == alunoId).ToList());

        public Task<bool> ExisteVinculoAtivoAsync(Guid educadorId, Guid alunoId, CancellationToken ct)
            => Task.FromResult(false);
        public Task<bool> ExisteVinculoAbertoAsync(Guid educadorId, Guid alunoId, CancellationToken ct)
            => Task.FromResult(false);
        public Task<Vinculo?> ObterPorIdAsync(Guid id, CancellationToken ct)
            => Task.FromResult<Vinculo?>(null);
        public Task<List<Vinculo>> ListarPendentesDoAlunoAsync(Guid alunoId, CancellationToken ct)
            => Task.FromResult(new List<Vinculo>());
        public Task<List<Vinculo>> ListarAtivosDoEducadorAsync(Guid educadorId, CancellationToken ct)
            => Task.FromResult(new List<Vinculo>());
        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;
        public Task<bool> TentarCriarAsync(Vinculo vinculo, CancellationToken ct) => Task.FromResult(true);
    }

    private sealed class UsuariosFake : IRepositorioUsuario
    {
        public Dictionary<Guid, Usuario> PorId { get; } = [];

        public Task<Usuario?> ObterPorIdAsync(Guid id, CancellationToken ct)
            => Task.FromResult(PorId.GetValueOrDefault(id));

        public Task<Usuario?> ObterPorFirebaseUidAsync(string firebaseUid, CancellationToken ct)
            => Task.FromResult<Usuario?>(null);
        public Task<Usuario?> ObterPorEmailAsync(string email, CancellationToken ct)
            => Task.FromResult<Usuario?>(null);
        public void Adicionar(Usuario usuario) { }
        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;
        public Task<bool> TentarInserirUsuarioAsync(Usuario usuario, CancellationToken ct) => Task.FromResult(true);
        public Task ExcluirContaAsync(Guid usuarioId, CancellationToken ct) => Task.CompletedTask;
    }

    private sealed class ConsentimentosFake : IRepositorioConsentimento
    {
        public Task RegistrarSeAusenteAsync(Guid usuarioId, string versaoTermo, CancellationToken ct)
            => Task.CompletedTask;
        public Task<bool> ExisteAsync(Guid usuarioId, string versaoTermo, CancellationToken ct)
            => Task.FromResult(false);
    }

    private static Usuario Educador(string nome) =>
        new() { Id = Guid.NewGuid(), Nome = nome, Email = $"{nome.ToLowerInvariant()}@x.dev", FirebaseUid = nome };

    [Fact]
    public async Task Mapeia_nome_email_e_desde_do_mais_recente_ao_mais_antigo()
    {
        var aluno = Guid.NewGuid();
        var vinculos = new VinculosFake();
        var usuarios = new UsuariosFake();
        var ana = Educador("Ana");
        var bia = Educador("Bia");
        usuarios.PorId[ana.Id] = ana;
        usuarios.PorId[bia.Id] = bia;
        var inicioAna = new DateTimeOffset(2026, 10, 12, 13, 0, 0, TimeSpan.Zero);
        var inicioBia = new DateTimeOffset(2026, 11, 2, 9, 0, 0, TimeSpan.Zero);
        var vAna = new Vinculo { Id = Guid.NewGuid(), EducadorId = ana.Id, AlunoId = aluno, Status = StatusVinculo.Ativo, Inicio = inicioAna };
        var vBia = new Vinculo { Id = Guid.NewGuid(), EducadorId = bia.Id, AlunoId = aluno, Status = StatusVinculo.Ativo, Inicio = inicioBia };
        vinculos.Ativos.AddRange([vAna, vBia]);

        var servico = new ServicoVinculo(vinculos, usuarios, new ConsentimentosFake(), new DiarioTreino.UnitTests.Educador.RepositorioEducadorCrefFake(), new ConfiguracaoEducador(false));
        var lista = await servico.ListarEducadoresAtivosAsync(aluno, CancellationToken.None);

        Assert.Equal(
            [
                new EducadorVinculado(vBia.Id, bia.Id, "Bia", "bia@x.dev", inicioBia),
                new EducadorVinculado(vAna.Id, ana.Id, "Ana", "ana@x.dev", inicioAna),
            ],
            lista);
    }

    [Fact]
    public async Task Ignora_educador_que_nao_existe_mais()
    {
        var aluno = Guid.NewGuid();
        var vinculos = new VinculosFake();
        vinculos.Ativos.Add(new Vinculo
        {
            Id = Guid.NewGuid(), EducadorId = Guid.NewGuid(), AlunoId = aluno,
            Status = StatusVinculo.Ativo, Inicio = DateTimeOffset.UtcNow,
        });

        var servico = new ServicoVinculo(vinculos, new UsuariosFake(), new ConsentimentosFake(), new DiarioTreino.UnitTests.Educador.RepositorioEducadorCrefFake(), new ConfiguracaoEducador(false));

        Assert.Empty(await servico.ListarEducadoresAtivosAsync(aluno, CancellationToken.None));
    }
}
