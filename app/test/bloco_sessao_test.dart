import 'package:diario_treino/features/sessao/bloco_sessao.dart';
import 'package:diario_treino/features/sessao/detalhe_sessao_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PBI-103: o bloco conjugado no detalhe da sessão, montado só com o que a
/// sessão gravou (bloco e posição em cada série).

SerieDetalhe _serie(int rodada,
        {double carga = 20, double volume = 15, int? descanso, int? bloco, int? posicao}) =>
    SerieDetalhe(
      rodada: rodada,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'kg',
      intensidade: carga,
      volumeMetricaId: 10,
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'rep',
      volume: volume,
      descansoSeg: descanso,
      bloco: bloco,
      posicaoNoBloco: posicao,
    );

ExercicioSessaoDetalhe _ex(String nome, List<SerieDetalhe> series,
        {int ordem = 1, bool naoRealizado = false}) =>
    ExercicioSessaoDetalhe(
      exercicioId: 'ex-$nome',
      treinoExercicioId: 'te-$nome',
      nome: nome,
      grupoMuscular: null,
      modalidade: 'FORCA',
      ordem: ordem,
      naoRealizado: naoRealizado,
      foraDaFicha: false,
      plano: null,
      series: series,
    );

/// Sessão do item 2 da ficha do PO: adução + agachamento em 3 rodadas, o
/// descanso de 30 s gravado só no agachamento (o último de cada rodada), e o
/// afundo avulso.
SessaoDetalhe _sessaoItem2() => SessaoDetalhe(
      id: 's1',
      treinoId: 'f1',
      treinoNome: 'Mobilidade de ombro',
      data: DateTime(2026, 11, 13),
      duracaoMin: 40,
      observacao: null,
      exercicios: [
        _ex('Adução com a bola', [
          for (var r = 1; r <= 3; r++) _serie(r, volume: 20, bloco: 1, posicao: 1),
        ]),
        _ex('Agachamento livre', [
          for (var r = 1; r <= 3; r++) _serie(r, descanso: 30, bloco: 1, posicao: 2),
        ], ordem: 2),
        _ex('Afundo', [_serie(1, descanso: 40)], ordem: 3),
      ],
    );

Future<void> _abrir(WidgetTester tester, SessaoDetalhe s, {bool escuro = false}) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [sessaoDetalheProvider.overrideWith((ref, id) async => s)],
    child: MaterialApp(
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      home: const DetalheSessaoScreen(sessaoId: 's1'),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('agrupamento', () {
    test('membros do mesmo bloco viram um item, na posição em que foram feitos', () {
      final s = _sessaoItem2();
      // A API pode mandar os membros fora de ordem (a ficha mudou depois).
      final invertida = [s.exercicios[2], s.exercicios[1], s.exercicios[0]];

      final itens = itensDaSessao(invertida);
      expect(itens.length, 2);
      expect(itens[0], isA<ItemSessaoAvulso>());
      final bloco = itens[1] as ItemSessaoBloco;
      expect(bloco.membros.map((m) => m.nome), ['Adução com a bola', 'Agachamento livre']);
      expect(bloco.rodadas, 3);
      expect(bloco.daRodada(2).length, 2);
      expect(bloco.descansoDaRodada(1), 30);
    });

    test('rodadas desiguais (item 1): rodadas 3 e 4 só com a elevação', () {
      final bloco = itensDaSessao([
        _ex('Prancha lateral', [_serie(1, bloco: 1, posicao: 1), _serie(2, bloco: 1, posicao: 1)]),
        _ex('Elevação pélvica', [for (var r = 1; r <= 4; r++) _serie(r, bloco: 1, posicao: 2)]),
      ]).single as ItemSessaoBloco;
      expect(bloco.rodadas, 4);
      expect(bloco.daRodada(3).map((p) => p.$1.nome), ['Elevação pélvica']);
      expect(bloco.descansoDaRodada(1), isNull);
    });

    test('sessão antiga, sem bloco, fica toda avulsa', () {
      final itens = itensDaSessao([_ex('Supino', [_serie(1)]), _ex('Remada', [_serie(1)])]);
      expect(itens.every((i) => i is ItemSessaoAvulso), isTrue);
    });

    test('bloco em que só um membro foi feito aparece como avulso', () {
      final itens = itensDaSessao([
        _ex('Adução com a bola', [_serie(1, bloco: 1, posicao: 1)]),
        _ex('Agachamento livre', const [], naoRealizado: true),
      ]);
      expect(itens.every((i) => i is ItemSessaoAvulso), isTrue);
    });
  });

  for (final escuro in [false, true]) {
    testWidgets('a sessão do item 2 mostra o bloco em 3 rodadas com "descanso 30 s" '
        '(${escuro ? 'escuro' : 'claro'})', (tester) async {
      await _abrir(tester, _sessaoItem2(), escuro: escuro);

      expect(find.text('Conjugado · 3 rodadas'), findsOneWidget);
      expect(find.text('Adução com a bola + Agachamento livre'), findsOneWidget);
      for (var r = 1; r <= 3; r++) {
        expect(find.text('RODADA $r · DESCANSO 30 S'), findsOneWidget);
      }
      // Cada membro aparece uma vez por rodada; o descanso não se repete por série.
      expect(find.text('Agachamento livre'), findsNWidgets(3));
      expect(find.text('30s'), findsNothing);
      // O avulso continua como antes, com o descanso dele.
      expect(find.text('Afundo'), findsOneWidget);
      expect(find.text('40s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rótulo falado do bloco', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, _sessaoItem2());
    expect(
        find.bySemanticsLabel(
            RegExp(r'^Bloco conjugado, 3 rodadas: Adução com a bola e Agachamento livre')),
        findsOneWidget);
    semantica.dispose();
  });

  testWidgets('sessão antiga abre igual a antes', (tester) async {
    await _abrir(
      tester,
      SessaoDetalhe(
        id: 's1',
        treinoId: null,
        treinoNome: null,
        data: DateTime(2026, 9, 1),
        duracaoMin: null,
        observacao: null,
        exercicios: [
          _ex('Supino', [_serie(1, descanso: 90), _serie(2, descanso: 90)]),
        ],
      ),
    );

    expect(find.textContaining('Conjugado'), findsNothing);
    expect(find.text('Supino'), findsOneWidget);
    expect(find.text('90s'), findsNWidgets(2));
  });

  testWidgets('360 px e fonte 1,3x', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(360, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessaoDetalheProvider.overrideWith((ref, id) async => _sessaoItem2())],
      child: MaterialApp(theme: AppTheme.claro, home: const DetalheSessaoScreen(sessaoId: 's1')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Conjugado · 3 rodadas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
