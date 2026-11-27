namespace DiarioTreino.Application.Educador;

/// <summary>
/// Corpo de <c>POST /me/educador/cref/verificar</c>. O <see cref="Cpf"/> só vive
/// na memória durante a chamada: não vai para banco, log nem resposta. O
/// <see cref="ToString"/> é sobrescrito para ele nunca aparecer por engano.
/// </summary>
/// <param name="PermiteConsulta">
/// O usuário marcou "Eu permito" o uso dos dados pessoais para validar o CREF.
/// Sem <c>true</c>, nada é consultado (400) e o modo educador não é habilitado.
/// </param>
public sealed record VerificarCrefRequest(string? Uf, string? Numero, string? Cpf, bool? PermiteConsulta = null)
{
    public override string ToString() =>
        $"VerificarCrefRequest {{ Uf = {Uf}, Numero = {Numero}, Cpf = ***, PermiteConsulta = {PermiteConsulta} }}";
}

/// <summary>Resposta da verificação: nunca traz CPF nem nome.</summary>
public sealed record VerificarCrefResposta(string Resultado, string? Motivo, string? Situacao);

/// <summary>Registro guardado do próprio usuário.</summary>
public sealed record RegistroCrefResposta(
    string? Uf, string? Numero, string? Situacao, string? Categoria, string Origem, DateTimeOffset? ConsultadoEm);

/// <summary>
/// <c>GET /me/educador/cref</c>: se a verificação é exigida (chave da PBI-106) e
/// o registro do usuário, se houver.
/// </summary>
public sealed record SituacaoCrefResposta(bool VerificacaoExigida, RegistroCrefResposta? Registro);
