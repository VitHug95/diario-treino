using DiarioTreino.Domain.Comum;
using DiarioTreino.Domain.Identidade;

namespace DiarioTreino.Application.Identidade;

/// <summary>
/// Resolve o perfil do usuário logado. No primeiro acesso, provisiona o
/// <see cref="Usuario"/> a partir dos dados do token, com o papel ATLETA
/// (MAS 11.1 / PBI-06).
/// </summary>
public sealed class ServicoPerfil
{
    private readonly IRepositorioUsuario _repositorio;

    public ServicoPerfil(IRepositorioUsuario repositorio)
    {
        _repositorio = repositorio;
    }

    public async Task<PerfilUsuario> ObterOuProvisionarAsync(
        IdentidadeDoChamador identidade,
        CancellationToken ct)
    {
        var usuario = await _repositorio.ObterPorFirebaseUidAsync(identidade.FirebaseUid, ct)
            ?? await ProvisionarAsync(identidade, ct);

        var papeis = usuario.Papeis.Select(p => p.Papel).OrderBy(p => p).ToList();
        return new PerfilUsuario(usuario.Id, usuario.Nome, usuario.Email, papeis);
    }

    /// <summary>
    /// Exclui a conta do usuário logado e todos os seus dados (PBI-25). A
    /// remoção do usuário no Firebase é feita pelo app depois do 204.
    /// </summary>
    public Task ExcluirContaAsync(Guid usuarioId, CancellationToken ct) =>
        _repositorio.ExcluirContaAsync(usuarioId, ct);

    private async Task<Usuario> ProvisionarAsync(
        IdentidadeDoChamador identidade,
        CancellationToken ct)
    {
        var usuario = new Usuario
        {
            Id = Guid.NewGuid(),
            FirebaseUid = identidade.FirebaseUid,
            Nome = string.IsNullOrWhiteSpace(identidade.Nome)
                ? DerivarNome(identidade.Email)
                : identidade.Nome.Trim(),
            Email = (identidade.Email ?? string.Empty).Trim().ToLowerInvariant(),
            Ativo = true,
            CriadoEm = DateTimeOffset.UtcNow,
            Papeis = [],
        };
        usuario.Papeis.Add(new UsuarioPapel { UsuarioId = usuario.Id, Papel = Papeis.Atleta });

        // Tolera corrida: no primeiro acesso o app dispara chamadas autenticadas
        // em paralelo (planos/sessões no boot), e todas tentam provisionar o
        // mesmo usuário. Se a inserção colidir no índice único, outra chamada já
        // criou o usuário — re-busca em vez de estourar 500.
        if (await _repositorio.TentarInserirUsuarioAsync(usuario, ct))
        {
            return usuario;
        }

        var existente = await _repositorio.ObterPorFirebaseUidAsync(identidade.FirebaseUid, ct);
        // Em tese sempre existe aqui (o conflito prova que foi inserido); a
        // checagem evita um null silencioso se a corrida for em outra coluna.
        return existente
            ?? throw new InvalidOperationException(
                "Falha ao provisionar o usuário: conflito de inserção sem registro correspondente.");
    }

    private static string DerivarNome(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            return "Atleta";
        }

        var local = email.Split('@')[0];
        return string.IsNullOrWhiteSpace(local) ? "Atleta" : local;
    }
}
