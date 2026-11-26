import 'dart:convert';

import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('versão do formato no aparelho', () {
    Future<SharedPreferences> prefsCom(Object? valor) async {
      SharedPreferences.setMockInitialValues(
          {if (valor != null) 'treino_em_andamento': valor is String ? valor : jsonEncode(valor)});
      return SharedPreferences.getInstance();
    }

    test('grava o número da versão atual', () async {
      final prefs = await prefsCom(null);
      await RascunhoTreinoService(prefs).salvar(_exemplo());

      final json = jsonDecode(prefs.getString('treino_em_andamento')!) as Map<String, dynamic>;
      expect(json['versao'], TreinoEmAndamento.versaoAtual);
    });

    test('rascunho da versão 0 (sem "versao", formato até o #151) abre igual', () async {
      // Rascunho real de antes dos campos opcionais (concluido, blocoId,
      // marcador, feita, blocos) e do número de versão.
      final prefs = await prefsCom({
        'treinoId': 'A',
        'treinoNome': 'Treino A',
        'treinoLivre': false,
        'dataIso': '2026-10-02',
        'inicioMillis': 1700000000000,
        'exercicios': [
          {
            'treinoExercicioId': 'te1',
            'exercicioId': 'ex1',
            'nome': 'Supino reto',
            'modalidade': 'FORCA',
            'origemPreenchimento': null,
            'foraDaFicha': false,
            'realizado': true,
            'series': [
              {
                'rodada': 1,
                'ordem': 1,
                'tipo': 'ESFORCO',
                'intensidadeMetricaId': 1,
                'intensidadeMetricaCodigo': 'CARGA_KG',
                'intensidadeMetricaNome': 'Carga',
                'intensidadeTexto': '30',
                'volumeMetricaId': 10,
                'volumeMetricaCodigo': 'REPETICOES',
                'volumeMetricaNome': 'Repetições',
                'volumeTexto': '10',
                'descansoTexto': '90',
              },
            ],
          },
        ],
      });

      final lido = RascunhoTreinoService(prefs).carregar();

      expect(lido, isNotNull);
      expect(lido!.exercicios.single.series.single.intensidadeTexto, '30');
      expect(lido.exercicios.single.concluido, isFalse);
      expect(lido.exercicios.single.series.single.marcador, 'VALIDA');
    });

    test('a migração leva a versão 0 até a atual e marca o número', () {
      final migrado = migrarRascunhoTreino(_exemplo().paraJson()..remove('versao'), 0);
      expect(TreinoEmAndamento.doJson(migrado).treinoId, 'A');
    });

    test('versão mais nova do app: não abre, mas também não apaga', () async {
      final maisNovo = {..._exemplo().paraJson(), 'versao': TreinoEmAndamento.versaoAtual + 1};
      final prefs = await prefsCom(maisNovo);
      final service = RascunhoTreinoService(prefs);

      expect(service.carregar(), isNull);
      expect(prefs.getString('treino_em_andamento'), jsonEncode(maisNovo));
      expect(prefs.getString(RascunhoTreinoService.chaveGuardado), isNull);

      // Começar outro treino nesta versão guarda o mais novo antes de ocupar a chave.
      await service.salvar(_exemplo());
      expect(prefs.getString(RascunhoTreinoService.chaveGuardado), jsonEncode(maisNovo));
      expect(service.carregar()?.treinoId, 'A');
    });

    test('texto corrompido: libera a chave e guarda a cópia', () async {
      final prefs = await prefsCom('{"treinoId": "A", ');

      expect(RascunhoTreinoService(prefs).carregar(), isNull);
      expect(prefs.getString('treino_em_andamento'), isNull);
      expect(prefs.getString(RascunhoTreinoService.chaveGuardado), '{"treinoId": "A", ');
    });

    test('formato que não fecha (campo obrigatório faltando): libera e guarda', () async {
      final quebrado = _exemplo().paraJson()..remove('treinoNome');
      final prefs = await prefsCom(quebrado);

      expect(RascunhoTreinoService(prefs).carregar(), isNull);
      expect(prefs.getString('treino_em_andamento'), isNull);
      expect(prefs.getString(RascunhoTreinoService.chaveGuardado), jsonEncode(quebrado));
    });
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

  test('PBI-70: gravar ou apagar o rascunho avisa o treino em andamento',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    final lidos = <String?>[];
    container.listen(treinoEmAndamentoProvider, (_, t) => lidos.add(t?.treinoId),
        fireImmediately: true);

    // Fluxo antigo (flag desligada): o registro grava só o rascunho, sem o
    // treino ao vivo. Ninguém invalida na tela; a Início precisa ver mesmo assim.
    await container.read(rascunhoTreinoServiceProvider).salvar(_exemplo());
    await container.pump();
    await container.read(rascunhoTreinoServiceProvider).limpar();
    await container.pump();

    expect(lidos, [null, _exemplo().treinoId, null]);
  });
}
