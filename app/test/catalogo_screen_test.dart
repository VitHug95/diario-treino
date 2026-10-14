import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/catalogo_screen.dart';
import 'package:diario_treino/features/catalogo/exercicio_resumo.dart';
import 'package:diario_treino/features/catalogo/membro.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _membros = <Membro>[
  const Membro(
    id: 1,
    codigo: 'PEITO',
    nome: 'Peito',
    ordem: 1,
    musculos: [Musculo(id: 1, codigo: 'PEITORAL', nome: 'Peitoral')],
  ),
  const Membro(
    id: 5,
    codigo: 'PERNAS',
    nome: 'Pernas',
    ordem: 5,
    musculos: [Musculo(id: 7, codigo: 'QUADRICEPS', nome: 'Quadríceps')],
  ),
];

ExercicioResumo _ex({
  required String nome,
  String? membroNome,
  String? musculoNome,
  bool proprio = false,
}) =>
    ExercicioResumo(
      id: nome,
      nome: nome,
      grupoMuscular: null,
      membroId: membroNome == null ? null : 1,
      membroNome: membroNome,
      musculoId: musculoNome == null ? null : 1,
      musculoNome: musculoNome,
      modalidade: 'FORCA',
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      proprio: proprio,
    );

Widget _appComResultado(Future<List<ExercicioResumo>> Function(Ref ref) resultado) =>
    ProviderScope(
      overrides: [
        catalogoProvider.overrideWith(resultado),
        // Chips de membro: sem rede nos testes.
        membrosProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: const CatalogoScreen()),
    );

void main() {
  testWidgets('Lista exercícios com grupo, forma de medir e selo Meu',
      (tester) async {
    await tester.pumpWidget(_appComResultado((ref) async => [
          _ex(nome: 'Supino reto', membroNome: 'Peito', musculoNome: 'Peitoral'),
          _ex(nome: 'Rosca direta minha', membroNome: 'Braços', proprio: true),
        ]));
    await tester.pumpAndSettle();

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Rosca direta minha'), findsOneWidget);
    // Membro · músculo + forma de medir no subtítulo.
    expect(find.text('Peito · Peitoral · Carga × Repetições'), findsOneWidget);
    // Selo "Meu" só no exercício próprio.
    expect(find.text('Meu'), findsOneWidget);
  });

  testWidgets('Estado vazio sugere criar exercício', (tester) async {
    await tester.pumpWidget(_appComResultado((ref) async => <ExercicioResumo>[]));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum exercício encontrado'), findsOneWidget);
    expect(find.text('Criar exercício'), findsOneWidget);
  });

  testWidgets('Chips de membro: "Todos" + membros do GET /membros, e tocar um filtra',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogoProvider.overrideWith((ref) async => <ExercicioResumo>[]),
          membrosProvider.overrideWith((ref) async => _membros),
        ],
        child: MaterialApp(theme: AppTheme.claro, home: const CatalogoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // "Todos" + os membros viram chips.
    expect(find.widgetWithText(ChoiceChip, 'Todos'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Peito'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Pernas'), findsOneWidget);

    // Começa em "Todos" (membro nulo).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CatalogoScreen)),
    );
    expect(container.read(catalogoFiltroProvider).membroId, isNull);

    // Tocar "Peito" define o filtro por membro.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Peito'));
    await tester.pumpAndSettle();
    expect(container.read(catalogoFiltroProvider).membroId, 1);
  });
}
