using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Corpo;
using DiarioTreino.Domain.Corpo;

namespace DiarioTreino.UnitTests.Corpo;

public sealed class ServicoMedidasTests
{
    private static readonly Guid Usuario = Guid.NewGuid();
    private static readonly DateOnly Dia = new(2026, 11, 5);

    private sealed class RepositorioMedidaFake : IRepositorioMedida
    {
        public readonly List<MedidaCorporal> Linhas = [];
        public int Salvou;

        public Task<List<MedidaCorporal>> UltimasDuasPorTipoAsync(Guid usuarioId, CancellationToken ct) =>
            Task.FromResult(Linhas.Where(m => m.UsuarioId == usuarioId).ToList());

        public Task<List<DiaHistoricoMedidas>> HistoricoAsync(Guid usuarioId, CancellationToken ct) =>
            Task.FromResult(Linhas.Where(m => m.UsuarioId == usuarioId)
                .GroupBy(m => m.Data)
                .Select(g => new DiaHistoricoMedidas(g.Key, g.Count()))
                .OrderByDescending(d => d.Data)
                .ToList());

        public Task<List<MedidaCorporal>> ListarDoDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct) =>
            Task.FromResult(Linhas.Where(m => m.UsuarioId == usuarioId && m.Data == data).ToList());

        public Task<List<MedidaCorporal>> ListarEvolucaoAsync(
            Guid usuarioId, string tipo, DateOnly? de, DateOnly? ate, CancellationToken ct) =>
            Task.FromResult(Linhas
                .Where(m => m.UsuarioId == usuarioId && m.Tipo == tipo
                    && (de == null || m.Data >= de) && (ate == null || m.Data <= ate))
                .OrderBy(m => m.Data)
                .ToList());

        public Task<decimal?> UltimoValorAsync(Guid usuarioId, string tipo, CancellationToken ct) =>
            Task.FromResult(Linhas
                .Where(m => m.UsuarioId == usuarioId && m.Tipo == tipo)
                .OrderByDescending(m => m.Data)
                .Select(m => (decimal?)m.Valor)
                .FirstOrDefault());

        public void Adicionar(MedidaCorporal medida) => Linhas.Add(medida);

        public void Remover(MedidaCorporal medida) => Linhas.Remove(medida);

        public Task SalvarAsync(CancellationToken ct)
        {
            Salvou++;
            return Task.CompletedTask;
        }

        public Task<int> ExcluirDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct) =>
            Task.FromResult(Linhas.RemoveAll(m => m.UsuarioId == usuarioId && m.Data == data));
    }

    private static MedidaCorporal Linha(string tipo, decimal valor, DateOnly data) =>
        new() { Id = Guid.NewGuid(), UsuarioId = Usuario, Tipo = tipo, Valor = valor, Data = data };

    private static Dictionary<string, decimal?> Valores(params (string tipo, decimal? valor)[] itens) =>
        itens.ToDictionary(i => i.tipo, i => i.valor);

    // ---- Variação ----

    [Fact]
    public void Ultimas_com_um_registro_nao_tem_variacao()
    {
        var ultimas = ServicoMedidas.MontarUltimas([Linha(TipoMedida.Cintura, 84.0m, Dia)]);

        var cintura = Assert.Single(ultimas);
        Assert.Equal(84.0m, cintura.Valor);
        Assert.Null(cintura.Variacao);
    }

    [Fact]
    public void Ultimas_com_dois_registros_compara_com_o_anterior()
    {
        var ultimas = ServicoMedidas.MontarUltimas(
        [
            Linha(TipoMedida.Cintura, 87.0m, Dia.AddDays(-30)),
            Linha(TipoMedida.Cintura, 84.0m, Dia),
        ]);

        var cintura = Assert.Single(ultimas);
        Assert.Equal(84.0m, cintura.Valor);
        Assert.Equal(Dia, cintura.Data);
        Assert.Equal(-3.0m, cintura.Variacao);
    }

    [Fact]
    public void Variacao_de_cada_tipo_compara_com_o_anterior_dele_mesmo_com_lacunas()
    {
        // Cintura medida em 01/09 e 05/11; peito só em 01/10 e 20/10: as datas
        // não coincidem e cada tipo compara com o seu próprio anterior.
        var ultimas = ServicoMedidas.MontarUltimas(
        [
            Linha(TipoMedida.Cintura, 90.0m, new DateOnly(2026, 9, 1)),
            Linha(TipoMedida.Cintura, 88.5m, Dia),
            Linha(TipoMedida.Peito, 100.0m, new DateOnly(2026, 10, 1)),
            Linha(TipoMedida.Peito, 101.5m, new DateOnly(2026, 10, 20)),
        ]);

        Assert.Equal(-1.5m, ultimas.Single(u => u.Tipo == TipoMedida.Cintura).Variacao);
        Assert.Equal(1.5m, ultimas.Single(u => u.Tipo == TipoMedida.Peito).Variacao);
    }

    [Fact]
    public void Ultimas_segue_a_ordem_dos_tipos_e_omite_quem_nao_tem_registro()
    {
        var ultimas = ServicoMedidas.MontarUltimas(
        [
            Linha(TipoMedida.CoxaD, 60.0m, Dia),
            Linha(TipoMedida.Peso, 78.0m, Dia),
        ]);

        Assert.Equal([TipoMedida.Peso, TipoMedida.CoxaD], ultimas.Select(u => u.Tipo));
    }

    // ---- Faixas e validação ----

    [Theory]
    [InlineData(TipoMedida.Peso, 30, 300)]
    [InlineData(TipoMedida.Cintura, 5, 250)]
    [InlineData(TipoMedida.PanturrilhaE, 5, 250)]
    public void Faixa_por_tipo(string tipo, int minimo, int maximo) =>
        Assert.Equal((minimo, maximo), TipoMedida.Faixa(tipo));

    [Fact]
    public void Sao_doze_tipos_e_so_o_peso_e_em_kg()
    {
        Assert.Equal(12, TipoMedida.Todos.Count);
        Assert.Equal("kg", TipoMedida.Unidade(TipoMedida.Peso));
        Assert.All(TipoMedida.Todos.Where(t => t != TipoMedida.Peso), t => Assert.Equal("cm", TipoMedida.Unidade(t)));
    }

    private static Task<FluentValidation.Results.ValidationResult> Validar(DateOnly data, params (string tipo, decimal? valor)[] itens) =>
        new SalvarMedidasValidator().ValidateAsync(new SalvarMedidasEntrada(data, Valores(itens)));

    [Fact]
    public async Task Validador_aceita_valores_nas_faixas_e_remocao_por_nulo()
    {
        var r = await Validar(Dia, (TipoMedida.Cintura, 83.0m), (TipoMedida.Peso, 30m), (TipoMedida.Peito, null));
        Assert.True(r.IsValid);
    }

    [Theory]
    [InlineData(TipoMedida.Peso, 29.9)]
    [InlineData(TipoMedida.Peso, 300.1)]
    [InlineData(TipoMedida.Cintura, 4.9)]
    [InlineData(TipoMedida.Cintura, 250.1)]
    public async Task Validador_recusa_valor_fora_da_faixa_na_chave_do_tipo(string tipo, double valor)
    {
        var r = await Validar(Dia, (tipo, (decimal)valor));

        Assert.False(r.IsValid);
        Assert.Contains(r.Errors, e => e.PropertyName == tipo);
    }

    [Fact]
    public async Task Validador_recusa_mais_de_uma_casa_decimal()
    {
        var r = await Validar(Dia, (TipoMedida.Cintura, 83.25m));
        Assert.False(r.IsValid);
    }

    [Fact]
    public async Task Validador_recusa_tipo_invalido_data_futura_e_corpo_vazio()
    {
        Assert.False((await Validar(Dia, ("COTOVELO", 10m))).IsValid);
        Assert.False((await Validar(DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1), (TipoMedida.Peso, 70m))).IsValid);
        Assert.False((await Validar(Dia)).IsValid);
    }

    [Fact]
    public async Task Validador_mensagem_de_erro_nao_traz_o_valor_digitado()
    {
        var r = await Validar(Dia, (TipoMedida.Peso, 12.3m));
        Assert.DoesNotContain(r.Errors, e => e.ErrorMessage.Contains("12,3") || e.ErrorMessage.Contains("12.3"));
    }

    // ---- Upsert ----

    [Fact]
    public async Task Salvar_cria_so_os_tipos_informados()
    {
        var repo = new RepositorioMedidaFake();
        var servico = new ServicoMedidas(repo);

        var dia = await servico.SalvarDiaAsync(
            Usuario, Dia, Valores((TipoMedida.Cintura, 83.0m), (TipoMedida.Peito, 102.5m)), default);

        Assert.Equal(2, repo.Linhas.Count);
        Assert.Equal(83.0m, dia.Valores[TipoMedida.Cintura]);
        Assert.Equal(102.5m, dia.Valores[TipoMedida.Peito]);
        Assert.False(dia.Valores.ContainsKey(TipoMedida.Peso));
    }

    [Fact]
    public async Task Salvar_no_mesmo_dia_atualiza_sem_duplicar()
    {
        var repo = new RepositorioMedidaFake();
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 84.0m, Dia));
        var servico = new ServicoMedidas(repo);

        await servico.SalvarDiaAsync(Usuario, Dia, Valores((TipoMedida.Cintura, 83.0m)), default);

        var cintura = Assert.Single(repo.Linhas);
        Assert.Equal(83.0m, cintura.Valor);
    }

    [Fact]
    public async Task Valor_nulo_remove_so_aquele_tipo()
    {
        var repo = new RepositorioMedidaFake();
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 84.0m, Dia));
        repo.Linhas.Add(Linha(TipoMedida.Peito, 100.0m, Dia));
        var servico = new ServicoMedidas(repo);

        var dia = await servico.SalvarDiaAsync(Usuario, Dia, Valores((TipoMedida.Peito, null)), default);

        Assert.Equal(TipoMedida.Cintura, Assert.Single(repo.Linhas).Tipo);
        Assert.Equal([TipoMedida.Cintura], dia.Valores.Keys);
    }

    [Fact]
    public async Task Dia_que_ficaria_vazio_e_recusado_sem_gravar()
    {
        var repo = new RepositorioMedidaFake();
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 84.0m, Dia));
        var servico = new ServicoMedidas(repo);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            servico.SalvarDiaAsync(Usuario, Dia, Valores((TipoMedida.Cintura, null)), default));

        Assert.Single(repo.Linhas);
        Assert.Equal(0, repo.Salvou);
    }

    [Fact]
    public async Task Dia_sem_medida_responde_nao_encontrado_ao_ler_e_ao_excluir()
    {
        var servico = new ServicoMedidas(new RepositorioMedidaFake());

        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() => servico.ObterDiaAsync(Usuario, Dia, default));
        await Assert.ThrowsAsync<RecursoNaoEncontradoException>(() => servico.ExcluirDiaAsync(Usuario, Dia, default));
    }

    [Fact]
    public async Task Resumo_traz_ultimas_e_historico_decrescente()
    {
        var repo = new RepositorioMedidaFake();
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 87.0m, Dia.AddDays(-10)));
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 84.0m, Dia));
        repo.Linhas.Add(Linha(TipoMedida.Peso, 78.0m, Dia));
        var servico = new ServicoMedidas(repo);

        var resumo = await servico.ObterResumoAsync(Usuario, default);

        Assert.Equal(2, resumo.Ultimas.Count);
        Assert.Equal([Dia, Dia.AddDays(-10)], resumo.Historico.Select(h => h.Data));
        Assert.Equal(2, resumo.Historico[0].Quantidade);
    }

    // ---- Evolução (PBI-94) ----

    [Fact]
    public void Evolucao_com_varios_pontos_tem_primeira_ultima_e_variacao()
    {
        var evolucao = ServicoMedidas.MontarEvolucao(TipoMedida.Cintura,
        [
            Linha(TipoMedida.Cintura, 84.0m, Dia),
            Linha(TipoMedida.Cintura, 87.0m, Dia.AddDays(-90)),
            Linha(TipoMedida.Cintura, 85.5m, Dia.AddDays(-30)),
        ]);

        Assert.Equal("cm", evolucao.Unidade);
        Assert.Equal([Dia.AddDays(-90), Dia.AddDays(-30), Dia], evolucao.Pontos.Select(p => p.Data)); // em ordem de data
        Assert.Equal(87.0m, evolucao.Primeira!.Valor);
        Assert.Equal(84.0m, evolucao.Ultima!.Valor);
        Assert.Equal(-3.0m, evolucao.Variacao);
    }

    [Fact]
    public void Evolucao_com_um_ponto_nao_tem_variacao()
    {
        var evolucao = ServicoMedidas.MontarEvolucao(TipoMedida.Peso, [Linha(TipoMedida.Peso, 78.0m, Dia)]);

        Assert.Equal("kg", evolucao.Unidade);
        Assert.Equal(evolucao.Primeira, evolucao.Ultima);
        Assert.Null(evolucao.Variacao);
    }

    [Fact]
    public void Evolucao_sem_pontos_e_lista_vazia_nao_erro()
    {
        var evolucao = ServicoMedidas.MontarEvolucao(TipoMedida.Peito, []);

        Assert.Empty(evolucao.Pontos);
        Assert.Null(evolucao.Primeira);
        Assert.Null(evolucao.Ultima);
        Assert.Null(evolucao.Variacao);
    }

    [Fact]
    public async Task Evolucao_filtra_o_periodo_com_limites_inclusive_e_so_o_tipo_pedido()
    {
        var repo = new RepositorioMedidaFake();
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 90.0m, Dia.AddDays(-60)));
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 88.0m, Dia.AddDays(-30)));
        repo.Linhas.Add(Linha(TipoMedida.Cintura, 86.0m, Dia));
        repo.Linhas.Add(Linha(TipoMedida.Peso, 78.0m, Dia));
        var servico = new ServicoMedidas(repo);

        var evolucao = await servico.ObterEvolucaoAsync(
            Usuario, TipoMedida.Cintura, Dia.AddDays(-30), Dia, default);

        Assert.Equal([88.0m, 86.0m], evolucao.Pontos.Select(p => p.Valor));
        Assert.Equal(-2.0m, evolucao.Variacao);
    }

    [Fact]
    public async Task Evolucao_com_tipo_invalido_ou_periodo_invertido_e_argumento_invalido()
    {
        var servico = new ServicoMedidas(new RepositorioMedidaFake());

        await Assert.ThrowsAsync<ArgumentException>(() =>
            servico.ObterEvolucaoAsync(Usuario, "COTOVELO", null, null, default));
        await Assert.ThrowsAsync<ArgumentException>(() =>
            servico.ObterEvolucaoAsync(Usuario, TipoMedida.Peso, Dia, Dia.AddDays(-1), default));
    }}
