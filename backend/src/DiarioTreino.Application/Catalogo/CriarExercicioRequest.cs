namespace DiarioTreino.Application.Catalogo;

/// <summary>
/// Dados para criar um exercício próprio (PBI-11/PBI-31). <see cref="MembroId"/>
/// é obrigatório; <see cref="MusculoId"/> é opcional e, se informado, precisa
/// pertencer ao membro.
/// </summary>
public sealed record CriarExercicioRequest(
    string Nome,
    short MembroId,
    short? MusculoId,
    string Modalidade,
    short IntensidadeMetricaId,
    short VolumeMetricaId);
