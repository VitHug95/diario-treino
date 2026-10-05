namespace DiarioTreino.Application.Identidade;

/// <summary>
/// Dados de identidade extraídos do token do Firebase (claims). A camada de
/// aplicação não conhece JWT nem HTTP; recebe só o que precisa.
/// </summary>
public sealed record IdentidadeDoChamador(
    string FirebaseUid,
    string? Email,
    string? Nome);
