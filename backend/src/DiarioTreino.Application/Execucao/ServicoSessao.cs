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
}
