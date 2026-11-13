import 'dart:convert';

import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/progresso/progresso_repository.dart';
import 'package:diario_treino/features/sessao/bloco_ao_vivo.dart';
import 'package:diario_treino/features/sessao/bloco_ao_vivo_screen.dart';
import 'package:diario_treino/features/sessao/descanso_controller.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_screen.dart';
import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PBI-102: treino ao vivo com bloco conjugado, com a ficha do PO.

class _RelogioFixo implements Relogio {
  _RelogioFixo(this.valor);
  final DateTime valor;
  @override
  DateTime agora() => valor;
}

SerieEdicao _serie(int rodada, {String volume = '15', String codigoVolume = 'REPETICOES', bool feita = false}) =>
    SerieEdicao(
      rodada: rodada,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      intensidadeTexto: '20',
      volumeMetricaId: codigoVolume == 'TEMPO_SEG' ? 11 : 10,
      volumeMetricaCodigo: codigoVolume,
      volumeMetricaNome: codigoVolume == 'TEMPO_SEG' ? 'Tempo' : 'Repetições',
      volumeTexto: volume,
      // O rascunho traz o descanso do exercício; no bloco ele é ignorado.
      descansoTexto: '90',
      feita: feita,
    );

ExercicioEdicao _ex(String nome, int series, {String? bloco, String codigoVolume = 'REPETICOES'}) =>
    ExercicioEdicao(
      treinoExercicioId: 'te-$nome',
      exercicioId: 'ex-$nome',
      nome: nome,
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: false,
      series: [for (var r = 1; r <= series; r++) _serie(r, codigoVolume: codigoVolume)],
      blocoId: bloco,
    );

/// Item 1 (sem descanso): prancha 2x25" + elevação pélvica 4x15.
List<ExercicioEdicao> _item1() => [
      _ex('Prancha lateral', 2, bloco: 'i1', codigoVolume: 'TEMPO_SEG'),
      _ex('Elevação pélvica', 4, bloco: 'i1'),
    ];

/// Item 2 (30 s): adução 3x20" + agachamento 3x15.
List<ExercicioEdicao> _item2() => [
      _ex('Adução com a bola', 3, bloco: 'i2', codigoVolume: 'TEMPO_SEG'),
      _ex('Agachamento livre', 3, bloco: 'i2'),
    ];

/// Item 5 (sem descanso): isometria 2x30" + panturrilha 2x10.
List<ExercicioEdicao> _item5() => [
      _ex('Isometria', 2, bloco: 'i5', codigoVolume: 'TEMPO_SEG'),
      _ex('Panturrilha no leg', 2, bloco: 'i5'),
    ];

const _descansos = {'i1': null, 'i2': 30, 'i5': null};

Future<(ProviderContainer, SharedPreferences)> _container(List<ExercicioEdicao> exercicios,
    {SharedPreferences? prefs}) async {
  if (prefs == null) {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 11, 13, 20, 0))),
    historicoExercicioProvider.overrideWith((ref, id) => Future.error('sem rede')),
    progressoPorExercicioProvider.overrideWith((ref, id) => Future.error('sem rede')),
  ]);
  if (exercicios.isNotEmpty) {
    c.read(treinoAoVivoControllerProvider.notifier).iniciar(
          treinoId: 'f1',
          treinoNome: 'Mobilidade de ombro',
          treinoLivre: false,
          data: DateTime(2026, 11, 13),
          inicio: DateTime(2026, 11, 13, 19, 30),
          exercicios: exercicios,
          descansoDosBlocos: _descansos,
        );
  }
  return (c, prefs);
}

Future<GoRouter> _abrir(WidgetTester tester, ProviderContainer c) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Rotas.treinoAoVivo,
    routes: [
      GoRoute(path: Rotas.inicio, builder: (_, __) => const Scaffold(body: Text('Tela inicial'))),
      GoRoute(path: Rotas.treinoAoVivo, builder: (_, __) => const TreinoAoVivoScreen()),
      GoRoute(
        path: Rotas.exercicioAoVivo,
        builder: (_, s) => ExercicioAoVivoScreen(indice: (s.extra as int?) ?? 0),
      ),
      GoRoute(
        path: Rotas.blocoAoVivo,
        builder: (_, s) => BlocoAoVivoScreen(blocoId: (s.extra as String?) ?? ''),
      ),
      GoRoute(path: Rotas.resumoTreino, builder: (_, __) => const Scaffold(body: Text('Resumo'))),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

List<ExercicioEdicao> _membros(ProviderContainer c, String bloco) => c
    .read(treinoAoVivoControllerProvider)!
    .exercicios
    .where((e) => e.blocoId == bloco)
    .toList();

Future<void> _rodadaFeita(WidgetTester tester) async {
  await tester.tap(find.text('RODADA FEITA'));
  await tester.pump();
}

void main() {
  // ---- Regras (sem tela) ----

  group('regras do bloco', () {
    test('agrupa vizinhos do mesmo bloco; bloco de um só vira avulso', () {
      final lista = [
        ..._item1(),
        _ex('Subida no caixote', 3),
        _ex('Sozinho', 2, bloco: 'x'),
        ..._item2(),
      ];
      final grupos = gruposDoTreino(lista);
      expect(grupos.length, 4);
      expect((grupos[0] as GrupoBloco).indices, [0, 1]);
      expect(grupos[1], isA<GrupoAvulso>());
      expect(grupos[2], isA<GrupoAvulso>());
      expect((grupos[3] as GrupoBloco).blocoId, 'i2');
      expect(grupoDoExercicio(grupos, 5), 3);
      expect(grupoDoBloco(grupos, 'i2'), 3);
    });

    test('item 1: 4 rodadas, as rodadas 3 e 4 só com a elevação', () {
      final m = _item1();
      expect(rodadasDoBloco(m), 4);
      expect(seriesDaRodada(m, 1).map((p) => p.$1.nome), ['Prancha lateral', 'Elevação pélvica']);
      expect(seriesDaRodada(m, 3).map((p) => p.$1.nome), ['Elevação pélvica']);
      expect(seriesDaRodada(m, 4).length, 1);
      expect(seriesDaRodada(m, 5), isEmpty);
    });

    test('rodada fecha só com todas as séries dela; a atual é a primeira aberta', () {
      final m = _item2();
      expect(rodadaAtual(m), 1);
      m[0].series[0].feita = true;
      expect(rodadaFechada(m, 1), isFalse);
      expect(rodadaAtual(m), 1);
      m[1].series[0].feita = true;
      expect(rodadaFechada(m, 1), isTrue);
      expect(rodadasFeitas(m), 1);
      expect(rodadaAtual(m), 2);
      for (final e in m) {
        for (final s in e.series) {
          s.feita = true;
        }
      }
      expect(rodadasFeitas(m), 3);
      expect(rodadaAtual(m), 3);
    });

    test('descanso só dispara se for maior que zero', () {
      expect(descansoQueDispara(30), 30);
      expect(descansoQueDispara(0), isNull);
      expect(descansoQueDispara(null), isNull);
    });

    test('ao salvar, o descanso do bloco vai só na última série de cada rodada', () {
      final lista = [..._item2(), _ex('Afundo', 1)];
      for (final e in lista.take(2)) {
        for (final s in e.series) {
          s.feita = true;
        }
      }
      // Rodada 3: só a adução foi feita; ela fecha o que houve.
      lista[1].series[2].feita = false;
      lista[2].series[0].feita = true;

      final d = descansosParaSalvar(lista, _descansos);
      expect(d[lista[0].series[0]], '');
      expect(d[lista[1].series[0]], '30');
      expect(d[lista[1].series[1]], '30');
      expect(d[lista[0].series[2]], '30');
      expect(d.containsKey(lista[1].series[2]), isFalse); // não feita
      expect(d.containsKey(lista[2].series[0]), isFalse); // avulso segue com o dele
    });

    test('bloco sem descanso grava todas as séries sem descanso', () {
      final m = _item1();
      for (final e in m) {
        for (final s in e.series) {
          s.feita = true;
        }
      }
      final d = descansosParaSalvar(m, _descansos);
      expect(d.length, 6);
      expect(d.values.toSet(), {''});
    });

    test('rótulo falado da rodada', () {
      expect(rotuloFaladoRodada(_item2(), 2),
          'Rodada 2 de 3, adução com a bola e agachamento livre');
      expect(rotuloFaladoRodada(_item1(), 3), 'Rodada 3 de 4, elevação pélvica');
    });

    test('cópia para salvar não mexe na série do treino', () {
      final s = _serie(1, feita: true);
      final copia = s.copiaComDescanso('30');
      expect(copia.descansoTexto, '30');
      expect(copia.feita, isTrue);
      expect(s.descansoTexto, '90');
    });
  });

  // ---- Rascunho local ----

  group('rascunho local', () {
    test('guarda o bloco e o descanso dele e volta igual', () async {
      final (c, prefs) = await _container(_item2());
      final membros = _membros(c, 'i2');
      c.read(treinoAoVivoControllerProvider.notifier).marcarRodada(membros, 1);

      final (outro, _) = await _container(const [], prefs: prefs);
      expect(outro.read(treinoAoVivoControllerProvider.notifier).retomarDoRascunho(), isTrue);
      final estado = outro.read(treinoAoVivoControllerProvider)!;
      expect(estado.descansoDosBlocos, {'i1': null, 'i2': 30, 'i5': null});
      final retomados = estado.exercicios.where((e) => e.blocoId == 'i2').toList();
      expect(retomados.length, 2);
      // Volta na rodada certa, com as marcações.
      expect(rodadaAtual(retomados), 2);
      expect(retomados.every((e) => e.series[0].feita), isTrue);
    });

    test('rascunho antigo, sem os campos do bloco, abre como avulso', () async {
      SharedPreferences.setMockInitialValues({
        'treino_em_andamento': jsonEncode({
          'treinoId': 'f1',
          'treinoNome': 'A',
          'treinoLivre': false,
          'dataIso': '2026-11-13',
          'inicioMillis': 0,
          'exercicios': [
            {
              'treinoExercicioId': 'te',
              'exercicioId': 'ex',
              'nome': 'Supino',
              'modalidade': 'FORCA',
              'origemPreenchimento': null,
              'foraDaFicha': false,
              'realizado': false,
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
                  'descansoTexto': '60',
                },
              ],
            },
          ],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final salvo = RascunhoTreinoService(prefs).carregar();
      expect(salvo, isNotNull);
      expect(salvo!.descansoDosBlocos, isEmpty);
      expect(salvo.exercicios.single.blocoId, isNull);
    });
  });

  // ---- Telas ----

  testWidgets('tela 14: o bloco é um cartão só com o progresso por rodada', (tester) async {
    final (c, _) = await _container([..._item2(), _ex('Afundo', 3)]);
    await _abrir(tester, c);

    expect(find.text('CONJUGADO'), findsOneWidget);
    expect(find.text('Adução com a bola + Agachamento livre'), findsOneWidget);
    expect(find.text('0 de 3 rodadas · ainda não começou'), findsOneWidget);
    expect(find.text('Afundo'), findsOneWidget);
    expect(find.text('Adução com a bola'), findsNothing); // não é cartão próprio
  });

  testWidgets('item 2: "Rodada feita" marca os dois, dispara 30 s e passa à rodada 2',
      (tester) async {
    final (c, _) = await _container(_item2());
    await _abrir(tester, c);
    await tester.tap(find.text('Adução com a bola + Agachamento livre'));
    await tester.pumpAndSettle();

    expect(find.text('Rodada 1 de 3'), findsOneWidget);
    expect(find.text('Descanso de 30 s depois de cada rodada'), findsOneWidget);
    expect(find.text('Adução com a bola'), findsOneWidget);
    expect(find.text('Agachamento livre'), findsOneWidget);

    await _rodadaFeita(tester);

    final m = _membros(c, 'i2');
    expect(m.every((e) => e.series[0].feita && e.realizado), isTrue);
    expect(c.read(descansoControllerProvider)?.total, const Duration(seconds: 30));
    expect(find.text('Rodada 2 de 3'), findsOneWidget);
  });

  testWidgets('item 1: avança sem cronômetro e as rodadas 3 e 4 só têm a elevação',
      (tester) async {
    final (c, _) = await _container(_item1());
    await _abrir(tester, c);
    await tester.tap(find.text('Prancha lateral + Elevação pélvica'));
    await tester.pumpAndSettle();

    expect(find.text('Rodada 1 de 4'), findsOneWidget);
    expect(find.text('Sem descanso entre as rodadas'), findsOneWidget);
    await _rodadaFeita(tester);
    expect(c.read(descansoControllerProvider), isNull);
    await _rodadaFeita(tester);
    expect(c.read(descansoControllerProvider), isNull);

    expect(find.text('Rodada 3 de 4'), findsOneWidget);
    expect(find.text('Elevação pélvica'), findsOneWidget);
    expect(find.text('Prancha lateral'), findsNothing);
    await _rodadaFeita(tester);
    expect(find.text('Rodada 4 de 4'), findsOneWidget);
    expect(find.text('Prancha lateral'), findsNothing);
  });

  testWidgets('item 5: "Rodada feita" sem descanso nenhum', (tester) async {
    final (c, _) = await _container(_item5());
    await _abrir(tester, c);
    await tester.tap(find.text('Isometria + Panturrilha no leg'));
    await tester.pumpAndSettle();

    await _rodadaFeita(tester);
    expect(c.read(descansoControllerProvider), isNull);
    expect(find.text('Rodada 2 de 2'), findsOneWidget);
  });

  testWidgets('marcar uma das duas não dispara; marcar a segunda dispara', (tester) async {
    final (c, _) = await _container(_item2());
    await _abrir(tester, c);
    await tester.tap(find.text('Adução com a bola + Agachamento livre'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Adução com a bola, série 1 pendente')));
    await tester.pump();
    expect(c.read(descansoControllerProvider), isNull);
    expect(find.text('Rodada 1 de 3'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Agachamento livre, série 1 pendente')));
    await tester.pump();
    expect(c.read(descansoControllerProvider)?.total, const Duration(seconds: 30));
    expect(find.text('Rodada 2 de 3'), findsOneWidget);
  });

  testWidgets('desmarcar uma série da rodada fechada cancela o descanso', (tester) async {
    final (c, _) = await _container(_item2());
    await _abrir(tester, c);
    await tester.tap(find.text('Adução com a bola + Agachamento livre'));
    await tester.pumpAndSettle();
    await _rodadaFeita(tester);
    expect(c.read(descansoControllerProvider), isNotNull);

    // Volta à rodada 1 e desmarca o agachamento.
    await tester.tap(find.bySemanticsLabel('Rodada anterior'));
    await tester.pump();
    expect(find.text('Rodada 1 de 3'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Agachamento livre, série 1 feita')));
    await tester.pump();

    expect(c.read(descansoControllerProvider), isNull);
    expect(_membros(c, 'i2')[1].series[0].feita, isFalse);
    expect(find.text('Rodada 1 de 3'), findsOneWidget);
  });

  testWidgets('"Concluir bloco" marca os membros como concluídos e abre o próximo item',
      (tester) async {
    final (c, _) = await _container([..._item2(), _ex('Afundo', 3)]);
    await _abrir(tester, c);
    await tester.tap(find.text('Adução com a bola + Agachamento livre'));
    await tester.pumpAndSettle();
    await _rodadaFeita(tester);

    await tester.tap(find.text('Concluir bloco'));
    await tester.pumpAndSettle();

    expect(_membros(c, 'i2').every((e) => e.concluido), isTrue);
    expect(find.byType(ExercicioAoVivoScreen), findsOneWidget);
    expect(find.text('Afundo'), findsWidgets);
    expect(find.text('Exercício 2 de 2'), findsOneWidget);
  });

  testWidgets('bloco no fim: "Concluir e ir ao resumo"', (tester) async {
    final (c, _) = await _container(_item5());
    await _abrir(tester, c);
    await tester.tap(find.text('Isometria + Panturrilha no leg'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Concluir e ir ao resumo'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo'), findsOneWidget);
  });

  testWidgets('a seta do exercício avulso leva ao bloco', (tester) async {
    final (c, _) = await _container([_ex('Afundo', 3), ..._item2()]);
    await _abrir(tester, c);
    await tester.tap(find.text('Afundo'));
    await tester.pumpAndSettle();
    expect(find.text('Exercício 1 de 2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Próximo exercício'));
    await tester.pumpAndSettle();
    expect(find.byType(BlocoAoVivoScreen), findsOneWidget);
    expect(find.text('Rodada 1 de 3'), findsOneWidget);
  });

  testWidgets('leitor de tela anuncia a rodada com os exercícios', (tester) async {
    final semantica = tester.ensureSemantics();
    final (c, _) = await _container(_item2());
    await _abrir(tester, c);
    await tester.tap(find.text('Adução com a bola + Agachamento livre'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Rodada 1 de 3, adução com a bola e agachamento livre'),
        findsOneWidget);
    semantica.dispose();
  });

  for (final escuro in [false, true]) {
    testWidgets('360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'})', (tester) async {
      final (c, _) = await _container(_item2());
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.claro,
          darkTheme: AppTheme.escuro,
          themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
          home: const BlocoAoVivoScreen(blocoId: 'i2'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rodada 1 de 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Toque de 44 px no check.
      final check = tester.getSize(find.bySemanticsLabel(RegExp(r'^Adução com a bola, série 1')));
      expect(check.width, greaterThanOrEqualTo(44));
    });
  }
}
