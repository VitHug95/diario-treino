using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Application.Planejamento;

/// <summary>Persistência de planos e fichas (PBI-12).</summary>
public interface IRepositorioPlano
{
    /// <summary>Plano EM USO do atleta (o que a Início segue) com as fichas
    /// ativas (ordenadas), ou nulo se nenhum plano está em uso (PBI-44).</summary>
    public Task<PlanoTreino?> ObterPlanoEmUsoAsync(Guid atletaId, CancellationToken ct);

    /// <summary>Planos ativos do atleta para a lista (PBI-44): em uso primeiro,
    /// depois pelo início mais recente. Com autoria e contagens.</summary>
    public Task<List<PlanoDaLista>> ListarPlanosDoAtletaAsync(Guid atletaId, CancellationToken ct);

    /// <summary>Atleta dono do plano (para o controle de acesso), ou nulo se o
    /// plano não existe/está inativo.</summary>
    public Task<Guid?> ObterAtletaDoPlanoAsync(Guid planoId, CancellationToken ct);

    /// <summary>Detalhe de um plano ativo com as fichas ativas (ordenadas) e a
    /// autoria, ou nulo se não existe/está inativo (PBI-44).</summary>
    public Task<PlanoDetalhe?> ObterPlanoParaDetalheAsync(Guid planoId, CancellationToken ct);

    /// <summary>Plano por id (entidade crua, sem fichas), ou nulo. Para
    /// renomear/duplicar/excluir depois do controle de acesso (PBI-44).</summary>
    public Task<PlanoTreino?> ObterPlanoAsync(Guid planoId, CancellationToken ct);

    /// <summary>
    /// Define o plano como o único em uso do atleta, numa transação só: zera o
    /// em uso anterior e liga o novo, sem janela com zero ou dois em uso
    /// (PBI-44, CA 3). Não faz nada se o plano já está em uso.
    /// </summary>
    public Task DefinirEmUsoAsync(Guid atletaId, Guid planoId, CancellationToken ct);

    /// <summary>
    /// Duplica o plano (PBI-44, CA 4): copia fichas, exercícios, alvos (etapas)
    /// e tags de rodada, com autor = atleta, nome informado, fora de uso e sem
    /// nenhuma sessão. Devolve o id da cópia.
    /// </summary>
    public Task<Guid> DuplicarPlanoAsync(Guid planoId, string novoNome, CancellationToken ct);

    /// <summary>
    /// Exclui o plano (PBI-44, CA 5, regra 10 do MER), numa transação: se
    /// nenhuma ficha tem sessão, apaga de verdade (cascata); se alguma tem,
    /// marca ativo=false e em_uso=false (histórico fica). Se o plano estava em
    /// uso, o uso passa para o plano do atleta com a sessão mais recente; sem
    /// outro, fica sem plano em uso.
    /// </summary>
    public Task ExcluirPlanoAsync(Guid planoId, CancellationToken ct);

    public void AdicionarPlano(PlanoTreino plano);

    public void AdicionarTreino(Treino treino);

    /// <summary>Treino por id (sem filtrar por dono). Usado para resolver o
    /// atleta e aplicar o controle de acesso.</summary>
    public Task<Treino?> ObterTreinoAsync(Guid treinoId, CancellationToken ct);

    /// <summary>Indica se a ficha já foi usada em alguma sessão registrada.
    /// Decide entre apagar de verdade (sem sessões) ou arquivar (com sessões).</summary>
    public Task<bool> TreinoTemSessoesAsync(Guid treinoId, CancellationToken ct);

    /// <summary>Apaga a ficha de verdade (itens e etapas caem em cascata). Só
    /// deve ser chamado quando não há sessões ligadas a ela.</summary>
    public void RemoverTreino(Treino treino);

    /// <summary>Atleta dono do plano a que o treino pertence, ou nulo se o
    /// treino não existe.</summary>
    public Task<Guid?> ObterAtletaDoTreinoAsync(Guid treinoId, CancellationToken ct);

    /// <summary>Maior ordem entre as fichas ativas do plano (0 se não houver).</summary>
    public Task<short> ObterMaiorOrdemAsync(Guid planoId, CancellationToken ct);

    // ---- Exercícios da ficha (PBI-13) ----

    /// <summary>Treino com os exercícios prescritos (com o exercício carregado),
    /// na ordem. Nulo se o treino não existe.</summary>
    public Task<Treino?> ObterTreinoComExerciciosAsync(Guid treinoId, CancellationToken ct);

    public void AdicionarTreinoExercicio(TreinoExercicio treinoExercicio);

    /// <summary>Indica se o exercício do catálogo já está na ficha (PBI-74).
    /// Cada exercício aparece uma única vez por ficha.</summary>
    public Task<bool> ExercicioJaNaFichaAsync(Guid treinoId, Guid exercicioId, CancellationToken ct);

    public void RemoverTreinoExercicio(TreinoExercicio treinoExercicio);

    /// <summary>Exercício prescrito por id, ou nulo.</summary>
    public Task<TreinoExercicio?> ObterTreinoExercicioAsync(Guid id, CancellationToken ct);

    /// <summary>Exercício prescrito por id, com as etapas carregadas, ou nulo.</summary>
    public Task<TreinoExercicio?> ObterTreinoExercicioComEtapasAsync(Guid id, CancellationToken ct);

    /// <summary>Métrica (código, nome) por id — para montar os alvos no DTO.</summary>
    public Task<(string Codigo, string Nome)?> ObterMetricaAsync(short metricaId, CancellationToken ct);

    public void AdicionarEtapa(EtapaPrescrita etapa);

    public void RemoverEtapa(EtapaPrescrita etapa);

    // ---- Marcadores de série prescritos (TV-1) ----

    public void AdicionarMarcador(RodadaMarcador marcador);

    public void RemoverMarcador(RodadaMarcador marcador);

    /// <summary>Exercícios prescritos de uma ficha, na ordem.</summary>
    public Task<List<TreinoExercicio>> ObterExerciciosDaFichaAsync(Guid treinoId, CancellationToken ct);

    /// <summary>Maior ordem entre os exercícios da ficha (0 se não houver).</summary>
    public Task<short> ObterMaiorOrdemExercicioAsync(Guid treinoId, CancellationToken ct);

    public Task SalvarAsync(CancellationToken ct);
}
