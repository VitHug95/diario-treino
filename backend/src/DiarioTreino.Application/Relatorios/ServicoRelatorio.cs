using DiarioTreino.Application.Execucao;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Application.Progresso;

namespace DiarioTreino.Application.Relatorios;

/// <summary>
/// Monta o relatório de progresso em PDF (PBI-89). Reusa o
/// <see cref="ServicoProgresso"/> e o <see cref="ServicoSessao"/>, que já
/// aplicam a regra do MAS 11.3 (<c>IControleAcesso</c>) e ocultam a observação
/// privada do aluno quando quem pede é o educador. O relatório é do atleta-alvo:
/// o próprio usuário logado ou, no modo educador, um aluno com vínculo ativo —
/// sem acesso, os serviços lançam 404.
/// </summary>
public sealed class ServicoRelatorio
{
    private readonly ServicoProgresso _progresso;
    private readonly ServicoSessao _sessoes;
    private readonly IRepositorioUsuario _usuarios;
    private readonly IGeradorRelatorioPdf _gerador;

    public ServicoRelatorio(
        ServicoProgresso progresso,
        ServicoSessao sessoes,
        IRepositorioUsuario usuarios,
        IGeradorRelatorioPdf gerador)
    {
        _progresso = progresso;
        _sessoes = sessoes;
        _usuarios = usuarios;
        _gerador = gerador;
    }

    /// <summary>
    /// Gera o PDF do progresso do atleta-alvo no período. Sem <paramref name="de"/>/
    /// <paramref name="ate"/>, usa os últimos 90 dias (padrão do gráfico). Devolve
    /// os bytes do arquivo. O acesso é garantido pelos serviços reusados: a
    /// PRIMEIRA leitura (exercícios com histórico) já responde 404 quando o
    /// usuário não pode ver o atleta, antes de qualquer dado ser exposto.
    /// </summary>
    public async Task<byte[]> GerarProgressoPdfAsync(
        Guid usuarioLogadoId,
        Guid atletaId,
        DateOnly? de,
        DateOnly? ate,
        CancellationToken ct)
    {
        var hoje = DateOnly.FromDateTime(DateTime.UtcNow.Date);
        var inicio = de ?? hoje.AddDays(-90);
        var fim = ate ?? hoje;

        // Garante o acesso (404 se não puder) ANTES de montar qualquer coisa.
        var exercicios = await _progresso.ListarExerciciosComHistoricoAsync(
            usuarioLogadoId, atletaId, ct);

        // Evolução de cada exercício no período (nome e métrica já resolvidos; a
        // observação privada já vem ocultada quando logado ≠ atleta).
        var evolucoes = new List<ProgressoExercicio>();
        foreach (var ex in exercicios)
        {
            var evolucao = await _progresso.ObterProgressoAsync(
                usuarioLogadoId, atletaId, ex.Id, inicio, fim, ct);
            // Só entram os exercícios com algum ponto no período.
            if (evolucao.Pontos.Count > 0)
            {
                evolucoes.Add(evolucao);
            }
        }

        var sessoes = await _sessoes.ListarSessoesAsync(
            usuarioLogadoId, atletaId, inicio, fim, ct);

        var atleta = await _usuarios.ObterPorIdAsync(atletaId, ct);
        var nome = atleta?.Nome ?? "Atleta";

        var relatorio = new RelatorioProgresso(
            AtletaNome: nome,
            De: inicio,
            Ate: fim,
            EmitidoEm: DateTimeOffset.UtcNow,
            VisaoEducador: usuarioLogadoId != atletaId,
            Evolucoes: evolucoes,
            Sessoes: sessoes);

        return _gerador.GerarProgresso(relatorio);
    }
}
