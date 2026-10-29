using DiarioTreino.Domain.Vinculos;

namespace DiarioTreino.Application.Acesso;

/// <summary>Acesso de persistência ao vínculo educador-aluno (MER 3.3).</summary>
public interface IRepositorioVinculo
{
    /// <summary>
    /// Verdadeiro se existe vínculo ATIVO entre o educador e o aluno informados.
    /// </summary>
    public Task<bool> ExisteVinculoAtivoAsync(
        Guid educadorId,
        Guid alunoId,
        CancellationToken ct);

    /// <summary>
    /// Verdadeiro se já existe vínculo ABERTO (PENDENTE ou ATIVO) entre o
    /// educador e o aluno. Espelha o filtro do índice único <c>ux_vinculo_aberto</c>:
    /// é a checagem que vira 409 antes de tentar criar um segundo convite.
    /// </summary>
    public Task<bool> ExisteVinculoAbertoAsync(
        Guid educadorId,
        Guid alunoId,
        CancellationToken ct);

    /// <summary>Vínculo pelo id, ou nulo.</summary>
    public Task<Vinculo?> ObterPorIdAsync(Guid id, CancellationToken ct);

    /// <summary>Vínculos PENDENTES em que o usuário é o aluno (convites a aceitar).</summary>
    public Task<List<Vinculo>> ListarPendentesDoAlunoAsync(Guid alunoId, CancellationToken ct);

    /// <summary>Vínculos ATIVOS em que o usuário é o educador (lista de alunos).</summary>
    public Task<List<Vinculo>> ListarAtivosDoEducadorAsync(Guid educadorId, CancellationToken ct);

    public Task SalvarAsync(CancellationToken ct);

    /// <summary>
    /// Insere um vínculo tolerando a corrida no convite: dois convites
    /// simultâneos ao mesmo aluno colidem no índice único parcial
    /// <c>ux_vinculo_aberto</c>. Retorna <c>false</c> nessa colisão (o serviço
    /// traduz em 409), em vez de deixar o <c>DbUpdateException</c> virar 500.
    /// </summary>
    public Task<bool> TentarCriarAsync(Vinculo vinculo, CancellationToken ct);
}
