using DiarioTreino.Application.Execucao;
using DiarioTreino.Domain.Comum;

namespace DiarioTreino.UnitTests.Execucao;

public sealed class CriarSessaoValidatorTests
{
    private readonly CriarSessaoValidator _validator = new();

    private static SerieRequest Serie(short rodada = 1) => new(
        Rodada: rodada,
        Ordem: 1,
        Tipo: TipoEtapa.Esforco,
        IntensidadeMetricaId: 1,
        Intensidade: 30,
        VolumeMetricaId: 10,
        Volume: 10,
        DescansoSeg: 60);

    private static ExercicioSessaoRequest Bloco(Guid exercicioId) => new(
        ExercicioId: exercicioId,
        TreinoExercicioId: null,
        Series: [Serie()]);

    private static CriarSessaoRequest Pedido(params ExercicioSessaoRequest[] exercicios) => new(
        TreinoId: null,
        Data: DateOnly.FromDateTime(DateTime.UtcNow),
        DuracaoMin: null,
        Observacao: null,
        Exercicios: exercicios);

    [Fact]
    public void Exercicio_repetido_na_sessao_e_invalido()
    {
        // PBI-74: o mesmo exercício em dois blocos da sessão é recusado.
        var exercicioId = Guid.NewGuid();
        var resultado = _validator.Validate(Pedido(Bloco(exercicioId), Bloco(exercicioId)));

        Assert.False(resultado.IsValid);
        Assert.Contains(resultado.Errors, e => e.ErrorMessage == "Este exercício já está no treino.");
    }

    [Fact]
    public void Exercicios_distintos_sao_validos()
    {
        var resultado = _validator.Validate(Pedido(Bloco(Guid.NewGuid()), Bloco(Guid.NewGuid())));

        Assert.True(resultado.IsValid);
    }
}
