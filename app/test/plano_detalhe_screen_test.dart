import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/planos/acoes_plano.dart';
import 'package:diario_treino/features/planos/plano_detalhe_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TreinoResumo _ficha(String id, String nome, int ordem, {String? desc}) =>
    TreinoResumo(id: id, nome: nome, descricao: desc, ordem: ordem);

PlanoDetalhe _plano({
  bool emUso = true,
  List<TreinoResumo>? fichas,
}) =>
    PlanoDetalhe(
      id: 'p1',
      nome: 'Hipertrofia',
      inicio: DateTime(2026, 9, 12),
      emUso: emUso,
      autor: 'Vitor',
      somenteLeitura: false,
      treinos: fichas ??
          [
            _ficha('fa', 'A', 1, desc: 'Peito e tríceps'),
            _ficha('fb', 'B', 2, desc: 'Costas e bíceps'),
            _ficha('fc', 'C', 3, desc: 'Pernas'),
          ],
    );

TreinoExercicioResumo _ex(int ordem) => TreinoExercicioResumo(
      id: 'te$ordem',
      exercicioId: 'e$ordem',
      nome: 'Exercício $ordem',
      grupoMuscular: 'peito',
      modalidade: 'FORCA',
      ordem: ordem,
      rodadas: 3,
      descansoSeg: null,
      instrucao: null,
      alvo: null,
    );

Widget _tela(PlanoDetalhe plano, {ThemeData? tema}) => ProviderScope(
      overrides: [
        planoDetalheProvider.overrideWith((ref, id) async => plano),
        // A ficha A tem 4 exercícios; as outras, 5.
        fichaDetalheProvider.overrideWith((ref, treinoId) async => TreinoDetalhe(
              id: treinoId,
              nome: treinoId,
              descricao: null,
              ordem: 1,
              exercicios: [
                for (var i = 1; i <= (treinoId == 'fa' ? 4 : 5); i++) _ex(i),
              ],
            )),
        // Só a ficha A tem sessão registrada (27/09).
        sessoesRecentesProvider.overrideWith((ref) async => [
              SessaoResumo(
                id: 's1',
                data: DateTime(2026, 9, 27),
                treinoId: 'fa',
                treinoNome: 'A',
                quantidadeExercicios: 4,
                duracaoMin: 50,
                temObservacao: false,
              ),
            ]),
      ],
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: const PlanoDetalheScreen(planoId: 'p1'),
      ),
    );

void main() {
  test('Quadrado da ficha: nome curto ou posição na sequência', () {
    expect(rotuloQuadradoFicha('A', 1), 'A');
    expect(rotuloQuadradoFicha('abc', 2), 'ABC');
    expect(rotuloQuadradoFicha('Peito pesado', 4), '4');
    expect(rotuloQuadradoFicha('Dia 1', 1), '1');
  });

  test('Aviso de excluir explica a troca de uso só para o plano em uso', () {
    expect(textoExcluirPlano(emUso: true),
        contains('o uso passa para o último plano que você usou'));
    expect(textoExcluirPlano(emUso: false), isNot(contains('o uso passa')));
  });

  testWidgets('Plano em uso: cabeçalho, fichas com resumo e Nova ficha',
      (tester) async {
    await tester.pumpWidget(_tela(_plano()));
    await tester.pumpAndSettle();

    expect(find.text('PLANO EM USO'), findsOneWidget);
    expect(find.text('HIPERTROFIA'), findsOneWidget);
    expect(find.text('Desde 12/09/2026 · 3 fichas · criado por você'), findsOneWidget);

    // Uma linha por ficha, com quadrado, título e resumo.
    expect(find.text('Peito e tríceps'), findsOneWidget);
    expect(find.text('4 exercícios · último em 27/09'), findsOneWidget);
    expect(find.text('5 exercícios · nunca feito'), findsNWidgets(2));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    expect(find.text('Nova ficha'), findsOneWidget);
    expect(find.text('Duplicar plano'), findsOneWidget);
    // Plano em uso não oferece "Definir como plano em uso".
    expect(find.text('DEFINIR COMO PLANO EM USO'), findsNothing);
  });

  testWidgets('Plano fora de uso oferece "Definir como plano em uso"',
      (tester) async {
    await tester.pumpWidget(_tela(_plano(emUso: false), tema: AppTheme.escuro));
    await tester.pumpAndSettle();

    expect(find.text('PLANO EM USO'), findsNothing);
    await tester.ensureVisible(find.text('DEFINIR COMO PLANO EM USO'));
    expect(find.text('DEFINIR COMO PLANO EM USO'), findsOneWidget);
  });

  testWidgets('Ficha de nome longo mostra a posição no quadrado',
      (tester) async {
    await tester.pumpWidget(_tela(_plano(fichas: [
      _ficha('fa', 'A', 1),
      _ficha('fp', 'Peito pesado', 2),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Peito pesado'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('PBI-58: lápis e lixeira no topo; rodapé só com Duplicar',
      (tester) async {
    await tester.pumpWidget(_tela(_plano()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Renomear plano'), findsOneWidget);
    expect(find.byTooltip('Excluir plano'), findsOneWidget);
    expect(find.text('Renomear'), findsNothing);
    expect(find.text('Excluir plano'), findsNothing);
    expect(find.text('Duplicar plano'), findsOneWidget);

    // Os dois botões têm 44 px.
    final lixeira = tester.getSize(find.byTooltip('Excluir plano'));
    expect(lixeira.width, greaterThanOrEqualTo(44));
    expect(lixeira.height, greaterThanOrEqualTo(44));
  });

  testWidgets('PBI-58: plano do professor não mostra lápis nem lixeira',
      (tester) async {
    final professor = PlanoDetalhe(
      id: 'p9',
      nome: 'Força 5 dias',
      inicio: DateTime(2026, 8, 1),
      emUso: false,
      autor: 'Rafael',
      somenteLeitura: true,
      treinos: [_ficha('fa', 'A', 1)],
    );
    await tester.pumpWidget(_tela(professor));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Renomear plano'), findsNothing);
    expect(find.byTooltip('Excluir plano'), findsNothing);
    expect(find.text('Copiar para editar'), findsOneWidget);
  });

  testWidgets('Excluir plano em uso explica que o uso passa adiante',
      (tester) async {
    await tester.pumpWidget(_tela(_plano()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Excluir plano'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir plano?'), findsOneWidget);
    expect(find.textContaining('o uso passa para o último plano que você usou'),
        findsOneWidget);
  });
}
