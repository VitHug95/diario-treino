using DiarioTreino.Application.Acesso;
using DiarioTreino.Application.Identidade;
using DiarioTreino.Domain.Corpo;
using DiarioTreino.Domain.Identidade;

namespace DiarioTreino.Application.Corpo;

/// <summary>
/// Dados corporais do próprio usuário e a TMB (E12 / PBI-93). Sexo, nascimento e
/// altura moram em <c>usuario</c>; o peso mora nas medidas (PBI-91) e a TMB usa
/// sempre o peso mais recente. Só o dono lê e grava (rotas sob <c>/me</c>); o
/// acesso do educador virá em rotas próprias (PBI-95). Nenhum valor vai para log.
/// </summary>
public sealed class ServicoPerfilCorporal
{
    private readonly IRepositorioUsuario _usuarios;
    private readonly IRepositorioMedida _medidas;
    private readonly ServicoMedidas _servicoMedidas;

    public ServicoPerfilCorporal(
        IRepositorioUsuario usuarios,
        IRepositorioMedida medidas,
        ServicoMedidas servicoMedidas)
    {
        _usuarios = usuarios;
        _medidas = medidas;
        _servicoMedidas = servicoMedidas;
    }

    public async Task<PerfilCorporalResposta> ObterAsync(Guid usuarioId, CancellationToken ct)
    {
        var usuario = await CarregarAsync(usuarioId, ct);
        return await MontarAsync(usuario, ct);
    }

    /// <summary>
    /// Substitui sexo, nascimento e altura (nulo limpa). Com <c>PesoKg</c>, grava
    /// a medida PESO do dia (upsert). Tudo no mesmo <c>SaveChanges</c>: o contexto
    /// é o mesmo do serviço de medidas, então usuário e peso entram juntos ou
    /// nenhum entra.
    /// </summary>
    public async Task<PerfilCorporalResposta> SalvarAsync(
        Guid usuarioId,
        SalvarPerfilCorporalRequest request,
        CancellationToken ct)
    {
        var usuario = await CarregarAsync(usuarioId, ct);
        usuario.Sexo = request.Sexo;
        usuario.DataNascimento = request.DataNascimento;
        usuario.AlturaCm = request.AlturaCm;

        if (request.PesoKg is { } peso)
        {
            var dia = request.DataPeso ?? Hoje();
            await _servicoMedidas.SalvarDiaAsync(
                usuarioId,
                dia,
                new Dictionary<string, decimal?> { [TipoMedida.Peso] = peso },
                ct);
        }
        else
        {
            await _usuarios.SalvarAsync(ct);
        }

        return await MontarAsync(usuario, ct);
    }

    /// <summary>
    /// Limpa sexo, nascimento e altura. NÃO apaga o histórico de peso: ele
    /// pertence às medidas e se apaga por lá.
    /// </summary>
    public async Task LimparAsync(Guid usuarioId, CancellationToken ct)
    {
        var usuario = await CarregarAsync(usuarioId, ct);
        usuario.Sexo = null;
        usuario.DataNascimento = null;
        usuario.AlturaCm = null;
        await _usuarios.SalvarAsync(ct);
    }

    private async Task<Usuario> CarregarAsync(Guid usuarioId, CancellationToken ct) =>
        await _usuarios.ObterPorIdAsync(usuarioId, ct) ?? throw new RecursoNaoEncontradoException();

    private async Task<PerfilCorporalResposta> MontarAsync(Usuario usuario, CancellationToken ct)
    {
        var peso = await _medidas.UltimoValorAsync(usuario.Id, TipoMedida.Peso, ct);
        var hoje = Hoje();
        var tmb = CalculoTmb.Calcular(usuario.Sexo, usuario.DataNascimento, usuario.AlturaCm, peso, hoje);
        int? idade = usuario.DataNascimento is { } nascimento
            ? CalculoTmb.IdadeEm(nascimento, hoje)
            : null;

        return new PerfilCorporalResposta(
            usuario.Sexo,
            usuario.DataNascimento,
            usuario.AlturaCm,
            peso,
            idade,
            tmb.Kcal,
            tmb.Motivo);
    }

    private static DateOnly Hoje() => DateOnly.FromDateTime(DateTime.UtcNow);
}
