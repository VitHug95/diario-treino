using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Domain.Comum;
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
    private readonly IRepositorioMetrica _metricas;

    public ServicoPlanejamento(
        IRepositorioPlano repositorio,
        IControleAcesso acesso,
        IRepositorioExercicio exercicios,
        IRepositorioMetrica metricas)
    {
        _repositorio = repositorio;
        _acesso = acesso;
        _exercicios = exercicios;
        _metricas = metricas;
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

        var exercicios = new List<TreinoExercicioResumo>();
        foreach (var te in treino.Exercicios)
        {
            // Musculação/isometria: uma etapa de ESFORÇO guarda os alvos.
            var etapa = te.Etapas
                .Where(e => e.Tipo == TipoEtapa.Esforco)
                .OrderBy(e => e.Ordem)
                .FirstOrDefault();

            exercicios.Add(new TreinoExercicioResumo(
                te.Id,
                te.ExercicioId,
                te.Exercicio?.Nome ?? string.Empty,
                te.Exercicio?.GrupoMuscular,
                te.Exercicio?.Modalidade ?? string.Empty,
                te.Ordem,
                te.Rodadas,
                te.DescansoAlvoSeg,
                te.Observacao,
                await MapearAlvoAsync(etapa, ct)));
        }

        return new TreinoDetalhe(treino.Id, treino.Nome, treino.Descricao, treino.Ordem, exercicios);
    }

    private async Task<AlvoExercicio?> MapearAlvoAsync(EtapaPrescrita? etapa, CancellationToken ct)
    {
        if (etapa is null)
        {
            return null;
        }

        var intensidade = await _repositorio.ObterMetricaAsync(etapa.IntensidadeMetricaId, ct);
        var volume = await _repositorio.ObterMetricaAsync(etapa.VolumeMetricaId, ct);
        if (intensidade is null || volume is null)
        {
            return null;
        }

        return new AlvoExercicio(
            etapa.IntensidadeMetricaId,
            intensidade.Value.Codigo,
            intensidade.Value.Nome,
            etapa.IntensidadeAlvo,
            etapa.VolumeMetricaId,
            volume.Value.Codigo,
            volume.Value.Nome,
            etapa.VolumeAlvo);
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

    // ---- Alvos do exercício (PBI-14) ----

    /// <summary>
    /// Define séries, alvos (intensidade/volume), descanso e instrução de um
    /// exercício da ficha. Grava em <c>treino_exercicio</c> (rodadas, descanso,
    /// observação) e numa única etapa de ESFORÇO (<c>etapa_prescrita</c>).
    /// </summary>
    public async Task DefinirAlvosAsync(
        Guid usuarioLogadoId,
        Guid treinoExercicioId,
        DefinirAlvosRequest request,
        CancellationToken ct)
    {
        var te = await _repositorio.ObterTreinoExercicioComEtapasAsync(treinoExercicioId, ct)
            ?? throw new RecursoNaoEncontradoException();
        await GarantirAcessoAoTreinoAsync(usuarioLogadoId, te.TreinoId, ct);

        await ValidarEixoAsync(request.IntensidadeMetricaId, EixoMetrica.Intensidade, ct);
        await ValidarEixoAsync(request.VolumeMetricaId, EixoMetrica.Volume, ct);

        te.Rodadas = request.Series;
        te.DescansoAlvoSeg = request.DescansoSeg;
        te.Observacao = string.IsNullOrWhiteSpace(request.Instrucao)
            ? null
            : request.Instrucao.Trim();

        // Substitui as etapas pela única etapa de esforço com os alvos.
        foreach (var antiga in te.Etapas.ToList())
        {
            _repositorio.RemoverEtapa(antiga);
        }
        _repositorio.AdicionarEtapa(new EtapaPrescrita
        {
            Id = Guid.NewGuid(),
            TreinoExercicioId = te.Id,
            Ordem = 1,
            Tipo = TipoEtapa.Esforco,
            IntensidadeMetricaId = request.IntensidadeMetricaId,
            IntensidadeAlvo = request.IntensidadeAlvo,
            VolumeMetricaId = request.VolumeMetricaId,
            VolumeAlvo = request.VolumeAlvo,
        });

        await _repositorio.SalvarAsync(ct);
    }

    private async Task ValidarEixoAsync(short metricaId, string eixoEsperado, CancellationToken ct)
    {
        var eixo = await _metricas.ObterEixoAsync(metricaId, ct);
        if (eixo is null)
        {
            throw new ArgumentException($"Métrica {metricaId} não existe.");
        }
        if (eixo != eixoEsperado)
        {
            throw new ArgumentException($"A métrica {metricaId} não é do eixo {eixoEsperado}.");
        }
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
