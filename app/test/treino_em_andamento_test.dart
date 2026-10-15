import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TreinoEmAndamento _exemplo() => TreinoEmAndamento(
      treinoId: 'A',
      treinoNome: 'Treino A',
      treinoLivre: false,
      dataIso: '2026-10-02',
      inicioMillis: 1700000000000,
      exercicios: [
        ExercicioEmAndamento(
          treinoExercicioId: 'te1',
          exercicioId: 'ex1',
          nome: 'Supino reto',
          modalidade: 'FORCA',
          origemPreenchimento: 'Preenchido com o último treino (27/09)',
          foraDaFicha: false,
          realizado: true,
          series: const [
            SerieEmAndamento(
              rodada: 1,
              ordem: 1,
              tipo: 'ESFORCO',
              intensidadeMetricaId: 1,
              intensidadeMetricaCodigo: 'CARGA_KG',
              intensidadeMetricaNome: 'Carga',
              intensidadeTexto: '30',
              volumeMetricaId: 10,
              volumeMetricaCodigo: 'REPETICOES',
              volumeMetricaNome: 'Repetições',
              volumeTexto: '10',
              descansoTexto: '90',
            ),
          ],
        ),
      ],
    );

void main() {
  test('rascunho sobrevive a fechar e reabrir o app (PBI-37)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = RascunhoTreinoService(prefs);

    expect(service.carregar(), isNull);

    await service.salvar(_exemplo());

    // Simula reabrir: um service novo lendo as mesmas prefs.
    final outro = RascunhoTreinoService(prefs);
    final lido = outro.carregar();
    expect(lido, isNotNull);
    expect(lido!.treinoId, 'A');
    expect(lido.treinoNome, 'Treino A');
    expect(lido.dataIso, '2026-10-02');
    expect(lido.inicioMillis, 1700000000000);
    final ex = lido.exercicios.single;
    expect(ex.realizado, isTrue);
    expect(ex.nome, 'Supino reto');
    final s = ex.series.single;
    expect(s.intensidadeTexto, '30');
    expect(s.volumeTexto, '10');
    expect(s.descansoTexto, '90');
  });

  test('limpar apaga o rascunho (finalizar/descartar)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = RascunhoTreinoService(prefs);

    await service.salvar(_exemplo());
    expect(service.carregar(), isNotNull);

    await service.limpar();
    expect(service.carregar(), isNull);
  });

  test('round-trip reconstrói o estado vivo (paraEdicao)', () async {
    final ex = _exemplo().exercicios.single.paraEdicao();
    expect(ex.realizado, isTrue);
    expect(ex.foraDaFicha, isFalse);
    expect(ex.series.single.intensidade.text, '30');
    expect(ex.series.single.volume.text, '10');
    // E de volta para o rascunho mantém os textos digitados.
    final rascunho = exercicioParaRascunho(ex);
    expect(rascunho.series.single.volumeTexto, '10');
    expect(rascunho.realizado, isTrue);
  });
}
