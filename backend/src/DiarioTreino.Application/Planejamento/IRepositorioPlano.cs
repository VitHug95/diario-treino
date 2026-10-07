using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Application.Planejamento;

/// <summary>Persistência de planos e fichas (PBI-12).</summary>
public interface IRepositorioPlano
{
    /// <summary>Plano ativo do atleta com as fichas ativas (ordenadas), ou nulo.</summary>
    public Task<PlanoTreino?> ObterPlanoAtivoAsync(Guid atletaId, CancellationToken ct);

    public void AdicionarPlano(PlanoTreino plano);

    public void AdicionarTreino(Treino treino);

    /// <summary>Treino por id (sem filtrar por dono). Usado para resolver o
    /// atleta e aplicar o controle de acesso.</summary>
    public Task<Treino?> ObterTreinoAsync(Guid treinoId, CancellationToken ct);

    /// <summary>Atleta dono do plano a que o treino pertence, ou nulo se o
    /// treino não existe.</summary>
    public Task<Guid?> ObterAtletaDoTreinoAsync(Guid treinoId, CancellationToken ct);

    /// <summary>Maior ordem entre as fichas ativas do plano (0 se não houver).</summary>
    public Task<short> ObterMaiorOrdemAsync(Guid planoId, CancellationToken ct);

    public Task SalvarAsync(CancellationToken ct);
}
