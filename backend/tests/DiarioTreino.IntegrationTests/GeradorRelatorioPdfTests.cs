using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Progresso;
using DiarioTreino.Application.Relatorios;
using DiarioTreino.Infrastructure.Relatorios;

namespace DiarioTreino.IntegrationTests;

/// <summary>
/// Teste do gerador de PDF (PBI-89) isolado: não usa banco nem HTTP, só exercita
/// o QuestPDF com um relatório em memória. Garante que a licença Community está
/// configurada e que a saída é um PDF válido (assinatura "%PDF"). Roda local,
/// sem Docker.
/// </summary>
public sealed class GeradorRelatorioPdfTests
{
    private static RelatorioProgresso Exemplo(bool visaoEducador = false) => new(
        AtletaNome: "João da Silva",
        De: new DateOnly(2026, 7, 4),
        Ate: new DateOnly(2026, 10, 2),
        EmitidoEm: DateTimeOffset.UtcNow,
        VisaoEducador: visaoEducador,
        Evolucoes:
        [
            new ProgressoExercicio(
                Guid.NewGuid(), "Supino reto", "FORCA", "CARGA",
                [
                    new PontoProgresso(new DateOnly(2026, 7, 10), 40m, 10m, Guid.NewGuid(), null),
                    new PontoProgresso(new DateOnly(2026, 8, 10), 45m, 8m, Guid.NewGuid(), "pesado"),
                    new PontoProgresso(new DateOnly(2026, 9, 10), 50m, 8m, Guid.NewGuid(), null),
                ],
                new ResumoProgresso(3, 10m, 1)),
        ],
        Sessoes:
        [
            new SessaoResumo(Guid.NewGuid(), new DateOnly(2026, 9, 10), null, "Treino A", 5, 50, false),
            new SessaoResumo(Guid.NewGuid(), new DateOnly(2026, 8, 10), null, null, 3, null, true),
        ]);

    private static bool EhPdf(byte[] b) =>
        b.Length > 4 && b[0] == (byte)'%' && b[1] == (byte)'P' && b[2] == (byte)'D' && b[3] == (byte)'F';

    [Fact]
    public void Gera_um_pdf_valido_com_evolucoes_e_sessoes()
    {
        var gerador = new GeradorRelatorioPdfQuestPdf();

        var bytes = gerador.GerarProgresso(Exemplo());

        Assert.NotEmpty(bytes);
        Assert.True(EhPdf(bytes), "a saída deveria começar com %PDF");
    }

    [Fact]
    public void Gera_pdf_mesmo_sem_evolucoes_nem_sessoes()
    {
        var gerador = new GeradorRelatorioPdfQuestPdf();
        var vazio = Exemplo() with { Evolucoes = [], Sessoes = [] };

        var bytes = gerador.GerarProgresso(vazio);

        Assert.True(EhPdf(bytes));
    }

    [Fact]
    public void Visao_educador_tambem_gera_pdf_valido()
    {
        var gerador = new GeradorRelatorioPdfQuestPdf();

        var bytes = gerador.GerarProgresso(Exemplo(visaoEducador: true));

        Assert.True(EhPdf(bytes));
    }
}
