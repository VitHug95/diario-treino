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
        var usuario = await _repositorio.ObterPorFirebaseUidAsync(identidade.FirebaseUid, ct);

        usuario ??= await ProvisionarAsync(identidade, ct);

        var papeis = usuario.Papeis.Select(p => p.Papel).OrderBy(p => p).ToList();
        return new PerfilUsuario(usuario.Id, usuario.Nome, usuario.Email, papeis);
    }

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

        _repositorio.Adicionar(usuario);
        await _repositorio.SalvarAsync(ct);
        return usuario;
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
