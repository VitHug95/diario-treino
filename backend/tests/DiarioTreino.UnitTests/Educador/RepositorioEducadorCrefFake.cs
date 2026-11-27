using DiarioTreino.Application.Educador;
using DiarioTreino.Domain.Educador;

namespace DiarioTreino.UnitTests.Educador;

/// <summary>Repositório do CREF em memória (PBI-106).</summary>
internal sealed class RepositorioEducadorCrefFake : IRepositorioEducadorCref
{
    public List<EducadorCref> Habilitados { get; } = [];
    public List<TentativaCref> Tentativas { get; } = [];
    private readonly List<EducadorCref> _pendentes = [];
    private readonly List<TentativaCref> _tentativasPendentes = [];

    /// <summary>Simula a colisão do índice único no SaveChanges.</summary>
    public bool ColidirAoSalvar { get; set; }
    public int Salvamentos { get; private set; }

    /// <summary>Sem nenhuma habilitação e com a chave desligada: o comportamento antigo.</summary>
    public static (RepositorioEducadorCrefFake, ConfiguracaoEducador) Desligado() =>
        (new RepositorioEducadorCrefFake(), new ConfiguracaoEducador(ExigirCref: false));

    public Task<EducadorCref?> ObterAsync(Guid usuarioId, CancellationToken ct) =>
        Task.FromResult(Habilitados.FirstOrDefault(e => e.UsuarioId == usuarioId));

    public Task<bool> HabilitadoAsync(Guid usuarioId, CancellationToken ct) =>
        Task.FromResult(Habilitados.Any(e => e.UsuarioId == usuarioId));

    public Task<bool> RegistroUsadoPorOutroAsync(string uf, string numero, Guid usuarioId, CancellationToken ct) =>
        Task.FromResult(Habilitados.Any(e => e.Uf == uf && e.Numero == numero && e.UsuarioId != usuarioId));

    public Task<int> ContarTentativasAsync(Guid usuarioId, DateTimeOffset desde, CancellationToken ct) =>
        Task.FromResult(Tentativas.Count(t =>
            t.UsuarioId == usuarioId && t.Em >= desde && t.Resultado != ResultadoCref.Indisponivel));

    public void AdicionarTentativa(TentativaCref tentativa) => _tentativasPendentes.Add(tentativa);

    public void Adicionar(EducadorCref educador) => _pendentes.Add(educador);

    public List<FotoCarteiraCref> Fotos { get; } = [];
    private readonly List<FotoCarteiraCref> _fotosPendentes = [];

    public void AdicionarFoto(FotoCarteiraCref foto) => _fotosPendentes.Add(foto);

    public Task<bool> TentarSalvarAsync(CancellationToken ct)
    {
        Salvamentos++;
        if (ColidirAoSalvar)
        {
            _pendentes.Clear();
            _tentativasPendentes.Clear();
            _fotosPendentes.Clear();
            return Task.FromResult(false);
        }
        Habilitados.AddRange(_pendentes);
        Tentativas.AddRange(_tentativasPendentes);
        Fotos.AddRange(_fotosPendentes);
        _fotosPendentes.Clear();
        _pendentes.Clear();
        _tentativasPendentes.Clear();
        return Task.FromResult(true);
    }
}
