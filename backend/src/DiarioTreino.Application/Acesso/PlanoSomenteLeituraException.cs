namespace DiarioTreino.Application.Acesso;

/// <summary>
/// Lançada quando o atleta tenta escrever (renomear, criar/editar/excluir ficha
/// ou exercício, excluir) num plano cujo autor é diferente dele — o plano
/// montado pelo professor é somente leitura para o atleta (PBI-44, MAS 11.3).
/// Responde 403 em Problem Details (<c>plano-somente-leitura</c>), SEMPRE depois
/// do controle de acesso: recurso de outro usuário continua respondendo 404.
/// Leitura, iniciar e registrar sessão continuam liberados.
/// </summary>
public sealed class PlanoSomenteLeituraException : Exception
{
    public PlanoSomenteLeituraException()
        : base("Plano somente leitura: só o autor pode editar.")
    {
    }
}
