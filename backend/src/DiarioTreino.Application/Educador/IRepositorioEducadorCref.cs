using DiarioTreino.Domain.Educador;

namespace DiarioTreino.Application.Educador;

public interface IRepositorioEducadorCref
{
    public Task<EducadorCref?> ObterAsync(Guid usuarioId, CancellationToken ct);

    /// <summary>Verdadeiro se o usuário foi habilitado (automática ou legado). Base da trava.</summary>
    public Task<bool> HabilitadoAsync(Guid usuarioId, CancellationToken ct);

    /// <summary>O registro (UF + número normalizado) já habilitou outra conta?</summary>
    public Task<bool> RegistroUsadoPorOutroAsync(string uf, string numero, Guid usuarioId, CancellationToken ct);

    /// <summary>Tentativas que contam para o limite (todas menos INDISPONIVEL) desde o instante.</summary>
    public Task<int> ContarTentativasAsync(Guid usuarioId, DateTimeOffset desde, CancellationToken ct);

    public void AdicionarTentativa(TentativaCref tentativa);

    public void Adicionar(EducadorCref educador);

    public void AdicionarFoto(FotoCarteiraCref foto);

    /// <summary>
    /// Salva tudo numa transação. Devolve <c>false</c> se o registro colidiu no
    /// índice único (outra conta se habilitou com ele ao mesmo tempo).
    /// </summary>
    public Task<bool> TentarSalvarAsync(CancellationToken ct);
}
