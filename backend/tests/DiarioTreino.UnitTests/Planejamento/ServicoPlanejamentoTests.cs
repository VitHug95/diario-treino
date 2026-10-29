using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Catalogo;
using DiarioTreino.Application.Comum;
using DiarioTreino.Application.Planejamento;
using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.UnitTests.Planejamento;

public sealed class ServicoPlanejamentoTests
{
    internal sealed class RepositorioPlanoFake : IRepositorioPlano
    {
        public PlanoTreino? PlanoAtivo;
        public readonly List<PlanoTreino> Planos = [];
        public readonly List<Treino> Treinos = [];
        public readonly List<TreinoExercicio> TreinoExercicios = [];
        public Guid? AtletaDoTreino;
        public short MaiorOrdem;
        public short MaiorOrdemExercicio;

        public Task<PlanoTreino?> ObterPlanoEmUsoAsync(Guid atletaId, CancellationToken ct)
        {
            // Reflete o estado real: o plano EM USO do atleta vem da lista.
            // Mantém o atalho PlanoAtivo para os testes que não populam Planos.
            var emUso = Planos.FirstOrDefault(p => p.AtletaId == atletaId && p.EmUso);
            return Task.FromResult(emUso ?? PlanoAtivo);
        }

        public Task<List<PlanoDaLista>> ListarPlanosDoAtletaAsync(Guid atletaId, CancellationToken ct)
            => Task.FromResult(Planos
                .Where(p => p.AtletaId == atletaId && p.Ativo)
                .Select(p => new PlanoDaLista(
                    p.Id, p.Nome, p.Inicio, p.EmUso, "Atleta",
                    p.AutorId != p.AtletaId,
                    Treinos.Count(t => t.PlanoId == p.Id && t.Ativo),
                    0))
                .ToList());

        public Task<Guid?> ObterAtletaDoPlanoAsync(Guid planoId, CancellationToken ct)
            => Task.FromResult(Planos.FirstOrDefault(p => p.Id == planoId)?.AtletaId);

        public Task<PlanoDetalhe?> ObterPlanoParaDetalheAsync(Guid planoId, CancellationToken ct)
        {
            var p = Planos.FirstOrDefault(x => x.Id == planoId);
            if (p is null) return Task.FromResult<PlanoDetalhe?>(null);
            var treinos = Treinos
                .Where(t => t.PlanoId == planoId && t.Ativo)
                .OrderBy(t => t.Ordem)
                .Select(t => new TreinoResumo(t.Id, t.Nome, t.Descricao, t.Ordem))
                .ToList();
            return Task.FromResult<PlanoDetalhe?>(new PlanoDetalhe(
                p.Id, p.Nome, p.Inicio, p.EmUso, "Atleta",
                p.AutorId != p.AtletaId, treinos));
        }

        public Task<PlanoTreino?> ObterPlanoAsync(Guid planoId, CancellationToken ct)
            => Task.FromResult(Planos.FirstOrDefault(p => p.Id == planoId));

        public Guid? DefinidoEmUso;
        public Task DefinirEmUsoAsync(Guid atletaId, Guid planoId, CancellationToken ct)
        {
            foreach (var p in Planos.Where(p => p.AtletaId == atletaId))
            {
                p.EmUso = p.Id == planoId;
            }
            DefinidoEmUso = planoId;
            return Task.CompletedTask;
        }

        public Guid? DuplicadoDe;
        public string? DuplicadoNome;
        public Task<Guid> DuplicarPlanoAsync(Guid planoId, string novoNome, CancellationToken ct)
        {
            DuplicadoDe = planoId;
            DuplicadoNome = novoNome;
            var copiaId = Guid.NewGuid();
            var orig = Planos.First(p => p.Id == planoId);
            Planos.Add(new PlanoTreino
            {
                Id = copiaId,
                AutorId = orig.AtletaId,
                AtletaId = orig.AtletaId,
                Nome = novoNome,
                Inicio = DateOnly.FromDateTime(DateTime.UtcNow),
                Ativo = true,
                EmUso = false,
            });
            return Task.FromResult(copiaId);
        }

        public Guid? ExcluidoId;
        public Task ExcluirPlanoAsync(Guid planoId, CancellationToken ct)
        {
            ExcluidoId = planoId;
            Planos.RemoveAll(p => p.Id == planoId);
            return Task.CompletedTask;
        }

        public void AdicionarPlano(PlanoTreino plano)
        {
            Planos.Add(plano);
            PlanoAtivo = plano;
        }

        public void AdicionarTreino(Treino treino) => Treinos.Add(treino);

        public Task<Treino?> ObterTreinoAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(Treinos.FirstOrDefault(t => t.Id == treinoId));

        public bool TemSessoes;
        public Task<bool> TreinoTemSessoesAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(TemSessoes);

        public void RemoverTreino(Treino treino) => Treinos.Remove(treino);

        public Task<Guid?> ObterAtletaDoTreinoAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(AtletaDoTreino);

        public Task<short> ObterMaiorOrdemAsync(Guid planoId, CancellationToken ct)
            => Task.FromResult(MaiorOrdem);

        public Task<Treino?> ObterTreinoComExerciciosAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(Treinos.FirstOrDefault(t => t.Id == treinoId));

        public void AdicionarTreinoExercicio(TreinoExercicio te) => TreinoExercicios.Add(te);

        public Task<bool> ExercicioJaNaFichaAsync(Guid treinoId, Guid exercicioId, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.Any(
                te => te.TreinoId == treinoId && te.ExercicioId == exercicioId));

        public void RemoverTreinoExercicio(TreinoExercicio te) => TreinoExercicios.Remove(te);

        public Task<TreinoExercicio?> ObterTreinoExercicioAsync(Guid id, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.FirstOrDefault(te => te.Id == id));

        public Task<List<TreinoExercicio>> ObterExerciciosDaFichaAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.Where(te => te.TreinoId == treinoId).ToList());

        public Task<short> ObterMaiorOrdemExercicioAsync(Guid treinoId, CancellationToken ct)
            => Task.FromResult(MaiorOrdemExercicio);

        public Task<TreinoExercicio?> ObterTreinoExercicioComEtapasAsync(Guid id, CancellationToken ct)
            => Task.FromResult(TreinoExercicios.FirstOrDefault(te => te.Id == id));

        public Task<(string Codigo, string Nome)?> ObterMetricaAsync(short metricaId, CancellationToken ct)
            => Task.FromResult<(string, string)?>(("COD", "Métrica"));

        public readonly List<EtapaPrescrita> Etapas = [];
        public void AdicionarEtapa(EtapaPrescrita etapa) => Etapas.Add(etapa);
        public void RemoverEtapa(EtapaPrescrita etapa) => Etapas.Remove(etapa);

        public readonly List<RodadaMarcador> Marcadores = [];
        public void AdicionarMarcador(RodadaMarcador marcador) => Marcadores.Add(marcador);
        public void RemoverMarcador(RodadaMarcador marcador) => Marcadores.Remove(marcador);

        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;
    }

    // Métricas: eixo por faixa de id (1-3 intensidade, 10-12 volume).
    internal sealed class RepositorioMetricaFake : IRepositorioMetrica
    {
        public Task<IReadOnlyList<MetricaResumo>> ListarAsync(CancellationToken ct)
            => Task.FromResult<IReadOnlyList<MetricaResumo>>([]);

        public Task<string?> ObterEixoAsync(short metricaId, CancellationToken ct)
        {
            string? eixo = metricaId switch
            {
                >= 1 and <= 3 => DiarioTreino.Domain.Comum.EixoMetrica.Intensidade,
                >= 10 and <= 12 => DiarioTreino.Domain.Comum.EixoMetrica.Volume,
                _ => null,
            };
            return Task.FromResult(eixo);
        }
    }

    internal sealed class RepositorioVinculoFake : IRepositorioVinculo
    {
        public Task<bool> ExisteVinculoAtivoAsync(Guid e, Guid a, CancellationToken ct)
            => Task.FromResult(false);

        public Task<bool> ExisteVinculoAbertoAsync(Guid e, Guid a, CancellationToken ct)
            => Task.FromResult(false);

        public Task<DiarioTreino.Domain.Vinculos.Vinculo?> ObterPorIdAsync(Guid id, CancellationToken ct)
            => Task.FromResult<DiarioTreino.Domain.Vinculos.Vinculo?>(null);

        public Task<List<DiarioTreino.Domain.Vinculos.Vinculo>> ListarPendentesDoAlunoAsync(
            Guid alunoId, CancellationToken ct)
            => Task.FromResult(new List<DiarioTreino.Domain.Vinculos.Vinculo>());

        public Task<List<DiarioTreino.Domain.Vinculos.Vinculo>> ListarAtivosDoEducadorAsync(
            Guid educadorId, CancellationToken ct)
            => Task.FromResult(new List<DiarioTreino.Domain.Vinculos.Vinculo>());

        public Task SalvarAsync(CancellationToken ct) => Task.CompletedTask;

        public Task<bool> TentarCriarAsync(DiarioTreino.Domain.Vinculos.Vinculo vinculo, CancellationToken ct)
            => Task.FromResult(true);
    }

    // Repositório de exercício: só o necessário para o planejamento.
    internal sealed class RepositorioExercicioFake : IRepositorioExercicio
    {
        public bool Disponivel = true;

        public Task<IReadOnlyList<ExercicioResumo>> BuscarAsync(
            Guid u, string? b, string? m, short? membroId, CancellationToken ct)
            => Task.FromResult<IReadOnlyList<ExercicioResumo>>([]);

        public Task<bool> ExisteNomeNoCatalogoAsync(Guid u, string n, CancellationToken ct)
            => Task.FromResult(false);

        public Task AdicionarAsync(DiarioTreino.Domain.Catalogo.Exercicio e, CancellationToken ct)
            => Task.CompletedTask;

        public Task<bool> ExisteDisponivelAsync(Guid exercicioId, Guid usuarioId, CancellationToken ct)
            => Task.FromResult(Disponivel);

        public Task<IReadOnlyDictionary<Guid, ExercicioBasico>> ObterBasicosPorIdsAsync(
            IReadOnlyCollection<Guid> ids, CancellationToken ct)
            => Task.FromResult<IReadOnlyDictionary<Guid, ExercicioBasico>>(
                new Dictionary<Guid, ExercicioBasico>());

        public Task<ExercicioParaRascunho?> ObterParaRascunhoAsync(
            Guid exercicioId, Guid usuarioId, CancellationToken ct)
            => Task.FromResult<ExercicioParaRascunho?>(null);
    }

    private static ServicoPlanejamento Montar(
        RepositorioPlanoFake repo,
        RepositorioExercicioFake? exercicios = null)
        => new(
            repo,
            new ControleAcesso(new RepositorioVinculoFake()),
            exercicios ?? new RepositorioExercicioFake(),
            new RepositorioMetricaFake());

    [Fact]
    public async Task Primeira_ficha_cria_plano_com_autor_igual_atleta()
    {
        var repo = new RepositorioPlanoFake();
        var atleta = Guid.NewGuid();

        await Montar(repo).AdicionarFichaAsync(
            atleta, null, new SalvarTreinoRequest("A", "Peito"), CancellationToken.None);

        Assert.Single(repo.Planos);
        Assert.Equal(atleta, repo.Planos[0].AutorId);
        Assert.Equal(atleta, repo.Planos[0].AtletaId);
        Assert.Single(repo.Treinos);
        Assert.Equal("A", repo.Treinos[0].Nome);
    }

    [Fact]
    public async Task Ficha_recebe_ordem_seguinte()
    {
        var atleta = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            PlanoAtivo = new PlanoTreino { Id = Guid.NewGuid(), AtletaId = atleta, AutorId = atleta },
            MaiorOrdem = 2,
        };

        await Montar(repo).AdicionarFichaAsync(
            atleta, null, new SalvarTreinoRequest("C", null), CancellationToken.None);

        Assert.Equal((short)3, repo.Treinos.Single().Ordem);
    }

    [Fact]
    public async Task Editar_ficha_de_outro_usuario_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            Treinos = { new Treino { Id = treinoId, Nome = "A" } },
        };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).EditarFichaAsync(
                terceiro, treinoId, new SalvarTreinoRequest("X", null), CancellationToken.None));
    }

    [Fact]
    public async Task Excluir_ficha_com_sessoes_apenas_arquiva()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var treino = new Treino { Id = treinoId, Nome = "A", Ativo = true };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TemSessoes = true,
            Treinos = { treino },
        };

        var apagou = await Montar(repo).ExcluirFichaAsync(dono, treinoId, CancellationToken.None);

        Assert.False(apagou); // arquivou, não apagou
        Assert.False(treino.Ativo);
        Assert.Contains(treino, repo.Treinos);
    }

    [Fact]
    public async Task Excluir_ficha_sem_sessoes_apaga_de_verdade()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var treino = new Treino { Id = treinoId, Nome = "A", Ativo = true };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TemSessoes = false,
            Treinos = { treino },
        };

        var apagou = await Montar(repo).ExcluirFichaAsync(dono, treinoId, CancellationToken.None);

        Assert.True(apagou);
        Assert.DoesNotContain(treino, repo.Treinos);
    }

    [Fact]
    public async Task Excluir_treino_inexistente_lanca_recurso_nao_encontrado()
    {
        var repo = new RepositorioPlanoFake { AtletaDoTreino = null };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).ExcluirFichaAsync(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Adicionar_exercicio_na_ficha_recebe_ordem_seguinte()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            MaiorOrdemExercicio = 1,
        };

        await Montar(repo).AdicionarExercicioAsync(
            dono, treinoId, Guid.NewGuid(), CancellationToken.None);

        var te = Assert.Single(repo.TreinoExercicios);
        Assert.Equal((short)2, te.Ordem);
        Assert.Equal(treinoId, te.TreinoId);
    }

    [Fact]
    public async Task Adicionar_exercicio_ja_na_ficha_lanca_conflito()
    {
        // PBI-74: cada exercício aparece uma única vez por ficha.
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var exercicioId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios =
            {
                new TreinoExercicio
                {
                    Id = Guid.NewGuid(),
                    TreinoId = treinoId,
                    ExercicioId = exercicioId,
                    Ordem = 1,
                },
            },
        };

        await Assert.ThrowsAsync<ConflitoException>(() =>
            Montar(repo).AdicionarExercicioAsync(dono, treinoId, exercicioId, CancellationToken.None));
    }

    [Fact]
    public async Task Adicionar_exercicio_indisponivel_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var repo = new RepositorioPlanoFake { AtletaDoTreino = dono };
        var exercicios = new RepositorioExercicioFake { Disponivel = false };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo, exercicios).AdicionarExercicioAsync(
                dono, Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task Reordenar_aplica_a_nova_ordem()
    {
        var dono = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var a = new TreinoExercicio { Id = Guid.NewGuid(), TreinoId = treinoId, Ordem = 1 };
        var b = new TreinoExercicio { Id = Guid.NewGuid(), TreinoId = treinoId, Ordem = 2 };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { a, b },
        };

        // Inverte a ordem: b primeiro, a depois.
        await Montar(repo).ReordenarExerciciosAsync(
            dono, treinoId, [b.Id, a.Id], CancellationToken.None);

        Assert.Equal((short)1, b.Ordem);
        Assert.Equal((short)2, a.Ordem);
    }

    [Fact]
    public async Task Remover_exercicio_de_outro_usuario_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { new TreinoExercicio { Id = teId, TreinoId = treinoId } },
        };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).RemoverExercicioAsync(terceiro, teId, CancellationToken.None));
    }

    [Fact]
    public async Task Definir_alvos_grava_series_descanso_instrucao_e_etapa()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var treinoId = Guid.NewGuid();
        var te = new TreinoExercicio { Id = teId, TreinoId = treinoId, Rodadas = 1 };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { te },
        };

        await Montar(repo).DefinirAlvosAsync(
            dono, teId,
            new DefinirAlvosRequest(
                Series: 3,
                IntensidadeMetricaId: 1,  // CARGA_KG (intensidade)
                IntensidadeAlvo: 30,
                VolumeMetricaId: 10,      // REPETICOES (volume)
                VolumeAlvo: 10,
                DescansoSeg: 90,
                Instrucao: "descer devagar"),
            CancellationToken.None);

        Assert.Equal((short)3, te.Rodadas);
        Assert.Equal((short)90, te.DescansoAlvoSeg);
        Assert.Equal("descer devagar", te.Observacao);
        var etapa = Assert.Single(repo.Etapas);
        Assert.Equal(30m, etapa.IntensidadeAlvo);
        Assert.Equal(10m, etapa.VolumeAlvo);
    }

    [Fact]
    public async Task Definir_alvos_grava_marcadores_diferentes_de_valida()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var te = new TreinoExercicio { Id = teId, TreinoId = Guid.NewGuid(), Rodadas = 1 };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { te },
        };

        await Montar(repo).DefinirAlvosAsync(
            dono, teId,
            new DefinirAlvosRequest(
                Series: 4,
                IntensidadeMetricaId: 1,
                IntensidadeAlvo: 30,
                VolumeMetricaId: 10,
                VolumeAlvo: 10,
                DescansoSeg: 90,
                Instrucao: null,
                Marcadores:
                [
                    new MarcadorRodada(1, DiarioTreino.Domain.Comum.TagSerie.Aquecimento),
                    new MarcadorRodada(4, DiarioTreino.Domain.Comum.TagSerie.Falha),
                    // VALIDA não deve virar linha.
                    new MarcadorRodada(2, DiarioTreino.Domain.Comum.TagSerie.Valida),
                ]),
            CancellationToken.None);

        Assert.Equal(2, repo.Marcadores.Count);
        Assert.Contains(repo.Marcadores, m =>
            m.Rodada == 1 && m.Marcador == DiarioTreino.Domain.Comum.TagSerie.Aquecimento);
        Assert.Contains(repo.Marcadores, m =>
            m.Rodada == 4 && m.Marcador == DiarioTreino.Domain.Comum.TagSerie.Falha);
        Assert.DoesNotContain(repo.Marcadores, m => m.Rodada == 2);
    }

    [Fact]
    public async Task Reduzir_series_corta_marcadores_de_rodada_maior()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        // Já havia uma tag na rodada 4 (ex.: ficha anterior com 4 séries).
        var te = new TreinoExercicio
        {
            Id = teId,
            TreinoId = Guid.NewGuid(),
            Rodadas = 4,
            Marcadores =
            {
                new RodadaMarcador
                {
                    TreinoExercicioId = teId,
                    Rodada = 4,
                    Marcador = DiarioTreino.Domain.Comum.TagSerie.Falha,
                },
            },
        };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { te },
        };

        // Reduz para 3 séries, reenviando a mesma tag da rodada 4 (que não cabe mais).
        await Montar(repo).DefinirAlvosAsync(
            dono, teId,
            new DefinirAlvosRequest(
                Series: 3,
                IntensidadeMetricaId: 1,
                IntensidadeAlvo: 30,
                VolumeMetricaId: 10,
                VolumeAlvo: 10,
                DescansoSeg: 90,
                Instrucao: null,
                Marcadores:
                [
                    new MarcadorRodada(4, DiarioTreino.Domain.Comum.TagSerie.Falha),
                ]),
            CancellationToken.None);

        // A tag da rodada 4 deixou de existir (fora de [1, 3]).
        Assert.DoesNotContain(repo.Marcadores, m => m.Rodada == 4);
        Assert.Empty(repo.Marcadores);
    }

    [Fact]
    public async Task Definir_alvos_grava_a_faixa_de_volume()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var te = new TreinoExercicio { Id = teId, TreinoId = Guid.NewGuid(), Rodadas = 1 };
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { te },
        };

        await Montar(repo).DefinirAlvosAsync(
            dono, teId,
            new DefinirAlvosRequest(
                Series: 3,
                IntensidadeMetricaId: 1,
                IntensidadeAlvo: 30,
                VolumeMetricaId: 10,
                VolumeAlvo: 8,
                DescansoSeg: 90,
                Instrucao: null,
                VolumeAlvoMax: 12),
            CancellationToken.None);

        var etapa = Assert.Single(repo.Etapas);
        Assert.Equal(8m, etapa.VolumeAlvo);
        Assert.Equal(12m, etapa.VolumeAlvoMax);
    }

    [Fact]
    public async Task Definir_alvos_com_metrica_de_eixo_errado_lanca_argumento()
    {
        var dono = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { new TreinoExercicio { Id = teId, TreinoId = Guid.NewGuid() } },
        };

        // Intensidade recebendo métrica de VOLUME (10).
        await Assert.ThrowsAsync<ArgumentException>(() =>
            Montar(repo).DefinirAlvosAsync(
                dono, teId,
                new DefinirAlvosRequest(3, 10, null, 10, null, null, null),
                CancellationToken.None));
    }

    [Fact]
    public async Task Definir_alvos_em_exercicio_de_outro_usuario_lanca_recurso_nao_encontrado()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var teId = Guid.NewGuid();
        var repo = new RepositorioPlanoFake
        {
            AtletaDoTreino = dono,
            TreinoExercicios = { new TreinoExercicio { Id = teId, TreinoId = Guid.NewGuid() } },
        };

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).DefinirAlvosAsync(
                terceiro, teId,
                new DefinirAlvosRequest(3, 1, 30, 10, 10, 90, null),
                CancellationToken.None));
    }

    // ---- Vários planos por atleta (PBI-44) ----

    [Fact]
    public async Task Primeiro_plano_nomeado_nasce_em_uso()
    {
        var atleta = Guid.NewGuid();
        var repo = new RepositorioPlanoFake();

        var plano = await Montar(repo).CriarPlanoNomeadoAsync(atleta, "Hipertrofia", CancellationToken.None);

        Assert.True(plano.EmUso);
        Assert.True(repo.Planos.Single().EmUso);
    }

    [Fact]
    public async Task Plano_nomeado_nasce_em_uso_quando_so_restam_planos_escondidos()
    {
        // PBI-77: o atleta excluiu todos os planos (que viraram ativo=false por
        // terem histórico) e cria um novo. Mesmo havendo plano escondido, o novo
        // nasce em uso, porque não há NENHUM plano EM USO.
        var atleta = Guid.NewGuid();
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AtletaId = atleta,
            AutorId = atleta,
            Nome = "Antigo (excluído)",
            Ativo = false,
            EmUso = false,
        });

        var novo = await Montar(repo).CriarPlanoNomeadoAsync(atleta, "Meu plano", CancellationToken.None);

        Assert.True(novo.EmUso);
        Assert.True(repo.Planos.Single(p => p.Nome == "Meu plano").EmUso);
    }

    [Fact]
    public async Task Primeira_ficha_apos_excluir_tudo_cria_plano_em_uso()
    {
        // PBI-77 pelo caminho da primeira ficha (AdicionarFichaAsync, ramo "Meu
        // plano"): com só plano escondido, o "Meu plano" criado nasce em uso.
        var atleta = Guid.NewGuid();
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AtletaId = atleta,
            AutorId = atleta,
            Nome = "Antigo (excluído)",
            Ativo = false,
            EmUso = false,
        });

        await Montar(repo).AdicionarFichaAsync(
            atleta, null, new SalvarTreinoRequest("A", null), CancellationToken.None);

        var meuPlano = repo.Planos.Single(p => p.Nome == "Meu plano");
        Assert.True(meuPlano.EmUso);
    }

    [Fact]
    public async Task Segundo_plano_nasce_fora_de_uso_e_nao_mexe_no_atual()
    {
        var atleta = Guid.NewGuid();
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(new PlanoTreino
        {
            Id = Guid.NewGuid(),
            AtletaId = atleta,
            AutorId = atleta,
            Nome = "Hipertrofia",
            EmUso = true,
        });

        var novo = await Montar(repo).CriarPlanoNomeadoAsync(atleta, "Treino de viagem", CancellationToken.None);

        Assert.False(novo.EmUso); // o novo nasce fora de uso
        // O que já estava em uso continua em uso.
        Assert.Equal("Hipertrofia", repo.Planos.Single(p => p.EmUso).Nome);
    }

    [Fact]
    public async Task Definir_em_uso_troca_o_plano_que_a_inicio_segue()
    {
        var atleta = Guid.NewGuid();
        var hipertrofia = new PlanoTreino
        {
            Id = Guid.NewGuid(), AtletaId = atleta, AutorId = atleta, Nome = "Hipertrofia", EmUso = true,
        };
        var viagem = new PlanoTreino
        {
            Id = Guid.NewGuid(), AtletaId = atleta, AutorId = atleta, Nome = "Viagem", EmUso = false,
        };
        var repo = new RepositorioPlanoFake();
        repo.Planos.AddRange([hipertrofia, viagem]);

        await Montar(repo).DefinirEmUsoAsync(atleta, viagem.Id, CancellationToken.None);

        Assert.False(hipertrofia.EmUso);
        Assert.True(viagem.EmUso);
    }

    [Fact]
    public async Task Renomear_plano_de_outro_autor_lanca_somente_leitura_403()
    {
        var atleta = Guid.NewGuid();
        var professor = Guid.NewGuid();
        // Plano do atleta, mas montado pelo professor (autor != atleta).
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(), AtletaId = atleta, AutorId = professor, Nome = "Força 5 dias",
        };
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(plano);

        await Assert.ThrowsAsync<PlanoSomenteLeituraException>(() =>
            Montar(repo).RenomearPlanoAsync(atleta, plano.Id, "Meu jeito", CancellationToken.None));
    }

    [Fact]
    public async Task Renomear_plano_de_outro_usuario_lanca_recurso_nao_encontrado_404()
    {
        var dono = Guid.NewGuid();
        var terceiro = Guid.NewGuid();
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(), AtletaId = dono, AutorId = dono, Nome = "Hipertrofia",
        };
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(plano);

        // O 404 (acesso) vem ANTES do 403 (somente leitura).
        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() =>
            Montar(repo).RenomearPlanoAsync(terceiro, plano.Id, "X", CancellationToken.None));
    }

    [Fact]
    public async Task Definir_em_uso_de_plano_do_professor_e_permitido()
    {
        var atleta = Guid.NewGuid();
        var professor = Guid.NewGuid();
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(), AtletaId = atleta, AutorId = professor, Nome = "Força 5 dias",
        };
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(plano);

        // Usar (seguir) o plano do professor não é escrita: não dá 403.
        await Montar(repo).DefinirEmUsoAsync(atleta, plano.Id, CancellationToken.None);

        Assert.Equal(plano.Id, repo.DefinidoEmUso);
    }

    [Fact]
    public async Task Duplicar_gera_copia_de_autoria_do_atleta()
    {
        var atleta = Guid.NewGuid();
        var professor = Guid.NewGuid();
        var plano = new PlanoTreino
        {
            Id = Guid.NewGuid(), AtletaId = atleta, AutorId = professor, Nome = "Força 5 dias",
        };
        var repo = new RepositorioPlanoFake();
        repo.Planos.Add(plano);

        var copiaId = await Montar(repo).DuplicarPlanoAsync(atleta, plano.Id, CancellationToken.None);

        Assert.Equal(plano.Id, repo.DuplicadoDe);
        Assert.Equal("Força 5 dias (cópia)", repo.DuplicadoNome);
        var copia = repo.Planos.Single(p => p.Id == copiaId);
        Assert.Equal(atleta, copia.AutorId); // autoria do atleta
        Assert.False(copia.EmUso);           // fora de uso
    }
}
