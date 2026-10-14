namespace DiarioTreino.Application.Catalogo;

/// <summary>Consultas das tabelas de referência de membro e músculo (PBI-31).</summary>
public interface IRepositorioMembro
{
    /// <summary>Membros na ordem dos chips, cada um com seus músculos.</summary>
    public Task<IReadOnlyList<MembroResumo>> ListarAsync(CancellationToken ct);

    /// <summary>O membro existe?</summary>
    public Task<bool> ExisteMembroAsync(short membroId, CancellationToken ct);

    /// <summary>O músculo existe E pertence ao membro informado?</summary>
    public Task<bool> MusculoPertenceAoMembroAsync(
        short musculoId, short membroId, CancellationToken ct);
}
