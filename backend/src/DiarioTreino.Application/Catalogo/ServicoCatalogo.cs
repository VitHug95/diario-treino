using DiarioTreino.Domain.Comum;

namespace DiarioTreino.Application.Catalogo;

/// <summary>Casos de uso do catálogo de exercícios (PBI-10).</summary>
public sealed class ServicoCatalogo
{
    private readonly IRepositorioExercicio _repositorio;

    public ServicoCatalogo(IRepositorioExercicio repositorio)
    {
        _repositorio = repositorio;
    }

    public async Task<IReadOnlyList<ExercicioResumo>> ListarAsync(
        Guid usuarioId,
        string? busca,
        string? modalidade,
        CancellationToken ct)
    {
        var modalidadeNormalizada = NormalizarModalidade(modalidade);
        var buscaNormalizada = string.IsNullOrWhiteSpace(busca) ? null : busca.Trim();

        return await _repositorio.BuscarAsync(
            usuarioId,
            buscaNormalizada,
            modalidadeNormalizada,
            ct);
    }

    /// <summary>
    /// Aceita vazio/"TODOS" como "sem filtro" (null). Qualquer outro valor
    /// precisa ser uma modalidade válida.
    /// </summary>
    private static string? NormalizarModalidade(string? modalidade)
    {
        if (string.IsNullOrWhiteSpace(modalidade))
        {
            return null;
        }

        var valor = modalidade.Trim().ToUpperInvariant();
        if (valor == "TODOS")
        {
            return null;
        }

        if (!Modalidade.Todos.Contains(valor))
        {
            throw new ArgumentException(
                $"Modalidade inválida: '{modalidade}'. Use Força, Isometria, Cardio ou Todos.",
                nameof(modalidade));
        }

        return valor;
    }
}
