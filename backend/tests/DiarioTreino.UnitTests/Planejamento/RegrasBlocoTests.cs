using DiarioTreino.Domain.Planejamento;

namespace DiarioTreino.UnitTests.Planejamento;

/// <summary>Regras do bloco conjugado (PBI-101).</summary>
public sealed class RegrasBlocoTests
{
    private static TreinoExercicio Te(short rodadas) => new() { Id = Guid.NewGuid(), Rodadas = rodadas };

    // ---- Rodadas = maior número de séries ----

    [Fact]
    public void Prancha_2_e_elevacao_4_dao_4_rodadas()
    {
        Assert.Equal(4, RegrasBloco.Rodadas([Te(2), Te(4)]));
    }

    [Fact]
    public void Mesmo_numero_de_series_da_esse_numero()
    {
        Assert.Equal(3, RegrasBloco.Rodadas([Te(3), Te(3)]));
    }

    [Fact]
    public void Sem_membros_da_zero()
    {
        Assert.Equal(0, RegrasBloco.Rodadas([]));
    }

    [Fact]
    public void Limites_do_bloco()
    {
        Assert.Equal(2, RegrasBloco.MinimoMembros);
        Assert.Equal(4, RegrasBloco.MaximoMembros);
        Assert.Equal(600, RegrasBloco.DescansoMaximoSeg);
    }

    // ---- Contiguidade ----

    private static readonly Guid B1 = Guid.NewGuid();
    private static readonly Guid B2 = Guid.NewGuid();

    [Fact]
    public void Ficha_sem_bloco_sempre_respeita()
    {
        Assert.True(RegrasBloco.OrdemRespeitaBlocos([null, null, null]));
        Assert.True(RegrasBloco.OrdemRespeitaBlocos([]));
    }

    [Fact]
    public void Blocos_inteiros_entre_avulsos_respeitam()
    {
        Assert.True(RegrasBloco.OrdemRespeitaBlocos([B1, B1, B2, B2, null, null]));
        Assert.True(RegrasBloco.OrdemRespeitaBlocos([null, B1, B1, null, B2, B2, B2]));
    }

    [Fact]
    public void Avulso_no_meio_do_bloco_quebra()
    {
        Assert.False(RegrasBloco.OrdemRespeitaBlocos([B1, null, B1]));
    }

    [Fact]
    public void Outro_bloco_no_meio_quebra()
    {
        Assert.False(RegrasBloco.OrdemRespeitaBlocos([B1, B2, B1]));
    }

    // ---- Agrupar ----

    [Fact]
    public void Agrupar_membros_separados_leva_para_a_posicao_do_primeiro()
    {
        Guid a = Guid.NewGuid(), b = Guid.NewGuid(), c = Guid.NewGuid(), d = Guid.NewGuid();

        var nova = RegrasBloco.Agrupar([a, b, c, d], [b, d]);

        Assert.Equal([a, b, d, c], nova);
    }

    [Fact]
    public void Agrupar_segue_a_sequencia_dos_membros()
    {
        Guid a = Guid.NewGuid(), b = Guid.NewGuid(), c = Guid.NewGuid();

        var nova = RegrasBloco.Agrupar([a, b, c], [c, a]);

        Assert.Equal([c, a, b], nova);
    }

    [Fact]
    public void Agrupar_vizinhos_nao_muda_nada()
    {
        Guid a = Guid.NewGuid(), b = Guid.NewGuid(), c = Guid.NewGuid();

        Assert.Equal([a, b, c], RegrasBloco.Agrupar([a, b, c], [b, c]));
    }
}
