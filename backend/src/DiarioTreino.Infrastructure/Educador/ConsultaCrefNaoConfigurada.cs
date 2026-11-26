using DiarioTreino.Application.Educador;

namespace DiarioTreino.Infrastructure.Educador;

/// <summary>
/// Consulta do CREF enquanto o leitor do site real não existe (PBI-106, parte
/// 1): sempre <see cref="ResultadoConsultaCref.Indisponivel"/>, que nunca recusa
/// nem gasta tentativa. O leitor real (Spiderware, configurado por UF) depende
/// das páginas de resultado salvas pelo PO (docs/INVESTIGACAO-CREF.md, seção 5).
/// </summary>
public sealed class ConsultaCrefNaoConfigurada : IConsultaCref
{
    public Task<ResultadoConsultaCref> ConsultarPorCpfAsync(string uf, string cpf, CancellationToken ct) =>
        Task.FromResult<ResultadoConsultaCref>(new ResultadoConsultaCref.Indisponivel());
}
