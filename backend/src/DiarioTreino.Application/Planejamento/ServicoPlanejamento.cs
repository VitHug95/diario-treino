using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Comum;
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
    public async Task<PlanoAtivo?> ObterPlanoAtivoAsync(
        Guid usuarioLogadoId, Guid atletaId, CancellationToken ct)
    {
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId, ct);

        var plano = await _repositorio.ObterPlanoEmUsoAsync(atletaId, ct);
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
    /// Lista os planos do atleta-alvo (PBI-44): em uso primeiro, depois pelo
    /// início mais recente. O alvo é o próprio usuário logado ou, no modo
    /// educador (PBI-86), um aluno com vínculo ativo — a regra do MAS 11.3 é
    /// aplicada antes de ler.
    /// </summary>
    public async Task<List<PlanoDaLista>> ListarPlanosAsync(
        Guid usuarioLogadoId, Guid atletaId, CancellationToken ct)
    {
        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId, ct);
        return await _repositorio.ListarPlanosDoAtletaAsync(atletaId, ct);
    }

    /// <summary>
    /// Detalhe de um plano com as fichas (PBI-44). Resolve o atleta dono e passa
    /// pela regra do MAS 11.3: plano inexistente ou de outro usuário → 404.
    /// </summary>
    public async Task<PlanoDetalhe> ObterPlanoAsync(
        Guid usuarioLogadoId,
        Guid planoId,
        CancellationToken ct)
    {
        var atletaId = await _repositorio.ObterAtletaDoPlanoAsync(planoId, ct);
        if (atletaId is null)
        {
            throw new RecursoNaoEncontradoException();
        }

        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId.Value, ct);

        return await _repositorio.ObterPlanoParaDetalheAsync(planoId, ct)
            ?? throw new RecursoNaoEncontradoException();
    }

    /// <summary>
    /// Cria um plano com nome (PBI-44). Nasce em uso quando o atleta não tem
    /// nenhum plano EM USO (PBI-77): assim, quem excluiu todos os planos e cria
    /// um novo volta a ter plano em uso, mesmo que ainda existam planos
    /// escondidos (ativo=false) no histórico. Com um plano já em uso, o novo
    /// nasce fora de uso. Devolve o resumo do plano criado.
    /// </summary>
    public async Task<PlanoDetalhe> CriarPlanoNomeadoAsync(
        Guid atletaId,
        string nome,
        CancellationToken ct)
    {
        var primeiro = await _repositorio.ObterPlanoEmUsoAsync(atletaId, ct) is null;
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AutorId = atletaId,
            AtletaId = atletaId,
            Nome = nome.Trim(),
            Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
            Ativo = true,
            EmUso = primeiro,
        };
        _repositorio.AdicionarPlano(plano);
        await _repositorio.SalvarAsync(ct);

        return new PlanoDetalhe(
            plano.Id, plano.Nome, plano.Inicio, plano.EmUso, string.Empty, false, []);
    }

    /// <summary>Renomeia o plano (PBI-44). Acesso + somente-leitura aplicados.</summary>
    public async Task RenomearPlanoAsync(
        Guid usuarioLogadoId,
        Guid planoId,
        string nome,
        CancellationToken ct)
    {
        var plano = await ResolverPlanoComAcessoAsync(usuarioLogadoId, planoId, ct, exigeAutor: true);
        plano.Nome = nome.Trim();
        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>
    /// Define o plano como em uso do atleta (PBI-44). Pode ser feito mesmo em
    /// plano de autoria do professor (somente-leitura não bloqueia o uso): o
    /// atleta escolhe qual plano a Início segue.
    /// </summary>
    public async Task DefinirEmUsoAsync(
        Guid usuarioLogadoId,
        Guid planoId,
        CancellationToken ct)
    {
        var plano = await ResolverPlanoComAcessoAsync(usuarioLogadoId, planoId, ct, exigeAutor: false);
        await _repositorio.DefinirEmUsoAsync(plano.AtletaId, planoId, ct);
    }

    /// <summary>
    /// Duplica o plano (PBI-44). A cópia é sempre de autoria do atleta, mesmo
    /// quando o original é do professor (é assim que o atleta "copia para
    /// editar"). Devolve o id da cópia.
    /// </summary>
    public async Task<Guid> DuplicarPlanoAsync(
        Guid usuarioLogadoId,
        Guid planoId,
        CancellationToken ct)
    {
        var plano = await ResolverPlanoComAcessoAsync(usuarioLogadoId, planoId, ct, exigeAutor: false);
        var baseNome = plano.Nome.Trim();
        return await _repositorio.DuplicarPlanoAsync(planoId, $"{baseNome} (cópia)", ct);
    }

    /// <summary>Exclui o plano (PBI-44, regra 10 do MER).</summary>
    public async Task ExcluirPlanoAsync(
        Guid usuarioLogadoId,
        Guid planoId,
        CancellationToken ct)
    {
        await ResolverPlanoComAcessoAsync(usuarioLogadoId, planoId, ct, exigeAutor: true);
        await _repositorio.ExcluirPlanoAsync(planoId, ct);
    }

    /// <summary>
    /// Carrega o plano garantindo acesso (MAS 11.3): resolve o atleta dono e
    /// passa pelo <see cref="IControleAcesso"/> — plano inexistente ou de outro
    /// usuário → 404. Quando <paramref name="exigeAutor"/>, aplica a regra de
    /// somente-leitura: editar plano de autor diferente do atleta → 403
    /// (preenchido na fatia D). A ordem é obrigatória: 404 primeiro, 403 depois.
    /// </summary>
    private async Task<PlanoTreino> ResolverPlanoComAcessoAsync(
        Guid usuarioLogadoId,
        Guid planoId,
        CancellationToken ct,
        bool exigeAutor)
    {
        var atletaId = await _repositorio.ObterAtletaDoPlanoAsync(planoId, ct);
        if (atletaId is null)
        {
            throw new RecursoNaoEncontradoException();
        }

        await _acesso.GarantirAcessoAtletaAsync(usuarioLogadoId, atletaId.Value, ct);

        var plano = await _repositorio.ObterPlanoAsync(planoId, ct)
            ?? throw new RecursoNaoEncontradoException();

        // Regra somente-leitura (fatia D): escrita em plano de autor diferente
        // do atleta responde 403, sempre DEPOIS do controle de acesso (404).
        if (exigeAutor && plano.AutorId != plano.AtletaId)
        {
            throw new PlanoSomenteLeituraException();
        }

        return plano;
    }

    /// <summary>
    /// Adiciona uma ficha ao plano ativo do atleta. Se ainda não existe plano,
    /// cria um (autor = atleta = usuário). A ordem da ficha é a próxima da fila.
    /// </summary>
    public async Task<Guid> AdicionarFichaAsync(
        Guid usuarioLogadoId,
        Guid? planoId,
        SalvarTreinoRequest request,
        CancellationToken ct)
    {
        PlanoTreino plano;

        // Com um plano existente no id da URL (PBI-44), a ficha vai para ELE,
        // após controle de acesso (404) e somente-leitura (403). Sem plano no id
        // (front antigo manda id qualquer, ou primeira ficha), cai no fluxo
        // compatível: usa o plano em uso ou cria "Meu plano".
        var existente = planoId is null
            ? null
            : await _repositorio.ObterPlanoAsync(planoId.Value, ct);

        if (existente is not null)
        {
            plano = await ResolverPlanoComAcessoAsync(usuarioLogadoId, existente.Id, ct, exigeAutor: true);
        }
        else
        {
            var emUso = await _repositorio.ObterPlanoEmUsoAsync(usuarioLogadoId, ct);
            if (emUso is null)
            {
                // Sem plano em uso: cria "Meu plano" e ele nasce em uso (PBI-77).
                // Chegamos aqui justamente porque ObterPlanoEmUsoAsync devolveu
                // nulo, então não há conflito com o índice único parcial.
                emUso = new PlanoTreino
                {
                    Id = Guid.NewGuid(),
                    AutorId = usuarioLogadoId,
                    AtletaId = usuarioLogadoId,
                    Nome = "Meu plano",
                    Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
                    Ativo = true,
                    EmUso = true,
                    Treinos = [],
                };
                _repositorio.AdicionarPlano(emUso);
                await _repositorio.SalvarAsync(ct);
            }
            plano = emUso;
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
    /// Cria uma ficha a partir dos exercícios de um treino livre (PBI-19,
    /// "Salvar também como ficha"): garante o plano, cria o treino e adiciona
    /// os exercícios na ordem informada. Cada exercício passa pela mesma
    /// verificação de disponibilidade/acesso de <see cref="AdicionarExercicioAsync"/>
    /// (exercício inexistente ou de outro usuário → 404). Devolve o id da ficha.
    /// </summary>
    public async Task<Guid> CriarFichaDeExerciciosAsync(
        Guid usuarioLogadoId,
        CriarFichaDeTreinoRequest request,
        CancellationToken ct)
    {
        // Treino livre salvo como ficha (PBI-19) vai para o plano em uso.
        var treinoId = await AdicionarFichaAsync(
            usuarioLogadoId,
            planoId: null,
            new SalvarTreinoRequest(request.Nome, request.Descricao),
            ct);

        // Ignora ids repetidos preservando a ordem da primeira ocorrência.
        var vistos = new HashSet<Guid>();
        foreach (var exercicioId in request.ExercicioIds)
        {
            if (!vistos.Add(exercicioId)) continue;
            await AdicionarExercicioAsync(usuarioLogadoId, treinoId, exercicioId, ct);
        }

        return treinoId;
    }

    /// <summary>
    /// Garante um plano ativo para o atleta (cria se não houver) e o devolve.
    /// Atende o POST /planos; o fluxo comum cria o plano junto da primeira ficha.
    /// </summary>
    public async Task<PlanoAtivo> CriarPlanoAsync(Guid atletaId, CancellationToken ct)
    {
        // Sem corpo: idempotente — devolve o plano em uso se já houver (contrato
        // antigo preservado para o E2E, até o front migrar). Sem plano em uso, o
        // plano criado nasce em uso (PBI-77), mesmo que haja planos escondidos.
        var existente = await _repositorio.ObterPlanoEmUsoAsync(atletaId, ct);
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
            EmUso = true,
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

    /// <summary>
    /// Exclui a ficha (PBI-36). Se nunca foi usada numa sessão, apaga de verdade
    /// (itens e etapas caem em cascata). Se já tem sessões registradas, arquiva
    /// (ativo = false) para o histórico e o gráfico continuarem com o nome dela.
    /// Devolve <c>true</c> quando apagou de verdade, <c>false</c> quando arquivou.
    /// </summary>
    public async Task<bool> ExcluirFichaAsync(
        Guid usuarioLogadoId,
        Guid treinoId,
        CancellationToken ct)
    {
        var treino = await ResolverComAcessoAsync(usuarioLogadoId, treinoId, ct);

        if (await _repositorio.TreinoTemSessoesAsync(treinoId, ct))
        {
            treino.Ativo = false;
            await _repositorio.SalvarAsync(ct);
            return false;
        }

        // Apaga de verdade. Carrega os itens e etapas para o EF remover o grafo
        // inteiro de forma determinística, sem depender do cascade do banco.
        var completo = await _repositorio.ObterTreinoComExerciciosAsync(treinoId, ct)
            ?? treino;
        _repositorio.RemoverTreino(completo);
        await _repositorio.SalvarAsync(ct);
        return true;
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

            var marcadores = te.Marcadores
                .Where(m => m.Marcador != TagSerie.Valida)
                .OrderBy(m => m.Rodada)
                .Select(m => new MarcadorRodada(m.Rodada, m.Marcador))
                .ToList();

            exercicios.Add(new TreinoExercicioResumo(
                te.Id,
                te.ExercicioId,
                te.Exercicio?.Nome ?? string.Empty,
                te.Exercicio?.Modalidade ?? string.Empty,
                te.Ordem,
                te.Rodadas,
                te.DescansoAlvoSeg,
                te.Observacao,
                await MapearAlvoAsync(etapa, ct),
                marcadores));
        }

        var plano = await _repositorio.ObterPlanoAsync(treino.PlanoId, ct);
        var somenteLeitura = plano is not null && plano.AutorId != plano.AtletaId;

        return new TreinoDetalhe(
            treino.Id, treino.Nome, treino.Descricao, treino.Ordem, exercicios, somenteLeitura);
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
            etapa.VolumeAlvo,
            etapa.VolumeAlvoMax);
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

        // PBI-74: cada exercício aparece uma única vez por ficha.
        if (await _repositorio.ExercicioJaNaFichaAsync(treinoId, exercicioId, ct))
        {
            throw new ConflitoException("Este exercício já está na ficha.");
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
            VolumeAlvoMax = request.VolumeAlvoMax,
        });

        SincronizarMarcadores(te, request);

        await _repositorio.SalvarAsync(ct);
    }

    /// <summary>
    /// Reaplica as tags de série (TV-1): apaga os marcadores atuais e regrava só
    /// os informados que sejam ≠ VALIDA e com rodada em [1, Series]. Assim,
    /// reduzir o número de séries descarta naturalmente as tags das rodadas que
    /// deixaram de existir, e rodada VALIDA não ocupa linha.
    /// </summary>
    private void SincronizarMarcadores(TreinoExercicio te, DefinirAlvosRequest request)
    {
        foreach (var antigo in te.Marcadores.ToList())
        {
            _repositorio.RemoverMarcador(antigo);
        }

        if (request.Marcadores is null)
        {
            return;
        }

        // Uma tag por rodada (a última informada vence, caso venham repetidas).
        var porRodada = new Dictionary<short, string>();
        foreach (var m in request.Marcadores)
        {
            var valido = TagSerie.EhValido(m.Marcador)
                && m.Marcador != TagSerie.Valida
                && m.Rodada >= 1
                && m.Rodada <= request.Series;
            if (valido)
            {
                porRodada[m.Rodada] = m.Marcador;
            }
        }

        foreach (var (rodada, marcador) in porRodada)
        {
            _repositorio.AdicionarMarcador(new RodadaMarcador
            {
                TreinoExercicioId = te.Id,
                Rodada = rodada,
                Marcador = marcador,
            });
        }
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
