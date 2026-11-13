using DiarioTreino.Application.Acesso;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Application.Planejamento;

/// <summary>
/// Blocos conjugados da ficha (PBI-101). Regras: 2 a 4 membros da mesma ficha,
/// sempre contíguos na ordem; um exercício está em no máximo um bloco; bloco que
/// ficaria com menos de 2 se desfaz e os membros voltam a ser avulsos com o
/// descanso do bloco. Erro de regra vira <see cref="ArgumentException"/> (400);
/// ficha ou bloco inexistente ou de outro usuário, 404 (MAS 11.3).
/// </summary>
public sealed partial class ServicoPlanejamento
{
    /// <summary>
    /// Junta exercícios que já estão na ficha num bloco novo. Os membros ficam na
    /// ordem da ficha e, se não forem vizinhos, vão para a posição do primeiro.
    /// </summary>
    public async Task<Guid> CriarBlocoAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        CriarBlocoRequest request,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);

        var exercicios = await _repositorio.ObterExerciciosDaFichaAsync(treinoId, ct);
        var porId = exercicios.ToDictionary(te => te.Id);
        foreach (var id in request.TreinoExercicioIds)
        {
            if (!porId.TryGetValue(id, out var te))
            {
                throw new ArgumentException("Só dá para juntar exercícios desta ficha.");
            }
            if (te.BlocoId is not null)
            {
                throw new ArgumentException("Um dos exercícios já está num bloco.");
            }
        }

        var bloco = new BlocoExercicio
        {
            Id = Guid.NewGuid(),
            TreinoId = treinoId,
            DescansoSeg = request.DescansoSeg,
        };
        _repositorio.AdicionarBloco(bloco);

        var pedidos = request.TreinoExercicioIds.ToHashSet();
        var membros = exercicios.Where(te => pedidos.Contains(te.Id)).Select(te => te.Id).ToList();
        foreach (var id in membros)
        {
            porId[id].BlocoId = bloco.Id;
        }
        AplicarOrdem(exercicios, RegrasBloco.Agrupar(exercicios.Select(te => te.Id).ToList(), membros));

        await _repositorio.SalvarAsync(ct);
        return bloco.Id;
    }

    /// <summary>Muda o descanso do bloco (nulo ou 0 = sem descanso).</summary>
    public async Task DefinirDescansoBlocoAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        Guid blocoId,
        short? descansoSeg,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);
        var bloco = await ObterBlocoDaFichaAsync(treinoId, blocoId, ct);

        bloco.DescansoSeg = descansoSeg;
        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>
    /// Desfaz o bloco: os membros ficam avulsos, na mesma ordem, cada um com o
    /// descanso do bloco.
    /// </summary>
    public async Task DesfazerBlocoAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        Guid blocoId,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);
        var bloco = await ObterBlocoDaFichaAsync(treinoId, blocoId, ct);
        var exercicios = await _repositorio.ObterExerciciosDaFichaAsync(treinoId, ct);

        Desfazer(bloco, exercicios.Where(te => te.BlocoId == bloco.Id));
        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>
    /// Troca os membros do bloco pela lista informada, que também é a ordem
    /// dentro dele. Quem sai fica avulso, logo depois do bloco, com o descanso
    /// do bloco. Com menos de 2 na lista, o bloco se desfaz.
    /// </summary>
    public async Task DefinirMembrosBlocoAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        Guid blocoId,
        IReadOnlyList<Guid> treinoExercicioIds,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);
        var bloco = await ObterBlocoDaFichaAsync(treinoId, blocoId, ct);
        var exercicios = await _repositorio.ObterExerciciosDaFichaAsync(treinoId, ct);
        var porId = exercicios.ToDictionary(te => te.Id);

        foreach (var id in treinoExercicioIds)
        {
            if (!porId.TryGetValue(id, out var te))
            {
                throw new ArgumentException("Só dá para juntar exercícios desta ficha.");
            }
            if (te.BlocoId is not null && te.BlocoId != bloco.Id)
            {
                throw new ArgumentException("Um dos exercícios já está noutro bloco.");
            }
        }

        var atuais = exercicios.Where(te => te.BlocoId == bloco.Id).ToList();

        if (treinoExercicioIds.Count < RegrasBloco.MinimoMembros)
        {
            Desfazer(bloco, atuais);
            await _repositorio.SalvarAsync(ct);
            return;
        }

        var novos = treinoExercicioIds.ToHashSet();
        var saem = atuais.Where(te => !novos.Contains(te.Id)).ToList();
        foreach (var te in saem)
        {
            te.BlocoId = null;
            te.DescansoAlvoSeg = bloco.DescansoSeg;
        }
        foreach (var id in treinoExercicioIds)
        {
            porId[id].BlocoId = bloco.Id;
        }

        // O bloco fica na posição do primeiro item (antigo ou novo); quem saiu
        // vem logo depois, para nenhum avulso ficar no meio dele.
        var sequencia = treinoExercicioIds.Concat(saem.Select(te => te.Id)).ToList();
        AplicarOrdem(exercicios, RegrasBloco.Agrupar(exercicios.Select(te => te.Id).ToList(), sequencia));

        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>
    /// Ao remover um membro: se o bloco ficaria com menos de 2, desfaz (o que
    /// sobrou fica avulso com o descanso do bloco).
    /// </summary>
    private async Task AjustarBlocoAoRemoverAsync(TreinoExercicio removido, CancellationToken ct)
    {
        if (removido.BlocoId is not { } blocoId) return;

        var blocos = await _repositorio.ObterBlocosDaFichaAsync(removido.TreinoId, ct);
        var bloco = blocos.FirstOrDefault(b => b.Id == blocoId);
        if (bloco is null) return;

        var exercicios = await _repositorio.ObterExerciciosDaFichaAsync(removido.TreinoId, ct);
        var restantes = exercicios
            .Where(te => te.BlocoId == blocoId && te.Id != removido.Id)
            .ToList();
        if (restantes.Count < RegrasBloco.MinimoMembros)
        {
            Desfazer(bloco, restantes);
        }
        removido.BlocoId = null;
    }

    /// <summary>Recusa (400) uma ordem que separe os membros de um bloco.</summary>
    private static void GarantirBlocosContiguos(IEnumerable<TreinoExercicio> exercicios)
    {
        var naOrdem = exercicios.OrderBy(te => te.Ordem).Select(te => te.BlocoId).ToList();
        if (!RegrasBloco.OrdemRespeitaBlocos(naOrdem))
        {
            throw new ArgumentException(
                "Os exercícios de um bloco ficam juntos: mova o bloco inteiro.");
        }
    }

    /// <summary>Blocos da ficha para o detalhe, na ordem da ficha.</summary>
    private static List<BlocoResumo> MontarBlocos(
        IReadOnlyCollection<BlocoExercicio> blocos,
        IReadOnlyCollection<TreinoExercicio> exercicios)
    {
        var resultado = new List<(short Ordem, BlocoResumo Bloco)>();
        foreach (var bloco in blocos)
        {
            var membros = exercicios
                .Where(te => te.BlocoId == bloco.Id)
                .OrderBy(te => te.Ordem)
                .ToList();
            if (membros.Count == 0) continue;
            resultado.Add((membros[0].Ordem, new BlocoResumo(
                bloco.Id,
                bloco.DescansoSeg,
                membros.Select(te => te.Id).ToList(),
                RegrasBloco.Rodadas(membros))));
        }
        return resultado.OrderBy(x => x.Ordem).Select(x => x.Bloco).ToList();
    }

    private async Task<BlocoExercicio> ObterBlocoDaFichaAsync(
        Guid treinoId, Guid blocoId, CancellationToken ct)
    {
        var blocos = await _repositorio.ObterBlocosDaFichaAsync(treinoId, ct);
        return blocos.FirstOrDefault(b => b.Id == blocoId)
            ?? throw new RecursoNaoEncontradoException();
    }

    private void Desfazer(BlocoExercicio bloco, IEnumerable<TreinoExercicio> membros)
    {
        foreach (var te in membros)
        {
            te.BlocoId = null;
            te.DescansoAlvoSeg = bloco.DescansoSeg;
        }
        _repositorio.RemoverBloco(bloco);
    }

    /// <summary>Renumera a ordem (1..n) seguindo a lista de ids.</summary>
    private static void AplicarOrdem(IReadOnlyCollection<TreinoExercicio> exercicios, IReadOnlyList<Guid> ids)
    {
        var porId = exercicios.ToDictionary(te => te.Id);
        short ordem = 1;
        foreach (var id in ids)
        {
            porId[id].Ordem = ordem++;
        }
    }
}
