namespace DiarioTreino.Application.Relatorios;

/// <summary>
/// Gera o PDF do relatório de progresso (PBI-89). A implementação fica na
/// Infrastructure (QuestPDF é detalhe de IO); a Application só conhece esta
/// porta, mantendo a regra de dependência do MAS 9.1 (o domínio e os casos de
/// uso não conhecem a biblioteca de PDF).
/// </summary>
public interface IGeradorRelatorioPdf
{
    /// <summary>Monta o PDF do relatório e devolve os bytes do arquivo.</summary>
    public byte[] GerarProgresso(RelatorioProgresso relatorio);
}
