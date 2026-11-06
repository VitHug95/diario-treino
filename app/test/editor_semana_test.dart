import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/planos/editor_semana.dart';
import 'package:diario_treino/shared/calendario/marca_dia.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Repositório que só grava a semana (guarda o que recebeu) ou falha.
class _RepoSemana extends FichasRepository {
  _RepoSemana({this.falhar = false}) : super(Dio());

  final bool falhar;
  List<DiaPlanejado>? gravada;
  int chamadas = 0;

  @override
  Future<void> definirSemana({
    required String planoId,
    required List<DiaPlanejado> dias,
  }) async {
    chamadas++;
    if (falhar) {
      throw const FichasException('Só quem montou este plano pode mudar a semana.');
    }
    gravada = dias;
  }
}

PlanoDetalhe _plano({
  List<DiaPlanejado> semana = const [],
  bool somenteLeitura = false,
  List<TreinoResumo>? fichas,
}) =>
    PlanoDetalhe(
      id: 'p1',
      nome: 'Hipertrofia',
      inicio: DateTime(2026, 9, 12),
      emUso: true,
      autor: 'Vitor',
      somenteLeitura: somenteLeitura,
      treinos: fichas ??
          const [
            TreinoResumo(id: 'fa', nome: 'A', descricao: 'Peito', ordem: 1),
            TreinoResumo(id: 'fb', nome: 'B', descricao: 'Costas', ordem: 2),
          ],
      semana: semana,
    );

Widget _tela(PlanoDetalhe plano,
        {required bool podeEditar, _RepoSemana? repo, ThemeData? tema}) =>
    ProviderScope(
      overrides: [
        if (repo != null) fichasRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecaoSemana(plano: plano, podeEditar: podeEditar),
          ),
        ),
      ),
    );

/// Escolhe [opcao] (rótulo falado da folha) para o dia de rótulo [dia].
Future<void> _escolher(WidgetTester tester, String dia, String opcao) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^$dia:')));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp('^$opcao')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra os 7 dias livres e grava a ficha escolhida para um dia',
      (tester) async {
    final repo = _RepoSemana();
    await tester.pumpWidget(_tela(_plano(), podeEditar: true, repo: repo));

    expect(find.text('SEMANA'), findsOneWidget);
    for (final dia in ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo']) {
      expect(find.bySemanticsLabel('$dia: livre. Toque para trocar'), findsOneWidget);
    }

    await _escolher(tester, 'Segunda', 'A na segunda');

    expect(repo.gravada, [const DiaPlanejado(diaSemana: 1, treinoId: 'fa')]);
    expect(find.bySemanticsLabel('Segunda: A. Toque para trocar'), findsOneWidget);
    expect(find.text('Segunda: A'), findsOneWidget); // pílula de confirmação
  });

  testWidgets('deixar um dia livre manda a semana sem ele e mantém os outros',
      (tester) async {
    final repo = _RepoSemana();
    await tester.pumpWidget(_tela(
      _plano(semana: const [
        DiaPlanejado(diaSemana: 1, treinoId: 'fa'),
        DiaPlanejado(diaSemana: 3, treinoId: 'fb'),
      ]),
      podeEditar: true,
      repo: repo,
    ));
    expect(find.bySemanticsLabel('Quarta: B. Toque para trocar'), findsOneWidget);

    await _escolher(tester, 'Segunda', 'Deixar segunda livre');

    expect(repo.gravada, [const DiaPlanejado(diaSemana: 3, treinoId: 'fb')]);
    expect(find.bySemanticsLabel('Segunda: livre. Toque para trocar'), findsOneWidget);
  });

  testWidgets('escolher a mesma ficha não grava de novo', (tester) async {
    final repo = _RepoSemana();
    await tester.pumpWidget(_tela(
      _plano(semana: const [DiaPlanejado(diaSemana: 2, treinoId: 'fa')]),
      podeEditar: true,
      repo: repo,
    ));

    await _escolher(tester, 'Terça', 'A na terça');

    expect(repo.chamadas, 0);
  });

  testWidgets('se a gravação falha, o dia volta ao que era e o erro aparece',
      (tester) async {
    final repo = _RepoSemana(falhar: true);
    await tester.pumpWidget(_tela(_plano(), podeEditar: true, repo: repo));

    await _escolher(tester, 'Sexta', 'B na sexta');

    expect(repo.chamadas, 1);
    expect(find.bySemanticsLabel('Sexta: livre. Toque para trocar'), findsOneWidget);
    expect(find.text('Só quem montou este plano pode mudar a semana.'), findsOneWidget);
    // Erro não usa a pílula de confirmação (PBI-75).
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).shape,
        isNot(isA<StadiumBorder>()));
  });

  testWidgets('somente leitura mostra a semana sem toque', (tester) async {
    final repo = _RepoSemana();
    await tester.pumpWidget(_tela(
      _plano(
        somenteLeitura: true,
        semana: const [DiaPlanejado(diaSemana: 1, treinoId: 'fa')],
      ),
      podeEditar: false,
      repo: repo,
    ));

    expect(find.text('SEMANA'), findsOneWidget);
    expect(find.bySemanticsLabel('Segunda: A'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Toque para trocar')), findsNothing);

    await tester.tap(find.bySemanticsLabel('Segunda: A'));
    await tester.pumpAndSettle();
    expect(find.text('Qual ficha é deste dia?'), findsNothing); // folha não abre
    expect(repo.chamadas, 0);
  });

  testWidgets('somente leitura sem semana e plano sem fichas não mostram a seção',
      (tester) async {
    await tester.pumpWidget(_tela(_plano(somenteLeitura: true), podeEditar: false));
    expect(find.text('SEMANA'), findsNothing);

    await tester.pumpWidget(_tela(_plano(fichas: const []), podeEditar: true));
    expect(find.text('SEMANA'), findsNothing);
  });

  testWidgets('ficha que saiu do plano não aparece na semana', (tester) async {
    await tester.pumpWidget(_tela(
      // "fx" não está nas fichas (foi excluída): o dia fica livre.
      _plano(semana: const [DiaPlanejado(diaSemana: 4, treinoId: 'fx')]),
      podeEditar: true,
    ));
    expect(find.bySemanticsLabel('Quinta: livre. Toque para trocar'), findsOneWidget);
  });

  testWidgets('desenha no tema escuro sem erro', (tester) async {
    await tester.pumpWidget(_tela(
      _plano(semana: const [DiaPlanejado(diaSemana: 1, treinoId: 'fa')]),
      podeEditar: true,
      tema: AppTheme.escuro,
    ));
    await tester.pumpAndSettle();
    expect(find.text('SEMANA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MarcaDia: descanso não tem o "X" da falta; sem o parâmetro, igual a antes',
      (tester) async {
    Future<void> montar(Widget w) => tester.pumpWidget(
        MaterialApp(theme: AppTheme.claro, home: Scaffold(body: Center(child: w))));

    await montar(const MarcaDia(treinou: false, ehHoje: false, futuro: false));
    expect(find.byIcon(LucideIcons.x), findsOneWidget); // falta (e o calendário)

    await montar(const MarcaDia(treinou: false, ehHoje: false, futuro: false, descanso: true));
    expect(find.byIcon(LucideIcons.x), findsNothing); // descanso
  });

  group('modelos (PBI-35)', () {
    test('doJson lê a semana e trata ausente como vazia', () {
      final comSemana = PlanoDetalhe.doJson({
        'id': 'p1', 'nome': 'H', 'inicio': '2026-09-12', 'emUso': true, 'autor': 'V',
        'somenteLeitura': false, 'treinos': <dynamic>[],
        'semana': [
          {'diaSemana': 5, 'treinoId': 'fb'},
          {'diaSemana': 1, 'treinoId': 'fa'},
        ],
      });
      expect(comSemana.semana, const [
        DiaPlanejado(diaSemana: 1, treinoId: 'fa'),
        DiaPlanejado(diaSemana: 5, treinoId: 'fb'),
      ]);

      final semSemana = PlanoAtivo.doJson({'id': 'p1', 'nome': 'H', 'treinos': <dynamic>[]});
      expect(semSemana.semana, isEmpty);
    });

    test('fichasPorDia ignora ficha que não está mais no plano', () {
      const a = TreinoResumo(id: 'fa', nome: 'A', descricao: null, ordem: 1);
      final mapa = fichasPorDia(const [
        DiaPlanejado(diaSemana: 1, treinoId: 'fa'),
        DiaPlanejado(diaSemana: 2, treinoId: 'fx'),
      ], const [a]);
      expect(mapa, {1: a});
    });
  });
}
