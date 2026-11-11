using DiarioTreino.Application.Acesso;
using DiarioTreino.Domain.Corpo;

namespace DiarioTreino.Application.Corpo;

/// <summary>
/// Medidas corporais do próprio usuário (E12 / PBI-91). Tudo sob <c>/me</c>: o
/// usuário só alcança as próprias linhas (filtro por <c>usuarioId</c> em toda
/// consulta), então não há id de outro usuário a recusar. O acesso do educador
/// virá em rotas próprias (PBI-95).
/// </summary>
public sealed class ServicoMedidas
{
    private readonly IRepositorioMedida _repositorio;

    public ServicoMedidas(IRepositorioMedida repositorio)
    {
        _repositorio = repositorio;
    }

    public async Task<ResumoMedidas> ObterResumoAsync(Guid usuarioId, CancellationToken ct)
    {
        var recentes = await _repositorio.UltimasDuasPorTipoAsync(usuarioId, ct);
        var historico = await _repositorio.HistoricoAsync(usuarioId, ct);
        return new ResumoMedidas(MontarUltimas(recentes), historico);
    }

    /// <summary>
    /// Valor atual de cada tipo e a variação para o registro anterior daquele
    /// mesmo tipo, mesmo que as outras medidas tenham sido feitas em outras datas.
    /// Tipos sem registro não aparecem.
    /// </summary>
    public static IReadOnlyList<UltimaMedida> MontarUltimas(IEnumerable<MedidaCorporal> medidas)
    {
        var porTipo = medidas.GroupBy(m => m.Tipo).ToDictionary(g => g.Key, g => g.OrderByDescending(m => m.Data).ToList());

        var resultado = new List<UltimaMedida>();
        foreach (var tipo in TipoMedida.Todos)
        {
            if (!porTipo.TryGetValue(tipo, out var registros))
            {
                continue;
            }

            var atual = registros[0];
            decimal? variacao = registros.Count > 1 ? atual.Valor - registros[1].Valor : null;
            resultado.Add(new UltimaMedida(tipo, atual.Valor, atual.Data, variacao));
        }

        return resultado;
    }

    /// <summary>
    /// Evolução de um tipo no período. Tipo desconhecido ou período invertido
    /// viram <see cref="ArgumentException"/> (400). Sem registro, lista vazia.
    /// </summary>
    public async Task<EvolucaoMedida> ObterEvolucaoAsync(
        Guid usuarioId, string tipo, DateOnly? de, DateOnly? ate, CancellationToken ct)
    {
        if (!TipoMedida.EhValido(tipo))
        {
            throw new ArgumentException("Tipo de medida inválido.");
        }

        if (de is not null && ate is not null && de > ate)
        {
            throw new ArgumentException("O início do período não pode ser depois do fim.");
        }

        var linhas = await _repositorio.ListarEvolucaoAsync(usuarioId, tipo, de, ate, ct);
        return MontarEvolucao(tipo, linhas);
    }

    /// <summary>Primeira, última e variação (última − primeira) de pontos em ordem de data.</summary>
    public static EvolucaoMedida MontarEvolucao(string tipo, IEnumerable<MedidaCorporal> linhas)
    {
        var pontos = linhas
            .OrderBy(m => m.Data)
            .Select(m => new PontoMedida(m.Data, m.Valor))
            .ToList();
        var primeira = pontos.Count > 0 ? pontos[0] : null;
        var ultima = pontos.Count > 0 ? pontos[^1] : null;
        decimal? variacao = pontos.Count > 1 ? ultima!.Valor - primeira!.Valor : null;
        return new EvolucaoMedida(tipo, TipoMedida.Unidade(tipo), pontos, primeira, ultima, variacao);
    }

    public async Task<DiaMedidas> ObterDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct)
    {
        var doDia = await _repositorio.ListarDoDiaAsync(usuarioId, data, ct);
        if (doDia.Count == 0)
        {
            throw new RecursoNaoEncontradoException();
        }

        return Montar(doDia.ToDictionary(m => m.Tipo, m => m.Valor));
    }

    /// <summary>
    /// Upsert por tipo no dia. Valor nulo remove só aquele tipo. Se o dia ficaria
    /// sem nenhum valor, recusa (<see cref="ArgumentException"/> → 400): para
    /// apagar o dia existe <see cref="ExcluirDiaAsync"/>.
    /// </summary>
    public async Task<DiaMedidas> SalvarDiaAsync(
        Guid usuarioId,
        DateOnly data,
        IReadOnlyDictionary<string, decimal?> valores,
        CancellationToken ct)
    {
        var existentes = (await _repositorio.ListarDoDiaAsync(usuarioId, data, ct))
            .ToDictionary(m => m.Tipo);

        // Primeiro decide o estado final do dia; só então mexe nas linhas.
        var final = existentes.ToDictionary(e => e.Key, e => e.Value.Valor);
        foreach (var (tipo, valor) in valores)
        {
            if (valor is null)
            {
                final.Remove(tipo);
            }
            else
            {
                final[tipo] = valor.Value;
            }
        }

        if (final.Count == 0)
        {
            throw new ArgumentException("Informe ao menos uma medida. Para apagar o dia, exclua a medição.");
        }

        foreach (var (tipo, valor) in valores)
        {
            existentes.TryGetValue(tipo, out var atual);
            if (valor is null)
            {
                if (atual is not null)
                {
                    _repositorio.Remover(atual);
                }
            }
            else if (atual is not null)
            {
                atual.Valor = valor.Value;
            }
            else
            {
                _repositorio.Adicionar(new MedidaCorporal
                {
                    Id = Guid.NewGuid(),
                    UsuarioId = usuarioId,
                    Data = data,
                    Tipo = tipo,
                    Valor = valor.Value,
                    CriadoEm = DateTimeOffset.UtcNow,
                });
            }
        }

        await _repositorio.SalvarAsync(ct);
        return Montar(final);
    }

    public async Task ExcluirDiaAsync(Guid usuarioId, DateOnly data, CancellationToken ct)
    {
        var removidas = await _repositorio.ExcluirDiaAsync(usuarioId, data, ct);
        if (removidas == 0)
        {
            throw new RecursoNaoEncontradoException();
        }
    }

    private static DiaMedidas Montar(Dictionary<string, decimal> valores) =>
        new(TipoMedida.Todos.Where(valores.ContainsKey).ToDictionary(t => t, t => valores[t]));
}
