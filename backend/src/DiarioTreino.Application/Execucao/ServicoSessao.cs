using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Planejamento;
using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Execucao;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.Application.Execucao;

/// <summary>
/// Casos de uso de registro de treino (PBI-15). Monta o rascunho pré-preenchido
/// (histórico ou alvos da ficha, MER 5.1) e grava a sessão com as séries.
/// Todo acesso a dado de atleta passa pelo <see cref="IControleAcesso"/>.
/// </summary>
public sealed class ServicoSessao
{
    private readonly IRepositorioSessao _sessoes;
    private readonly IRepositorioPlano _planos;
    private readonly IControleAcesso _acesso;
    private readonly IRepositorioExercicio _exercicios;
    private readonly IRepositorioMetrica _metricas;

    public ServicoSessao(
        IRepositorioSessao sessoes,
        IRepositorioPlano planos,
        IControleAcesso acesso,
        IRepositorioExercicio exercicios,
        IRepositorioMetrica metricas)
    {
        _sessoes = sessoes;
        _planos = planos;
        _acesso = acesso;
        _exercicios = exercicios;
        _metricas = metricas;
    }

    /// <summary>
    /// Monta o rascunho de sessão de uma ficha: cada exercício abre com as
    /// séries da última sessão do atleta que o contenha; sem histórico, usa os
    /// alvos prescritos (MER 5.1).
    /// </summary>
    public async Task<RascunhoSessao> MontarRascunhoAsync(
        Guid usuarioLogadoId, Guid treinoId, CancellationToken ct)
    {
        var atletaId = await _planos.ObterAtletaDoTreinoAsync(treinoId, ct)
            ?? throw new RecursoNaoEncontradoException();
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId, ct);

        var treino = await _planos.ObterTreinoComExerciciosAsync(treinoId, ct)
            ?? throw new RecursoNaoEncontradoException();

        var exercicios = new List<RascunhoExercicio>();
        foreach (var te in treino.Exercicios)
        {
            exercicios.Add(await MontarExercicioAsync(atletaId, te, ct));
        }

        return new RascunhoSessao(
            treino.Id,
            treino.Nome,
            DateOnly.FromDateTime(DateTime.UtcNow.Date),
            exercicios);
    }

    private async Task<RascunhoExercicio> MontarExercicioAsync(
        Guid atletaId, TreinoExercicio te, CancellationToken ct)
    {
        var nome = te.Exercicio?.Nome ?? string.Empty;
        var grupo = te.Exercicio?.GrupoMuscular;
        var modalidade = te.Exercicio?.Modalidade ?? string.Empty;

        // 1) Histórico: última execução do atleta com este exercício.
        var ultima = await _sessoes.ObterUltimaExecucaoAsync(atletaId, te.ExercicioId, ct);
        if (ultima is { Series.Count: > 0 })
        {
            var series = new List<SerieRascunho>();
            foreach (var se in ultima.Value.Series)
            {
                series.Add(await MapearSerieHistoricoAsync(se, ct));
            }
            var origem = $"Preenchido com o último treino ({ultima.Value.Data:dd/MM})";
            return new RascunhoExercicio(
                te.Id, te.ExercicioId, nome, grupo, modalidade, te.Ordem, origem, series);
        }

        // 2) Sem histórico: alvos prescritos (etapas × rodadas).
        if (te.Etapas.Count > 0 && te.Rodadas > 0)
        {
            var series = await MontarSeriesDosAlvosAsync(te, ct);
            return new RascunhoExercicio(
                te.Id, te.ExercicioId, nome, grupo, modalidade, te.Ordem,
                "Preenchido com os alvos da ficha", series);
        }

        // 3) Sem histórico e sem alvos: começa vazio.
        return new RascunhoExercicio(
            te.Id, te.ExercicioId, nome, grupo, modalidade, te.Ordem, null, []);
    }

    private async Task<List<SerieRascunho>> MontarSeriesDosAlvosAsync(
        TreinoExercicio te, CancellationToken ct)
    {
        var etapas = te.Etapas.OrderBy(e => e.Ordem).ToList();
        var series = new List<SerieRascunho>();
        for (short rodada = 1; rodada <= te.Rodadas; rodada++)
        {
            short ordem = 1;
            foreach (var etapa in etapas)
            {
                var i = await ObterMetricaAsync(etapa.IntensidadeMetricaId, ct);
                var v = await ObterMetricaAsync(etapa.VolumeMetricaId, ct);
                series.Add(new SerieRascunho(
                    rodada,
                    ordem,
                    etapa.Tipo,
                    etapa.IntensidadeMetricaId, i.Codigo, i.Nome, etapa.IntensidadeAlvo,
                    etapa.VolumeMetricaId, v.Codigo, v.Nome, etapa.VolumeAlvo,
                    te.DescansoAlvoSeg));
                ordem++;
            }
        }
        return series;
    }

    private async Task<SerieRascunho> MapearSerieHistoricoAsync(
        SerieExecutada se, CancellationToken ct)
    {
        var i = await ObterMetricaAsync(se.IntensidadeMetricaId, ct);
        var v = await ObterMetricaAsync(se.VolumeMetricaId, ct);
        return new SerieRascunho(
            se.Rodada,
            se.Ordem,
            se.Tipo,
            se.IntensidadeMetricaId, i.Codigo, i.Nome, se.Intensidade,
            se.VolumeMetricaId, v.Codigo, v.Nome, se.Volume,
            se.DescansoSeg);
    }

    private async Task<(string Codigo, string Nome)> ObterMetricaAsync(short id, CancellationToken ct)
    {
        var m = await _planos.ObterMetricaAsync(id, ct);
        return m ?? (string.Empty, string.Empty);
    }

    /// <summary>
    /// Grava a sessão. Exercício sem séries é ignorado (fica como não realizado).
    /// Valida o eixo de cada métrica (MER 5.7) e que os exercícios existem.
    /// </summary>
    public async Task<Guid> CriarSessaoAsync(
        Guid usuarioLogadoId, CriarSessaoRequest request, CancellationToken ct)
    {
        // O atleta da sessão é o usuário logado (no MVP, autor = atleta). Quando
        // vem de uma ficha, confirma que a ficha é acessível ao usuário.
        var atletaId = usuarioLogadoId;
        if (request.TreinoId is { } treinoId)
        {
            var donoDaFicha = await _planos.ObterAtletaDoTreinoAsync(treinoId, ct)
                ?? throw new RecursoNaoEncontradoException();
            await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, donoDaFicha, ct);
            atletaId = donoDaFicha;
        }

        var sessao = new Sessao
        {
            Id = Guid.NewGuid(),
            AtletaId = atletaId,
            TreinoId = request.TreinoId,
            RegistradoPorId = usuarioLogadoId,
            Data = request.Data,
            DuracaoMin = request.DuracaoMin,
            Observacao = string.IsNullOrWhiteSpace(request.Observacao)
                ? null
                : request.Observacao.Trim(),
            Series = [],
        };

        foreach (var ex in request.Exercicios)
        {
            // Exercício sem séries: não realizado, não grava nada.
            if (ex.Series.Count == 0)
            {
                continue;
            }

            if (!await _exercicios.ExisteDisponivelAsync(ex.ExercicioId, usuarioLogadoId, ct))
            {
                throw new ArgumentException($"Exercício {ex.ExercicioId} não encontrado.");
            }

            foreach (var s in ex.Series)
            {
                await ValidarEixoAsync(s.IntensidadeMetricaId, EixoMetrica.Intensidade, ct);
                await ValidarEixoAsync(s.VolumeMetricaId, EixoMetrica.Volume, ct);

                sessao.Series.Add(new SerieExecutada
                {
                    Id = Guid.NewGuid(),
                    SessaoId = sessao.Id,
                    ExercicioId = ex.ExercicioId,
                    TreinoExercicioId = ex.TreinoExercicioId,
                    Rodada = s.Rodada,
                    Ordem = s.Ordem,
                    Tipo = s.Tipo,
                    IntensidadeMetricaId = s.IntensidadeMetricaId,
                    Intensidade = s.Intensidade,
                    VolumeMetricaId = s.VolumeMetricaId,
                    Volume = s.Volume,
                    DescansoSeg = s.DescansoSeg,
                });
            }
        }

        _sessoes.AdicionarSessao(sessao);
        await _sessoes.SalvarAsync(ct);
        return sessao.Id;
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

    // ---- Ver / editar / excluir (PBI-18) ----

    /// <summary>
    /// Detalhe de uma sessão: séries por exercício, o plano prescrito ao lado
    /// (quando veio de ficha) e os exercícios da ficha não realizados.
    /// </summary>
    public async Task<SessaoDetalhe> ObterSessaoAsync(
        Guid usuarioLogadoId, Guid sessaoId, CancellationToken ct)
    {
        var sessao = await CarregarSessaoComAcessoAsync(usuarioLogadoId, sessaoId, ct);

        // Dados dos exercícios que aparecem nas séries.
        var idsExercicios = sessao.Series.Select(s => s.ExercicioId).Distinct().ToList();
        var basicos = await _exercicios.ObterBasicosPorIdsAsync(idsExercicios, ct);

        // Prescrição da ficha (se a sessão veio de uma): plano + não realizados.
        Treino? ficha = null;
        if (sessao.TreinoId is { } treinoId)
        {
            ficha = await _planos.ObterTreinoComExerciciosAsync(treinoId, ct);
        }

        var exercicios = new List<ExercicioSessaoDetalhe>();

        // Agrupa as séries feitas por treino_exercicio (ou pelo exercício, se
        // for fora da ficha), preservando a ordem de execução.
        var grupos = sessao.Series
            .GroupBy(s => (s.TreinoExercicioId, s.ExercicioId))
            .ToList();

        var teComSerie = new HashSet<Guid>();
        foreach (var grupo in grupos)
        {
            var (teId, exId) = grupo.Key;
            if (teId is { } t) teComSerie.Add(t);

            var tePrescrito = ficha?.Exercicios.FirstOrDefault(x => x.Id == teId);
            var basico = basicos.GetValueOrDefault(exId);

            exercicios.Add(new ExercicioSessaoDetalhe(
                exId,
                teId,
                basico?.Nome ?? string.Empty,
                basico?.GrupoMuscular,
                basico?.Modalidade ?? string.Empty,
                tePrescrito?.Ordem ?? (short)(exercicios.Count + 1),
                NaoRealizado: false,
                ForaDaFicha: teId is null,
                Plano: await MontarPlanoAsync(tePrescrito, ct),
                Series: await MapearSeriesDetalheAsync(grupo.OrderBy(s => s.Rodada).ThenBy(s => s.Ordem), ct)));
        }

        // Exercícios da ficha sem nenhuma série feita = não realizados.
        if (ficha is not null)
        {
            foreach (var te in ficha.Exercicios.OrderBy(te => te.Ordem))
            {
                if (teComSerie.Contains(te.Id)) continue;
                exercicios.Add(new ExercicioSessaoDetalhe(
                    te.ExercicioId,
                    te.Id,
                    te.Exercicio?.Nome ?? string.Empty,
                    te.Exercicio?.GrupoMuscular,
                    te.Exercicio?.Modalidade ?? string.Empty,
                    te.Ordem,
                    NaoRealizado: true,
                    ForaDaFicha: false,
                    Plano: await MontarPlanoAsync(te, ct),
                    Series: []));
            }
        }

        return new SessaoDetalhe(
            sessao.Id,
            sessao.TreinoId,
            ficha?.Nome,
            sessao.Data,
            sessao.DuracaoMin,
            sessao.Observacao,
            exercicios.OrderBy(e => e.Ordem).ToList());
    }

    /// <summary>Resumo do plano prescrito, ex.: "3 × 10 com 30 kg". Nulo se não
    /// há etapa de esforço prescrita.</summary>
    private async Task<string?> MontarPlanoAsync(TreinoExercicio? te, CancellationToken ct)
    {
        if (te is null) return null;
        var etapa = te.Etapas
            .Where(e => e.Tipo == TipoEtapa.Esforco)
            .OrderBy(e => e.Ordem)
            .FirstOrDefault();
        if (etapa is null) return null;

        var volume = etapa.VolumeAlvo is { } v ? Formatar(v) : "—";
        var plano = $"{te.Rodadas} × {volume}";
        if (etapa.IntensidadeAlvo is { } i)
        {
            var metrica = await _planos.ObterMetricaAsync(etapa.IntensidadeMetricaId, ct);
            var nome = metrica?.Nome ?? string.Empty;
            plano += $" com {Formatar(i)} {nome}".TrimEnd();
        }
        return plano;
    }

    private async Task<List<SerieDetalhe>> MapearSeriesDetalheAsync(
        IEnumerable<SerieExecutada> series, CancellationToken ct)
    {
        var lista = new List<SerieDetalhe>();
        foreach (var se in series)
        {
            var i = await ObterMetricaAsync(se.IntensidadeMetricaId, ct);
            var v = await ObterMetricaAsync(se.VolumeMetricaId, ct);
            lista.Add(new SerieDetalhe(
                se.Rodada, se.Ordem, se.Tipo,
                se.IntensidadeMetricaId, i.Codigo, i.Nome, se.Intensidade,
                se.VolumeMetricaId, v.Codigo, v.Nome, se.Volume,
                se.DescansoSeg));
        }
        return lista;
    }

    private static string Formatar(decimal valor)
    {
        // Inteiro sem casas; senão com até duas, sem zeros à toa.
        return valor == decimal.Truncate(valor)
            ? ((long)valor).ToString()
            : valor.ToString("0.##");
    }

    /// <summary>
    /// Edita a sessão: troca data/duração/observação e substitui as séries pelas
    /// do request (mesma validação do registro). Exercício sem séries fica fora.
    /// </summary>
    public async Task EditarSessaoAsync(
        Guid usuarioLogadoId, Guid sessaoId, CriarSessaoRequest request, CancellationToken ct)
    {
        var sessao = await CarregarSessaoComAcessoAsync(usuarioLogadoId, sessaoId, ct);

        sessao.TreinoId = request.TreinoId;
        sessao.Data = request.Data;
        sessao.DuracaoMin = request.DuracaoMin;
        sessao.Observacao = string.IsNullOrWhiteSpace(request.Observacao)
            ? null
            : request.Observacao.Trim();
        sessao.AtualizadoEm = DateTimeOffset.UtcNow;

        // Substitui todas as séries pelas novas.
        foreach (var antiga in sessao.Series.ToList())
        {
            _sessoes.RemoverSerie(antiga);
        }

        foreach (var ex in request.Exercicios)
        {
            if (ex.Series.Count == 0) continue;

            if (!await _exercicios.ExisteDisponivelAsync(ex.ExercicioId, usuarioLogadoId, ct))
            {
                throw new ArgumentException($"Exercício {ex.ExercicioId} não encontrado.");
            }

            foreach (var s in ex.Series)
            {
                await ValidarEixoAsync(s.IntensidadeMetricaId, EixoMetrica.Intensidade, ct);
                await ValidarEixoAsync(s.VolumeMetricaId, EixoMetrica.Volume, ct);

                _sessoes.AdicionarSerie(new SerieExecutada
                {
                    Id = Guid.NewGuid(),
                    SessaoId = sessao.Id,
                    ExercicioId = ex.ExercicioId,
                    TreinoExercicioId = ex.TreinoExercicioId,
                    Rodada = s.Rodada,
                    Ordem = s.Ordem,
                    Tipo = s.Tipo,
                    IntensidadeMetricaId = s.IntensidadeMetricaId,
                    Intensidade = s.Intensidade,
                    VolumeMetricaId = s.VolumeMetricaId,
                    Volume = s.Volume,
                    DescansoSeg = s.DescansoSeg,
                });
            }
        }

        await _sessoes.SalvarAsync(ct);
    }

    /// <summary>Exclui a sessão (as séries saem em cascata). Remove do histórico.</summary>
    public async Task ExcluirSessaoAsync(Guid usuarioLogadoId, Guid sessaoId, CancellationToken ct)
    {
        var sessao = await CarregarSessaoComAcessoAsync(usuarioLogadoId, sessaoId, ct);
        _sessoes.RemoverSessao(sessao);
        await _sessoes.SalvarAsync(ct);
    }

    /// <summary>
    /// Carrega a sessão com as séries garantindo o acesso do usuário (MAS 11.3).
    /// Sessão inexistente ou de outro usuário → 404.
    /// </summary>
    private async Task<Sessao> CarregarSessaoComAcessoAsync(
        Guid usuarioLogadoId, Guid sessaoId, CancellationToken ct)
    {
        var atletaId = await _sessoes.ObterAtletaDaSessaoAsync(sessaoId, ct)
            ?? throw new RecursoNaoEncontradoException();
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId, ct);

        return await _sessoes.ObterSessaoComSeriesAsync(sessaoId, ct)
            ?? throw new RecursoNaoEncontradoException();
    }
}
