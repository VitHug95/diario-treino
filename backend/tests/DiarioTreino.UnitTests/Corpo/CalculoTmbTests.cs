using DiarioTreino.Application.Corpo;
using DiarioTreino.Domain.Corpo;

namespace DiarioTreino.UnitTests.Corpo;

public sealed class CalculoTmbTests
{
    private static readonly DateOnly Hoje = new(2026, 11, 9);

    // 31 anos completos em 09/11/2026.
    private static readonly DateOnly Nasc31 = new(1995, 5, 20);

    // ---- Fórmula (Mifflin-St Jeor) ----

    [Fact]
    public void Homem_31_anos_180cm_78kg_da_1755()
    {
        var r = CalculoTmb.Calcular("M", Nasc31, 180, 78.0m, Hoje);

        Assert.Equal(1755, r.Kcal);
        Assert.Null(r.Motivo);
    }

    [Fact]
    public void Mulher_31_anos_165cm_60kg_da_1315_com_a_constante_menos_161()
    {
        var r = CalculoTmb.Calcular("F", Nasc31, 165, 60.0m, Hoje);

        Assert.Equal(1315, r.Kcal); // 1315,25 arredondado
    }

    [Fact]
    public void Arredonda_meio_para_cima()
    {
        // 10×70,1 + 6,25×170 − 5×31 + 5 = 701 + 1062,5 − 155 + 5 = 1613,5 → 1614
        var r = CalculoTmb.Calcular("M", Nasc31, 170, 70.1m, Hoje);

        Assert.Equal(1614, r.Kcal);
    }

    // ---- Dado faltando e menor de idade ----

    [Theory]
    [InlineData(null, 1995, 180, 78)]
    [InlineData("M", null, 180, 78)]
    [InlineData("M", 1995, null, 78)]
    [InlineData("M", 1995, 180, null)]
    public void Faltando_qualquer_dado_nao_ha_numero(string? sexo, int? anoNascimento, int? altura, int? peso)
    {
        DateOnly? nascimento = anoNascimento is { } ano ? new DateOnly(ano, 5, 20) : null;

        var r = CalculoTmb.Calcular(sexo, nascimento, altura, peso, Hoje);

        Assert.Null(r.Kcal);
        Assert.Equal(MotivoSemTmb.DadosIncompletos, r.Motivo);
    }

    [Fact]
    public void Sexo_invalido_conta_como_dado_incompleto()
    {
        var r = CalculoTmb.Calcular("X", Nasc31, 180, 78.0m, Hoje);

        Assert.Equal(MotivoSemTmb.DadosIncompletos, r.Motivo);
    }

    [Fact]
    public void Aos_17_anos_nao_ha_numero_e_aos_18_ha()
    {
        // 18 anos completos hoje; 17 anos e 364 dias amanhã de manhã.
        var faz18Hoje = Hoje.AddYears(-18);
        var faz18Amanha = Hoje.AddYears(-18).AddDays(1);

        var com18 = CalculoTmb.Calcular("M", faz18Hoje, 180, 78.0m, Hoje);
        var com17 = CalculoTmb.Calcular("M", faz18Amanha, 180, 78.0m, Hoje);

        Assert.NotNull(com18.Kcal);
        Assert.Null(com17.Kcal);
        Assert.Equal(MotivoSemTmb.MenorDeIdade, com17.Motivo);
    }

    [Fact]
    public void Dado_incompleto_vem_antes_de_menor_de_idade()
    {
        var r = CalculoTmb.Calcular("M", Hoje.AddYears(-10), null, 40m, Hoje);

        Assert.Equal(MotivoSemTmb.DadosIncompletos, r.Motivo);
    }

    // ---- Idade ----

    [Fact]
    public void Idade_no_dia_do_aniversario_ja_conta_o_ano()
    {
        var nascimento = new DateOnly(1995, 11, 9);

        Assert.Equal(31, CalculoTmb.IdadeEm(nascimento, new DateOnly(2026, 11, 9)));
        Assert.Equal(30, CalculoTmb.IdadeEm(nascimento, new DateOnly(2026, 11, 8)));
    }

    [Fact]
    public void Nascido_em_29_de_fevereiro_faz_anos_em_28_nos_anos_nao_bissextos()
    {
        var nascimento = new DateOnly(2000, 2, 29);

        // Em ano bissexto o aniversário é em 29/02; nos demais, em 28/02.
        Assert.Equal(25, CalculoTmb.IdadeEm(nascimento, new DateOnly(2026, 2, 27)));
        Assert.Equal(26, CalculoTmb.IdadeEm(nascimento, new DateOnly(2026, 2, 28)));
        Assert.Equal(24, CalculoTmb.IdadeEm(nascimento, new DateOnly(2025, 2, 27)));
        Assert.Equal(25, CalculoTmb.IdadeEm(nascimento, new DateOnly(2025, 2, 28)));
        Assert.Equal(23, CalculoTmb.IdadeEm(nascimento, new DateOnly(2024, 2, 28)));
        Assert.Equal(24, CalculoTmb.IdadeEm(nascimento, new DateOnly(2024, 2, 29)));
    }

    // ---- Validação do PUT ----

    private static SalvarPerfilCorporalRequest Pedido(
        string? sexo = "M",
        DateOnly? nascimento = null,
        short? altura = 180,
        decimal? peso = 78.0m,
        DateOnly? dataPeso = null) =>
        new(sexo, nascimento ?? Nasc31, altura, peso, dataPeso);

    private static Task<FluentValidation.Results.ValidationResult> Validar(SalvarPerfilCorporalRequest r) =>
        new SalvarPerfilCorporalValidator().ValidateAsync(r);

    [Fact]
    public async Task Validador_aceita_dados_completos_e_tudo_nulo()
    {
        Assert.True((await Validar(Pedido())).IsValid);
        Assert.True((await Validar(new SalvarPerfilCorporalRequest(null, null, null, null, null))).IsValid);
    }

    [Theory]
    [InlineData(99)]
    [InlineData(251)]
    public async Task Validador_recusa_altura_fora_de_100_a_250(short altura)
    {
        var r = await Validar(Pedido(altura: altura));

        Assert.False(r.IsValid);
        Assert.Contains(r.Errors, e => e.PropertyName == nameof(SalvarPerfilCorporalRequest.AlturaCm));
    }

    [Theory]
    [InlineData(100)]
    [InlineData(250)]
    public async Task Validador_aceita_os_limites_da_altura(short altura) =>
        Assert.True((await Validar(Pedido(altura: altura))).IsValid);

    [Theory]
    [InlineData(29.9)]
    [InlineData(300.1)]
    public async Task Validador_recusa_peso_fora_de_30_a_300(double peso) =>
        Assert.False((await Validar(Pedido(peso: (decimal)peso))).IsValid);

    [Fact]
    public async Task Validador_recusa_peso_com_mais_de_uma_casa_decimal() =>
        Assert.False((await Validar(Pedido(peso: 78.25m))).IsValid);

    [Fact]
    public async Task Validador_recusa_sexo_diferente_de_M_ou_F() =>
        Assert.False((await Validar(Pedido(sexo: "X"))).IsValid);

    [Fact]
    public async Task Validador_recusa_nascimento_no_futuro_ou_hoje()
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow);

        Assert.False((await Validar(Pedido(nascimento: hoje))).IsValid);
        Assert.False((await Validar(Pedido(nascimento: hoje.AddDays(1)))).IsValid);
    }

    [Fact]
    public async Task Validador_exige_idade_entre_10_e_100_anos()
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow);

        Assert.False((await Validar(Pedido(nascimento: hoje.AddYears(-9)))).IsValid);
        Assert.True((await Validar(Pedido(nascimento: hoje.AddYears(-10)))).IsValid);
        Assert.True((await Validar(Pedido(nascimento: hoje.AddYears(-100)))).IsValid);
        Assert.False((await Validar(Pedido(nascimento: hoje.AddYears(-101)))).IsValid);
    }

    [Fact]
    public async Task Validador_recusa_data_do_peso_no_futuro()
    {
        var amanha = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(1);

        Assert.False((await Validar(Pedido(dataPeso: amanha))).IsValid);
    }

    [Fact]
    public async Task Validador_nao_repete_o_valor_digitado_na_mensagem()
    {
        var r = await Validar(Pedido(peso: 12.3m, altura: 77));

        Assert.All(r.Errors, e => Assert.DoesNotContain("12,3", e.ErrorMessage));
        Assert.All(r.Errors, e => Assert.DoesNotContain("77", e.ErrorMessage));
    }
}
