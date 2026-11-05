namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Um dia da semana planejada de um plano (PBI-35): qual ficha é treinada
/// naquele dia. A semana é do <see cref="PlanoTreino"/> (a Início segue a do
/// plano em uso) e é opcional — dia sem linha é dia livre/de descanso.
/// No máximo uma ficha por dia; a mesma ficha pode estar em vários dias.
/// PK composta (PlanoId, DiaSemana).
/// </summary>
public class PlanoDiaSemana
{
    public Guid PlanoId { get; set; }

    /// <summary>Dia da semana no padrão ISO: 1 = segunda … 7 = domingo.</summary>
    public short DiaSemana { get; set; }

    /// <summary>Ficha planejada para o dia; precisa ser uma ficha ativa do plano.</summary>
    public Guid TreinoId { get; set; }
}
