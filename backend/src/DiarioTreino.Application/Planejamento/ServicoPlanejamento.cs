using DiarioTreino.Application.Acesso;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Application.Planejamento;

/// <summary>
/// Casos de uso de fichas de treino (PBI-12). No MVP, autor e atleta do plano
/// são a mesma pessoa (o usuário logado). Toda operação sobre dados de atleta
/// passa pelo <see cref="IControleAcesso"/>.
/// </summary>
public sealed class ServicoPlanejamento
{
    private readonly IRepositorioPlano _repositorio;
    private readonly IControleAcesso _acesso;

    public ServicoPlanejamento(IRepositorioPlano repositorio, IControleAcesso acesso)
    {
        _repositorio = repositorio;
        _acesso = acesso;
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
}
