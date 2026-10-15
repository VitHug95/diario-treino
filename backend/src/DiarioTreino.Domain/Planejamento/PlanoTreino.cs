namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Conjunto de fichas de um atleta (MER 3.6). Autor e atleta são a mesma pessoa
/// quando o atleta monta o próprio plano; quando o educador monta, o
/// <see cref="AutorId"/> é o educador e o plano é somente leitura para o atleta.
/// Um atleta pode ter vários planos (PBI-44), com no máximo um
/// <see cref="EmUso"/> por vez — garantido por índice único parcial.
/// </summary>
public class PlanoTreino
{
    public Guid Id { get; set; }
    public Guid AutorId { get; set; }
    public Guid AtletaId { get; set; }
    public string Nome { get; set; } = null!;
    public DateOnly Inicio { get; set; }
    public DateOnly? Fim { get; set; }

    /// <summary>
    /// Plano existente com histórico. <c>false</c> só quando o plano foi
    /// excluído e já tinha sessões ligadas às fichas dele: some das telas, o
    /// histórico fica. Padrão <c>true</c>.
    /// </summary>
    public bool Ativo { get; set; } = true;

    /// <summary>
    /// O plano que a tela Início segue (sequência A, B, C). No máximo um por
    /// atleta. Padrão <c>false</c>; o primeiro plano do atleta nasce em uso.
    /// Invariante do banco: <c>NOT EmUso OR Ativo</c>.
    /// </summary>
    public bool EmUso { get; set; }

    public ICollection<Treino> Treinos { get; set; } = [];
}
