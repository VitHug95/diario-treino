using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Progresso;

namespace DiarioTreino.Application.Relatorios;

/// <summary>
/// Dados do relatório de progresso para gerar o PDF (PBI-89): cabeçalho +
/// evolução por exercício + sessões do período. É montado pelo
/// <see cref="ServicoRelatorio"/> reusando os serviços de progresso e sessão
/// (que já aplicam o controle de acesso e ocultam a observação privada do
/// educador). O gerador de PDF recebe este DTO pronto — não lê o banco nem
/// conhece a regra de acesso.
/// </summary>
public sealed record RelatorioProgresso(
    string AtletaNome,
    DateOnly De,
    DateOnly Ate,
    DateTimeOffset EmitidoEm,
    /// <summary>
    /// true quando quem pediu o relatório é um educador (logado ≠ atleta): a
    /// observação privada do aluno já vem ocultada nos dados e o PDF avisa isso.
    /// </summary>
    bool VisaoEducador,
    IReadOnlyList<ProgressoExercicio> Evolucoes,
    IReadOnlyList<SessaoResumo> Sessoes);
