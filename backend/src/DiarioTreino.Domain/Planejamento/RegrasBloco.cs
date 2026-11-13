namespace DiarioTreino.Domain.Planejamento;

/// <summary>
/// Regras do bloco conjugado (PBI-101), sem dependência de banco. A ordem da
/// ficha é a lista de exercícios ordenada por <see cref="TreinoExercicio.Ordem"/>;
/// "contíguo" quer dizer que nenhum exercício de fora fica no meio dos membros
/// (os números de ordem podem ter buracos).
/// </summary>
public static class RegrasBloco
{
    /// <summary>Bloco com menos que isso se desfaz.</summary>
    public const int MinimoMembros = 2;

    /// <summary>Trava de tela (360 px). Se o PO quiser mais, é só esta constante.</summary>
    public const int MaximoMembros = 4;

    /// <summary>Descanso do bloco: 0 a 600 s (10 minutos).</summary>
    public const short DescansoMaximoSeg = 600;

    /// <summary>Rodadas do bloco: o maior número de séries entre os membros.</summary>
    public static short Rodadas(IEnumerable<TreinoExercicio> membros)
    {
        short maior = 0;
        foreach (var m in membros)
        {
            if (m.Rodadas > maior) maior = m.Rodadas;
        }
        return maior;
    }

    /// <summary>
    /// A ordem mantém cada bloco inteiro: depois que a sequência sai de um bloco,
    /// ele não pode voltar a aparecer. Recebe o bloco de cada item, na ordem.
    /// </summary>
    public static bool OrdemRespeitaBlocos(IReadOnlyList<Guid?> blocosNaOrdem)
    {
        var fechados = new HashSet<Guid>();
        Guid? atual = null;
        foreach (var bloco in blocosNaOrdem)
        {
            if (bloco != atual)
            {
                if (atual is not null) fechados.Add(atual.Value);
                if (bloco is not null && fechados.Contains(bloco.Value)) return false;
                atual = bloco;
            }
        }
        return true;
    }

    /// <summary>
    /// Nova ordem com os <paramref name="membros"/> juntos, na posição do primeiro
    /// deles na ordem atual, e na sequência em que vieram em
    /// <paramref name="membros"/>. Os outros itens mantêm a ordem relativa.
    /// </summary>
    public static List<Guid> Agrupar(IReadOnlyList<Guid> ordemAtual, IReadOnlyList<Guid> membros)
    {
        var conjunto = membros.ToHashSet();
        var resultado = new List<Guid>(ordemAtual.Count);
        var inserido = false;
        foreach (var id in ordemAtual)
        {
            if (!conjunto.Contains(id))
            {
                resultado.Add(id);
            }
            else if (!inserido)
            {
                resultado.AddRange(membros);
                inserido = true;
            }
        }
        return resultado;
    }
}
