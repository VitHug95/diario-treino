using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Application.Planejamento;

/// <summary>
/// Casos de uso de fichas de treino (PBI-12 e PBI-13). No MVP, autor e atleta do
/// plano são a mesma pessoa (o usuário logado). Toda operação sobre dados de
/// atleta passa pelo <see cref="IControleAcesso"/>.
/// </summary>
public sealed class ServicoPlanejamento
{
    private readonly IRepositorioPlano _repositorio;
    private readonly IControleAcesso _acesso;
    private readonly IRepositorioExercicio _exercicios;

    public ServicoPlanejamento(
        IRepositorioPlano repositorio,
        IControleAcesso acesso,
        IRepositorioExercicio exercicios)
    {
        _repositorio = repositorio;
        _acesso = acesso;
        _exercicios = exercicios;
    }

    /// <summary>Plano ativo do atleta como DTO, ou nulo se ainda não há plano.</summary>
    public async Task<PlanoAtivo?> ObterPlanoAtivoAsync(Guid atletaId, CancellationToken ct)
    {
        var plano = await _repositorio.ObterPlanoAtivoAsync(atletaId, ct);
        if (plano is null)
        {
            return null;
        }

        var treinos = plano.Treinos
            .Select(t => new TreinoResumo(t.Id, t.Nome, t.Descricao, t.Ordem))
            .ToList();
        return new PlanoAtivo(plano.Id, plano.Nome, treinos);
    }

    /// <summary>
    /// Adiciona uma ficha ao plano ativo do atleta. Se ainda não existe plano,
    /// cria um (autor = atleta = usuário). A ordem da ficha é a próxima da fila.
    /// </summary>
    public async Task<Guid> AdicionarFichaAsync(
        Guid atletaId,
        SalvarTreinoRequest request,
        CancellationToken ct)
    {
        var plano = await _repositorio.ObterPlanoAtivoAsync(atletaId, ct);
        if (plano is null)
        {
            plano = new PlanoTreino
            {
                Id = Guid.NewGuid(),
                AutorId = atletaId,
                AtletaId = atletaId,
                Nome = "Meu plano",
                Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
                Ativo = true,
                Treinos = [],
            };
            _repositorio.AdicionarPlano(plano);
            await _repositorio.SalvarAsync(ct);
        }

        var maiorOrdem = await _repositorio.ObterMaiorOrdemAsync(plano.Id, ct);

        var treino = new Treino
        {
            Id = Guid.NewGuid(),
            PlanoId = plano.Id,
            Nome = request.Nome.Trim(),
            Descricao = string.IsNullOrWhiteSpace(request.Descricao)
                ? null
                : request.Descricao.Trim(),
            Ordem = (short)(maiorOrdem + 1),
            Ativo = true,
        };
        _repositorio.AdicionarTreino(treino);
        await _repositorio.SalvarAsync(ct);
        return treino.Id;
    }

    /// <summary>
    /// Garante um plano ativo para o atleta (cria se não houver) e o devolve.
    /// Atende o POST /planos; o fluxo comum cria o plano junto da primeira ficha.
    /// </summary>
    public async Task<PlanoAtivo> CriarPlanoAsync(Guid atletaId, CancellationToken ct)
    {
        var existente = await _repositorio.ObterPlanoAtivoAsync(atletaId, ct);
        if (existente is not null)
        {
            var treinos = existente.Treinos
                .Select(t => new TreinoResumo(t.Id, t.Nome, t.Descricao, t.Ordem))
                .ToList();
            return new PlanoAtivo(existente.Id, existente.Nome, treinos);
        }

        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AutorId = atletaId,
            AtletaId = atletaId,
            Nome = "Meu plano",
            Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
            Ativo = true,
            Treinos = [],
        };
        _repositorio.AdicionarPlano(plano);
        await _repositorio.SalvarAsync(ct);
        return new PlanoAtivo(plano.Id, plano.Nome, []);
    }

    /// <summary>Renomeia/edita a ficha (nome e descrição).</summary>
    public async Task EditarFichaAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        SalvarTreinoRequest request,
        CancellationToken ct)
    {
        var treino = await ResolverComAcessoAsync(usuarioLogadoId, treinoId, ct);

        treino.Nome = request.Nome.Trim();
        treino.Descricao = string.IsNullOrWhiteSpace(request.Descricao)
            ? null
            : request.Descricao.Trim();
        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>Arquiva a ficha (ativo = false). O histórico de sessões continua.</summary>
    public async Task ArquivarFichaAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        CancellationToken ct)
    {
        var treino = await ResolverComAcessoAsync(usuarioLogadoId, treinoId, ct);
        treino.Ativo = false;
        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>
    /// Carrega o treino garantindo acesso: resolve o atleta dono e passa pela
    /// regra do MAS 11.3. Treino inexistente ou de outro usuário → 404.
    /// </summary>
    private async Task<Treino> ResolverComAcessoAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        CancellationToken ct)
    {
        var atletaId = await _repositorio.ObterAtletaDoTreinoAsync(treinoId, ct);
        if (atletaId is null)
        {
            throw new RecursoNaoEncontradoException();
        }

        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId.Value, ct);

        var treino = await _repositorio.ObterTreinoAsync(treinoId, ct);
        return treino ?? throw new RecursoNaoEncontradoException();
    }

    // ---- Exercícios da ficha (PBI-13) ----

    /// <summary>Detalhe da ficha com os exercícios prescritos, na ordem.</summary>
    public async Task<TreinoDetalhe> ObterFichaAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);

        var treino = await _repositorio.ObterTreinoComExerciciosAsync(treinoId, ct)
            ?? throw new RecursoNaoEncontradoException();

        var exercicios = treino.Exercicios
            .Select(te => new TreinoExercicioResumo(
                te.Id,
                te.ExercicioId,
                te.Exercicio?.Nome ?? string.Empty,
                te.Exercicio?.GrupoMuscular,
                te.Exercicio?.Modalidade ?? string.Empty,
                te.Ordem,
                te.Rodadas))
            .ToList();

        return new TreinoDetalhe(treino.Id, treino.Nome, treino.Descricao, treino.Ordem, exercicios);
    }

    /// <summary>
    /// Adiciona um exercício do catálogo ao final da ficha (ordem = próxima).
    /// O exercício precisa existir e estar disponível ao usuário.
    /// </summary>
    public async Task<Guid> AdicionarExercicioAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        Guid exercicioId,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);

        if (!await _exercicios.ExisteDisponivelAsync(exercicioId, usuarioLogadoId, ct))
        {
            throw new RecursoNaoEncontradoException("Exercício não encontrado.");
        }

        var maiorOrdem = await _repositorio.ObterMaiorOrdemExercicioAsync(treinoId, ct);
        var treinoExercicio = new TreinoExercicio
        {
            Id = Guid.NewGuid(),
            TreinoId = treinoId,
            ExercicioId = exercicioId,
            Ordem = (short)(maiorOrdem + 1),
            Rodadas = 1, // alvos detalhados (séries, carga, reps) são o PBI-14
        };
        _repositorio.AdicionarTreinoExercicio(treinoExercicio);
        await _repositorio.SalvarAsync(ct);
        return treinoExercicio.Id;
    }

    /// <summary>
    /// Remove o exercício da ficha. Não apaga o histórico: a FK em
    /// <c>serie_executada</c> é ON DELETE SET NULL (MER 3.11).
    /// </summary>
    public async Task RemoverExercicioAsync(
        Guid usuarioLogadoId,
        Guid treinoExercicioId,
        CancellationToken ct)
    {
        var te = await _repositorio.ObterTreinoExercicioAsync(treinoExercicioId, ct)
            ?? throw new RecursoNaoEncontradoException();
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, te.TreinoId, ct);

        _repositorio.RemoverTreinoExercicio(te);
        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>Aplica a nova ordem dos exercícios da ficha.</summary>
    public async Task ReordenarExerciciosAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        IReadOnlyList<Guid> idsNaOrdem,
        CancellationToken ct)
    {
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, treinoId, ct);

        var exercicios = await _repositorio.ObterExerciciosDaFichaAsync(treinoId, ct);
        var porId = exercicios.ToDictionary(te => te.Id);

        short ordem = 1;
        foreach (var id in idsNaOrdem)
        {
            if (porId.TryGetValue(id, out var te))
            {
                te.Ordem = ordem;
                ordem++;
            }
        }
        await _repositorio.SalvarAsync(ct);
    }

    private async Task GarantirAcessoAoTreinoAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        CancellationToken ct)
    {
        var atletaId = await _repositorio.ObterAtletaDoTreinoAsync(treinoId, ct);
        if (atletaId is null)
        {
            throw new RecursoNaoEncontradoException();
        }
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId.Value, ct);
    }
}
