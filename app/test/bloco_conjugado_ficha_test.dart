import 'package:dio/dio.dart';
import 'package:diario_treino/core/localizacao/material_pt.dart';
import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/features/fichas/bloco_conjugado.dart';
import 'package:diario_treino/features/fichas/editar_alvos_screen.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/fichas_screen.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PBI-101: bloco conjugado no editor da ficha. O "servidor" em memória aplica
/// as regras do back (rodadas = maior número de séries, menos de 2 desfaz,
/// quem sai fica avulso com o descanso do bloco), e a tela só atualiza pela
/// releitura que o comando dispara (sem F5).

const _metricas = <Metrica>[
  Metrica(id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE'),
  Metrica(id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: 'rep', eixo: 'VOLUME'),
];

const _alvo = AlvoExercicio(
  intensidadeMetricaId: 1,
  intensidadeMetricaCodigo: 'CARGA_KG',
  intensidadeMetricaNome: 'Carga',
  intensidadeAlvo: null,
  volumeMetricaId: 10,
  volumeMetricaCodigo: 'REPETICOES',
  volumeMetricaNome: 'Repetições',
  volumeAlvo: 15,
);

class _Ex {
  _Ex(this.id, this.nome, this.rodadas, {this.descanso, this.bloco});
  final String id;
  final String nome;
  int rodadas;
  int? descanso;
  String? bloco;
}

class _Servidor extends FichasRepository {
  _Servidor(this.exercicios, [Map<String, int?>? blocos])
      : blocos = blocos ?? {},
        super(Dio());

  final List<_Ex> exercicios;

  /// id do bloco → descanso.
  final Map<String, int?> blocos;
  final chamadas = <String>[];
  var _proximo = 0;

  List<String> _membros(String bloco) =>
      [for (final e in exercicios) if (e.bloco == bloco) e.id];

  void _desfazer(String bloco) {
    for (final e in exercicios.where((e) => e.bloco == bloco)) {
      e.bloco = null;
      e.descanso = blocos[bloco];
    }
    blocos.remove(bloco);
  }

  /// Ordem nova com [ids] juntos no lugar do primeiro deles.
  void _agrupar(List<String> ids) {
    final grupo = [for (final id in ids) exercicios.firstWhere((e) => e.id == id)];
    final primeiro = exercicios.indexWhere((e) => ids.contains(e.id));
    final resto = exercicios.where((e) => !ids.contains(e.id)).toList();
    final antes = exercicios.take(primeiro).where((e) => !ids.contains(e.id)).length;
    exercicios
      ..clear()
      ..addAll([...resto.take(antes), ...grupo, ...resto.skip(antes)]);
  }

  @override
  Future<TreinoDetalhe> obterFicha(String treinoId) async {
    final lista = [
      for (var i = 0; i < exercicios.length; i++)
        TreinoExercicioResumo(
          id: exercicios[i].id,
          exercicioId: 'cat-${exercicios[i].id}',
          nome: exercicios[i].nome,
          grupoMuscular: null,
          modalidade: 'FORCA',
          ordem: i + 1,
          rodadas: exercicios[i].rodadas,
          descansoSeg: exercicios[i].descanso,
          instrucao: null,
          alvo: _alvo,
          blocoId: exercicios[i].bloco,
        ),
    ];
    final ordemBlocos = <String>[];
    for (final e in exercicios) {
      if (e.bloco != null && !ordemBlocos.contains(e.bloco)) ordemBlocos.add(e.bloco!);
    }
    return TreinoDetalhe(
      id: 'f1',
      nome: 'Mobilidade de ombro',
      descricao: null,
      ordem: 1,
      exercicios: lista,
      blocos: [
        for (final b in ordemBlocos)
          BlocoFicha(
            id: b,
            descansoSeg: blocos[b],
            treinoExercicioIds: _membros(b),
            rodadas: exercicios
                .where((e) => e.bloco == b)
                .map((e) => e.rodadas)
                .reduce((a, c) => a > c ? a : c),
          ),
      ],
    );
  }

  @override
  Future<String> criarBloco({
    required String treinoId,
    required List<String> treinoExercicioIds,
    int? descansoSeg,
  }) async {
    chamadas.add('criar $treinoExercicioIds $descansoSeg');
    final id = 'b${++_proximo}';
    blocos[id] = descansoSeg;
    for (final e in exercicios.where((e) => treinoExercicioIds.contains(e.id))) {
      e.bloco = id;
    }
    _agrupar([for (final e in exercicios) if (treinoExercicioIds.contains(e.id)) e.id]);
    return id;
  }

  @override
  Future<void> definirDescansoBloco({
    required String treinoId,
    required String blocoId,
    int? descansoSeg,
  }) async {
    chamadas.add('descanso $blocoId $descansoSeg');
    blocos[blocoId] = descansoSeg;
  }

  @override
  Future<void> desfazerBloco({required String treinoId, required String blocoId}) async {
    chamadas.add('desfazer $blocoId');
    _desfazer(blocoId);
  }

  @override
  Future<void> definirMembrosBloco({
    required String treinoId,
    required String blocoId,
    required List<String> treinoExercicioIds,
  }) async {
    chamadas.add('membros $blocoId $treinoExercicioIds');
    if (treinoExercicioIds.length < 2) {
      _desfazer(blocoId);
      return;
    }
    final saem = _membros(blocoId).where((id) => !treinoExercicioIds.contains(id)).toList();
    for (final e in exercicios) {
      if (saem.contains(e.id)) {
        e.bloco = null;
        e.descanso = blocos[blocoId];
      } else if (treinoExercicioIds.contains(e.id)) {
        e.bloco = blocoId;
      }
    }
    _agrupar([...treinoExercicioIds, ...saem]);
  }

  @override
  Future<void> reordenarExercicios({
    required String treinoId,
    required List<String> treinoExercicioIds,
  }) async {
    chamadas.add('ordem $treinoExercicioIds');
    final novos = [for (final id in treinoExercicioIds) exercicios.firstWhere((e) => e.id == id)];
    exercicios
      ..clear()
      ..addAll(novos);
  }
}

/// A ficha real do PO: itens 1, 2 e 5 em bloco; 3 e 4 avulsos.
_Servidor _fichaDoPo() => _Servidor([
      _Ex('prancha', 'Prancha lateral', 2, bloco: 'i1'),
      _Ex('elevacao', 'Elevação pélvica', 4, bloco: 'i1'),
      _Ex('aducao', 'Adução com a bola', 3, bloco: 'i2'),
      _Ex('agacha', 'Agachamento livre', 3, bloco: 'i2'),
      _Ex('caixote', 'Subida no caixote unilateral', 3, descanso: 30),
      _Ex('afundo', 'Afundo', 3, descanso: 40),
      _Ex('isometria', 'Isometria', 2, bloco: 'i5'),
      _Ex('panturrilha', 'Panturrilha no leg', 2, bloco: 'i5'),
    ], {
      'i1': null,
      'i2': 30,
      'i5': null,
    });

Widget _app(_Servidor repo, {bool escuro = false}) => ProviderScope(
      overrides: [
        fichasRepositoryProvider.overrideWithValue(repo),
        planoAtivoProvider.overrideWith((ref) async => const PlanoAtivo(
              id: 'p1',
              nome: 'Reabilitação',
              treinos: [TreinoResumo(id: 'f1', nome: 'Mobilidade de ombro', descricao: null, ordem: 1)],
            )),
        fichaTemSessoesProvider.overrideWith((ref, id) async => false),
        sessoesRecentesProvider.overrideWith((ref) async => []),
        metricasProvider.overrideWith((ref) async => _metricas),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        darkTheme: AppTheme.escuro,
        themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: LocalizacoesPt.delegates,
        home: const FichasScreen(fichaInicialId: 'f1'),
      ),
    );

Future<void> _abrir(WidgetTester tester, _Servidor repo, {bool escuro = false}) async {
  tester.view.physicalSize = const Size(400, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(repo, escuro: escuro));
  await tester.pumpAndSettle();
}

void main() {
  for (final escuro in [false, true]) {
    testWidgets('a ficha do PO mostra os três blocos e os dois avulsos '
        '(${escuro ? 'escuro' : 'claro'})', (tester) async {
      await _abrir(tester, _fichaDoPo(), escuro: escuro);

      // Item 1: prancha 2 + elevação 4 = 4 rodadas, sem descanso.
      expect(find.text('Conjugado · 4 rodadas · sem descanso'), findsOneWidget);
      // Item 2: 3 rodadas, descanso 30 s.
      expect(find.text('Conjugado · 3 rodadas · descanso 30 s'), findsOneWidget);
      // Item 5: 2 rodadas, sem descanso.
      expect(find.text('Conjugado · 2 rodadas · sem descanso'), findsOneWidget);

      // Membros mostram o resumo sem descanso; os avulsos, com o deles.
      expect(find.text('2 séries · 15 rep'), findsNWidgets(3)); // prancha, isometria, panturrilha
      expect(find.text('3 séries · 15 rep · 30 s'), findsOneWidget); // caixote
      expect(find.text('3 séries · 15 rep · 40 s'), findsOneWidget); // afundo
      expect(find.text('Descanso'), findsNWidgets(3));
      expect(find.text('Desfazer bloco'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rótulo falado do bloco', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, _fichaDoPo());

    expect(find.bySemanticsLabel(RegExp(r'^Bloco conjugado, 3 rodadas, descanso 30 segundos, 2 exercícios')),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Bloco conjugado, 4 rodadas, sem descanso, 2 exercícios')),
        findsOneWidget);
    semantica.dispose();
  });

  testWidgets('juntar com o de baixo pede o descanso e o bloco aparece sem recarregar',
      (tester) async {
    final repo = _Servidor([_Ex('a', 'Adução com a bola', 3), _Ex('b', 'Agachamento livre', 3)]);
    await _abrir(tester, repo);
    expect(find.textContaining('Conjugado'), findsNothing);

    await tester.tap(find.byTooltip('Juntar Adução com a bola com o de baixo'));
    await tester.pumpAndSettle();
    expect(find.text('Descanso depois de cada rodada'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Segundos'), '30');
    await tester.tap(find.text('JUNTAR'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['criar [a, b] 30']);
    expect(find.text('Conjugado · 3 rodadas · descanso 30 s'), findsOneWidget);
    // O último não tem com quem juntar; dentro do bloco não há "juntar".
    expect(find.byTooltip('Juntar Agachamento livre com o de baixo'), findsNothing);
  });

  testWidgets('juntar com "Sem descanso" cria o bloco sem descanso', (tester) async {
    final repo = _Servidor([_Ex('a', 'Prancha lateral', 2), _Ex('b', 'Elevação pélvica', 4)]);
    await _abrir(tester, repo);

    await tester.tap(find.byTooltip('Juntar Prancha lateral com o de baixo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem descanso'));
    await tester.pump();
    await tester.tap(find.text('JUNTAR'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['criar [a, b] null']);
    expect(find.text('Conjugado · 4 rodadas · sem descanso'), findsOneWidget);
  });

  testWidgets('descanso fora de 0 a 600 é recusado no sheet', (tester) async {
    final repo = _Servidor([_Ex('a', 'A', 2), _Ex('b', 'B', 2)]);
    await _abrir(tester, repo);

    await tester.tap(find.byTooltip('Juntar A com o de baixo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Segundos'), '900');
    await tester.tap(find.text('JUNTAR'));
    await tester.pumpAndSettle();

    expect(find.text('Use de 0 a 600 segundos.'), findsOneWidget);
    expect(repo.chamadas, isEmpty);
  });

  testWidgets('avulso acima de um bloco entra no bloco', (tester) async {
    final repo = _Servidor([
      _Ex('x', 'Afundo', 3),
      _Ex('a', 'Adução com a bola', 3, bloco: 'b1'),
      _Ex('b', 'Agachamento livre', 3, bloco: 'b1'),
    ], {'b1': 30});
    await _abrir(tester, repo);

    await tester.tap(find.byTooltip('Juntar Afundo com o de baixo'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['membros b1 [x, a, b]']);
    expect(find.text('Conjugado · 3 rodadas · descanso 30 s'), findsOneWidget);
    expect(find.byTooltip('Juntar Afundo com o de baixo'), findsNothing);
  });

  testWidgets('bloco cheio (4) não oferece juntar', (tester) async {
    final repo = _Servidor([
      for (final id in ['a', 'b', 'c', 'd']) _Ex(id, 'Ex $id', 2, bloco: 'b1'),
      _Ex('e', 'Ex e', 2),
    ], {'b1': null});
    await _abrir(tester, repo);

    expect(find.byTooltip('Juntar o bloco com o de baixo'), findsNothing);
    expect(find.byTooltip('Juntar Ex d com o de baixo'), findsNothing);
  });

  testWidgets('tirar do bloco de dois desfaz e os dois ficam com o descanso do bloco',
      (tester) async {
    final repo = _Servidor([
      _Ex('a', 'Adução com a bola', 3, bloco: 'b1'),
      _Ex('b', 'Agachamento livre', 3, bloco: 'b1'),
    ], {'b1': 30});
    await _abrir(tester, repo);

    await tester.tap(find.byTooltip('Opções de Adução com a bola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar do bloco'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['membros b1 [b]']);
    expect(find.textContaining('Conjugado'), findsNothing);
    expect(find.text('3 séries · 15 rep · 30 s'), findsNWidgets(2));
  });

  testWidgets('mover para baixo troca a ordem dentro do bloco', (tester) async {
    final repo = _Servidor([
      _Ex('a', 'Adução com a bola', 3, bloco: 'b1'),
      _Ex('b', 'Agachamento livre', 3, bloco: 'b1'),
    ], {'b1': 30});
    await _abrir(tester, repo);

    await tester.tap(find.byTooltip('Opções de Adução com a bola'));
    await tester.pumpAndSettle();
    // O primeiro não sobe.
    expect(find.text('Mover para cima'), findsNothing);
    await tester.tap(find.text('Mover para baixo'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['membros b1 [b, a]']);
    final yAgacha = tester.getTopLeft(find.text('Agachamento livre')).dy;
    final yAducao = tester.getTopLeft(find.text('Adução com a bola')).dy;
    expect(yAgacha, lessThan(yAducao));
  });

  testWidgets('"Descanso" no cabeçalho muda o descanso do bloco', (tester) async {
    final repo = _Servidor([
      _Ex('a', 'A', 3, bloco: 'b1'),
      _Ex('b', 'B', 3, bloco: 'b1'),
    ], {'b1': 30});
    await _abrir(tester, repo);

    await tester.tap(find.text('Descanso'));
    await tester.pumpAndSettle();
    // Abre com o valor atual.
    expect(find.widgetWithText(TextField, '30'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Segundos'), '45');
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['descanso b1 45']);
    expect(find.text('Conjugado · 3 rodadas · descanso 45 s'), findsOneWidget);
  });

  testWidgets('"Desfazer bloco" confirma e deixa os exercícios avulsos', (tester) async {
    final repo = _Servidor([
      _Ex('a', 'A', 3, bloco: 'b1'),
      _Ex('b', 'B', 3, bloco: 'b1'),
    ], {'b1': 30});
    await _abrir(tester, repo);

    await tester.tap(find.text('Desfazer bloco'));
    await tester.pumpAndSettle();
    expect(find.text('Desfazer o bloco?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Desfazer'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['desfazer b1']);
    expect(find.textContaining('Conjugado'), findsNothing);
  });

  testWidgets('o editor de alvos de um membro não tem o campo de descanso', (tester) async {
    await _abrir(tester, _fichaDoPo());

    await tester.tap(find.text('Adução com a bola'));
    await tester.pumpAndSettle();

    expect(find.byType(EditarAlvosScreen), findsOneWidget);
    expect(find.text('O descanso é definido no bloco.'), findsOneWidget);
    expect(find.text('Descanso entre séries (opcional)'), findsNothing);
  });

  testWidgets('o editor de alvos de um avulso continua com o descanso', (tester) async {
    await _abrir(tester, _fichaDoPo());

    await tester.tap(find.text('Afundo'));
    await tester.pumpAndSettle();

    expect(find.text('Descanso entre séries (opcional)'), findsOneWidget);
    expect(find.text('O descanso é definido no bloco.'), findsNothing);
  });

  testWidgets('360 px com fonte 1,3x: a ficha do PO cabe sem estourar', (tester) async {
    tester.view.physicalSize = const Size(360, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(_fichaDoPo()));
    await tester.pumpAndSettle();
    expect(MediaQuery.textScalerOf(tester.element(find.byType(FichasScreen))).scale(10), 13);

    expect(find.text('Conjugado · 4 rodadas · sem descanso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('textos do bloco', () {
    const comDescanso =
        BlocoFicha(id: 'b', descansoSeg: 30, treinoExercicioIds: ['x', 'y'], rodadas: 3);
    const semDescanso = BlocoFicha(id: 'b', descansoSeg: 0, treinoExercicioIds: ['x'], rodadas: 1);
    expect(textoCabecalhoBloco(comDescanso), 'Conjugado · 3 rodadas · descanso 30 s');
    expect(textoCabecalhoBloco(semDescanso), 'Conjugado · 1 rodada · sem descanso');
    expect(rotuloFaladoBloco(comDescanso, 2),
        'Bloco conjugado, 3 rodadas, descanso 30 segundos, 2 exercícios');
    expect(validarDescansoBloco(''), isNotNull);
    expect(validarDescansoBloco('601'), isNotNull);
    expect(validarDescansoBloco('600'), isNull);
    expect(validarDescansoBloco('0'), isNull);
  });

  test('ficha antiga sem "blocos" no JSON vira tudo avulso', () {
    final f = TreinoDetalhe.doJson({
      'id': 'f',
      'nome': 'A',
      'descricao': null,
      'ordem': 1,
      'exercicios': [
        {
          'id': 'x',
          'exercicioId': 'e',
          'nome': 'Supino',
          'modalidade': 'FORCA',
          'ordem': 1,
          'rodadas': 3,
          'descansoSeg': 60,
          'instrucao': null,
          'alvo': null,
        },
      ],
    });
    expect(f.blocos, isEmpty);
    expect(f.itens.single, isA<ItemAvulso>());
  });
}
