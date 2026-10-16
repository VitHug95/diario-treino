import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/planos/planos_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PlanoDaLista _plano(
  String nome, {
  required String inicio,
  bool emUso = false,
  bool professor = false,
  int fichas = 3,
  int exercicios = 14,
}) =>
    PlanoDaLista(
      id: 'id-$nome',
      nome: nome,
      inicio: DateTime.parse(inicio),
      emUso: emUso,
      autor: professor ? 'Rafael' : 'Vitor',
      somenteLeitura: professor,
      quantidadeFichas: fichas,
      quantidadeExercicios: exercicios,
    );

/// Três planos fora de ordem: a tela precisa pôr o em uso primeiro e depois
/// o início mais recente.
final _tres = [
  _plano('Força 5 dias', inicio: '2026-08-01', professor: true, exercicios: 15),
  _plano('Treino de viagem', inicio: '2026-10-03', fichas: 2, exercicios: 8),
  _plano('Hipertrofia', inicio: '2026-09-12', emUso: true),
];

Widget _tela(Future<List<PlanoDaLista>> Function(Ref ref) planos,
        {ThemeData? tema}) =>
    ProviderScope(
      overrides: [planosProvider.overrideWith(planos)],
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: const PlanosScreen(),
      ),
    );

void main() {
  test('ordenarPlanos: em uso primeiro, depois o início mais recente', () {
    final nomes = ordenarPlanos(_tres).map((p) => p.nome).toList();
    expect(nomes, ['Hipertrofia', 'Treino de viagem', 'Força 5 dias']);
  });

  testWidgets('Lista os planos com o em uso primeiro e a tag "Em uso"',
      (tester) async {
    await tester.pumpWidget(_tela((ref) async => _tres));
    await tester.pumpAndSettle();

    expect(find.text('PLANOS'), findsOneWidget);
    expect(find.text('NOVO PLANO'), findsOneWidget);

    // Ordem na tela: Hipertrofia (em uso) acima de Treino de viagem, que fica
    // acima de Força 5 dias.
    final yHiper = tester.getTopLeft(find.text('HIPERTROFIA')).dy;
    final yViagem = tester.getTopLeft(find.text('TREINO DE VIAGEM')).dy;
    final yForca = tester.getTopLeft(find.text('FORÇA 5 DIAS')).dy;
    expect(yHiper, lessThan(yViagem));
    expect(yViagem, lessThan(yForca));

    // Uma única tag "Em uso", e o resumo do plano próprio com a data.
    expect(find.text('Em uso'), findsOneWidget);
    expect(find.text('3 fichas · 14 exercícios · desde 12/09/2026'), findsOneWidget);
    expect(find.text('2 fichas · 8 exercícios · desde 03/10/2026'), findsOneWidget);
  });

  testWidgets('Plano do professor mostra o autor e o chip com cadeado',
      (tester) async {
    await tester.pumpWidget(_tela((ref) async => _tres, tema: AppTheme.escuro));
    await tester.pumpAndSettle();

    expect(find.text('3 fichas · 15 exercícios · Prof. Rafael'), findsOneWidget);
    expect(find.text('Do professor · só leitura'), findsOneWidget);
  });

  testWidgets('Cada cartão expõe "abrir" e "menu" como alvos separados',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_tela((ref) async => _tres));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Abrir plano Hipertrofia'), findsOneWidget);
    expect(find.byTooltip('Mais ações de Hipertrofia'), findsOneWidget);

    // Os dois alvos têm no mínimo 44 px.
    final abrir = tester.getSize(find.bySemanticsLabel('Abrir plano Hipertrofia'));
    final menu = tester.getSize(find.byTooltip('Mais ações de Hipertrofia'));
    expect(abrir.height, greaterThanOrEqualTo(44));
    expect(menu.width, greaterThanOrEqualTo(44));
    expect(menu.height, greaterThanOrEqualTo(44));
    handle.dispose();
  });

  testWidgets('Sem planos, mostra o Primeiro acesso', (tester) async {
    await tester.pumpWidget(_tela((ref) async => <PlanoDaLista>[]));
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsOneWidget);
    expect(find.text('MONTAR MINHAS FICHAS'), findsOneWidget);
  });

  testWidgets('Erro ao carregar oferece "Tentar de novo"', (tester) async {
    await tester.pumpWidget(
        _tela((ref) async => throw Exception('sem rede')));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar os planos.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('Menu do plano em uso não oferece "Definir como em uso"',
      (tester) async {
    await tester.pumpWidget(_tela((ref) async => _tres));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mais ações de Hipertrofia'));
    await tester.pumpAndSettle();

    expect(find.text('Definir como em uso'), findsNothing);
    expect(find.text('Duplicar plano'), findsOneWidget);
    expect(find.text('Renomear'), findsOneWidget);
    expect(find.text('Excluir plano'), findsOneWidget);
  });
}
