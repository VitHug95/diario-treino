namespace DiarioTreino.Application.Identidade;

/// <summary>Persistência do consentimento LGPD (MER 3.13, PBI-87/88).</summary>
public interface IRepositorioConsentimento
{
    /// <summary>
    /// Registra o aceite da versão do termo pelo usuário, se ainda não houver.
    /// Idempotente: aceitar de novo a mesma versão não duplica (índice único
    /// <c>ux_consentimento_usuario_versao</c>). Não chama SaveChanges — o
    /// chamador salva junto da sua transação (ex.: no aceite do vínculo).
    /// </summary>
    public Task RegistrarSeAusenteAsync(Guid usuarioId, string versaoTermo, CancellationToken ct);

    /// <summary>Verdadeiro se o usuário já aceitou a versão do termo informada.</summary>
    public Task<bool> ExisteAsync(Guid usuarioId, string versaoTermo, CancellationToken ct);
}
