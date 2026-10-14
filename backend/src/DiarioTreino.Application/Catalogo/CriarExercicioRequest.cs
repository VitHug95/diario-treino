namespace DiarioTreino.Application.Catalogo;

/// <summary>
/// Dados para criar um exercício próprio (PBI-11/PBI-31). <see cref="MembroId"/>
/// é obrigatório; <see cref="MusculoId"/> é opcional e, se informado, precisa
/// pertencer ao membro. <see cref="GrupoMuscular"/> é legado (removido na etapa
/// 4 do PBI-31) e não é mais exigido.
/// </summary>
public sealed record CriarExercicioRequest(
    string Nome,
    short MembroId,
    short? MusculoId,
    string Modalidade,
    short IntensidadeMetricaId,
    short VolumeMetricaId,
    string? GrupoMuscular = null);
