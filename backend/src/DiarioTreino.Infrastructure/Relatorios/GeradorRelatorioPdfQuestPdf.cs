using System.Globalization;
using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Progresso;
using DiarioTreino.Application.Relatorios;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace DiarioTreino.Infrastructure.Relatorios;

/// <summary>
/// Gera o PDF do relatório de progresso com o QuestPDF (PBI-89). Fica na
/// Infrastructure porque a biblioteca é detalhe de IO; a Application só conhece
/// a porta <see cref="IGeradorRelatorioPdf"/>. Recebe o relatório já pronto
/// (acesso e privacidade tratados a montante) e só desenha.
/// </summary>
public sealed class GeradorRelatorioPdfQuestPdf : IGeradorRelatorioPdf
{
    private static readonly CultureInfo Cultura = new("pt-BR");

    static GeradorRelatorioPdfQuestPdf()
    {
        // Licença Community do QuestPDF (PBI-89): gratuita para projetos/empresas
        // com receita anual abaixo de US$ 1M (é o caso deste app de uso pessoal).
        // Fica no próprio gerador para ele ser autossuficiente — não depende de
        // o DI ter rodado antes (o que também o torna testável isoladamente).
        QuestPDF.Settings.License = LicenseType.Community;
    }

    public byte[] GerarProgresso(RelatorioProgresso relatorio)
    {
        var documento = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(2, Unit.Centimetre);
                page.DefaultTextStyle(x => x.FontSize(10).FontColor(Colors.Grey.Darken4));

                page.Header().Element(c => Cabecalho(c, relatorio));
                page.Content().Element(c => Conteudo(c, relatorio));
                page.Footer().AlignCenter().Text(txt =>
                {
                    txt.Span("Diário de Treino · página ");
                    txt.CurrentPageNumber();
                    txt.Span(" de ");
                    txt.TotalPages();
                });
            });
        });

        return documento.GeneratePdf();
    }

    private static void Cabecalho(IContainer container, RelatorioProgresso r)
    {
        container.Column(col =>
        {
            col.Item().Text("Relatório de progresso")
                .FontSize(18).SemiBold().FontColor(Colors.Blue.Darken2);
            col.Item().PaddingTop(2).Text(r.AtletaNome).FontSize(13).SemiBold();
            col.Item().Text(
                $"Período: {Data(r.De)} a {Data(r.Ate)}  ·  Emitido em {DataHora(r.EmitidoEm)}")
                .FontSize(9).FontColor(Colors.Grey.Darken1);
            if (r.VisaoEducador)
            {
                col.Item().PaddingTop(2).Text(
                    "Observações marcadas como privadas pelo aluno não aparecem neste relatório.")
                    .FontSize(8).Italic().FontColor(Colors.Grey.Darken1);
            }
            col.Item().PaddingTop(8).LineHorizontal(1).LineColor(Colors.Grey.Lighten1);
        });
    }

    private static void Conteudo(IContainer container, RelatorioProgresso r)
    {
        container.PaddingVertical(10).Column(col =>
        {
            col.Spacing(14);
            col.Item().Element(c => SecaoEvolucao(c, r.Evolucoes));
            col.Item().Element(c => SecaoSessoes(c, r.Sessoes));
        });
    }

    private static void SecaoEvolucao(IContainer container, IReadOnlyList<ProgressoExercicio> evolucoes)
    {
        container.Column(col =>
        {
            col.Item().Text("Evolução por exercício").FontSize(13).SemiBold();
            col.Item().PaddingTop(4);

            if (evolucoes.Count == 0)
            {
                col.Item().Text("Sem dados de evolução no período.")
                    .FontColor(Colors.Grey.Darken1).Italic();
                return;
            }

            foreach (var ex in evolucoes)
            {
                col.Item().PaddingTop(6).Element(c => Exercicio(c, ex));
            }
        });
    }

    private static void Exercicio(IContainer container, ProgressoExercicio ex)
    {
        container.Column(col =>
        {
            var unidade = Unidade(ex.Metrica);
            var variacao = ex.Resumo.Variacao is { } v
                ? $"variação {(v >= 0 ? "+" : "")}{Numero(v)} {unidade}".TrimEnd()
                : "variação —";

            col.Item().Text(t =>
            {
                t.Span(ex.Nome).SemiBold();
                t.Span($"   {ex.Resumo.Sessoes} sessões · {variacao}")
                    .FontSize(9).FontColor(Colors.Grey.Darken1);
            });

            col.Item().PaddingTop(3).Table(tabela =>
            {
                tabela.ColumnsDefinition(c =>
                {
                    c.RelativeColumn(2); // data
                    c.RelativeColumn(2); // valor
                    c.RelativeColumn(3); // observação
                });

                tabela.Header(h =>
                {
                    h.Cell().Element(CabecalhoCelula).Text("Data");
                    h.Cell().Element(CabecalhoCelula).Text(RotuloValor(ex.Metrica));
                    h.Cell().Element(CabecalhoCelula).Text("Observação");
                });

                foreach (var p in ex.Pontos)
                {
                    var valor = p.Repeticoes is { } reps
                        ? $"{Numero(p.Valor)} {unidade} × {Numero(reps)}".TrimEnd()
                        : $"{Numero(p.Valor)} {unidade}".TrimEnd();

                    tabela.Cell().Element(Celula).Text(Data(p.Data));
                    tabela.Cell().Element(Celula).Text(valor);
                    tabela.Cell().Element(Celula).Text(p.Observacao ?? "—");
                }
            });
        });
    }

    private static void SecaoSessoes(IContainer container, IReadOnlyList<SessaoResumo> sessoes)
    {
        container.Column(col =>
        {
            col.Item().Text("Sessões do período").FontSize(13).SemiBold();
            col.Item().PaddingTop(4);

            if (sessoes.Count == 0)
            {
                col.Item().Text("Nenhuma sessão registrada no período.")
                    .FontColor(Colors.Grey.Darken1).Italic();
                return;
            }

            col.Item().Table(tabela =>
            {
                tabela.ColumnsDefinition(c =>
                {
                    c.RelativeColumn(2); // data
                    c.RelativeColumn(4); // ficha
                    c.RelativeColumn(2); // exercícios
                    c.RelativeColumn(2); // duração
                });

                tabela.Header(h =>
                {
                    h.Cell().Element(CabecalhoCelula).Text("Data");
                    h.Cell().Element(CabecalhoCelula).Text("Ficha");
                    h.Cell().Element(CabecalhoCelula).Text("Exercícios");
                    h.Cell().Element(CabecalhoCelula).Text("Duração");
                });

                foreach (var s in sessoes)
                {
                    tabela.Cell().Element(Celula).Text(Data(s.Data));
                    tabela.Cell().Element(Celula).Text(s.TreinoNome ?? "Treino livre");
                    tabela.Cell().Element(Celula).Text(s.QuantidadeExercicios.ToString(Cultura));
                    tabela.Cell().Element(Celula).Text(
                        s.DuracaoMin is { } min ? $"{min} min" : "—");
                }
            });
        });
    }

    // ---- Helpers de célula e formatação ----

    private static IContainer CabecalhoCelula(IContainer c) => c
        .BorderBottom(1).BorderColor(Colors.Grey.Lighten1)
        .PaddingVertical(3).DefaultTextStyle(t => t.SemiBold().FontSize(9));

    private static IContainer Celula(IContainer c) => c
        .BorderBottom(1).BorderColor(Colors.Grey.Lighten3)
        .PaddingVertical(3).DefaultTextStyle(t => t.FontSize(9));

    private static string RotuloValor(string? metrica) => metrica switch
    {
        "CARGA" => "Carga",
        "REPETICOES" => "Repetições",
        "TEMPO" => "Tempo",
        _ => "Valor",
    };

    private static string Unidade(string? metrica) => metrica switch
    {
        "CARGA" => "kg",
        "REPETICOES" => "rep",
        "TEMPO" => "s",
        _ => "",
    };

    private static string Data(DateOnly d) => d.ToString("dd/MM/yyyy", Cultura);

    private static string DataHora(DateTimeOffset d) =>
        d.ToLocalTime().ToString("dd/MM/yyyy HH:mm", Cultura);

    private static string Numero(decimal v) => v == Math.Truncate(v)
        ? ((long)v).ToString(Cultura)
        : v.ToString("0.##", Cultura);
}
