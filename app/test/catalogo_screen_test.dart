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

  testWidgets(
      'Filtro de músculo (PBI-54): campo abre folha com "Todos" + membros e aplica',
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

    // Não há mais chips de rolagem lateral; o filtro é um campo "Músculo".
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Músculo'), findsOneWidget);

    // Começa em "Todos" (membro nulo).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CatalogoScreen)),
    );
    expect(container.read(catalogoFiltroProvider).membroId, isNull);

    // Toca o campo: abre a folha com "Todos" + os membros, sem rolagem lateral.
    await tester.tap(find.text('Músculo'));
    await tester.pumpAndSettle();
    expect(find.text('FILTRAR POR MÚSCULO'), findsOneWidget);
    // "Todos" aparece no campo (valor atual) e na folha (opção) enquanto aberta.
    expect(find.text('Todos'), findsNWidgets(2));
    expect(find.text('Peito'), findsOneWidget);
    expect(find.text('Pernas'), findsOneWidget);

    // Escolher "Peito" aplica o filtro e fecha a folha.
    await tester.tap(find.text('Peito'));
    await tester.pumpAndSettle();
    expect(container.read(catalogoFiltroProvider).membroId, 1);
    expect(find.text('FILTRAR POR MÚSCULO'), findsNothing);

    // O campo passa a mostrar o músculo escolhido.
    expect(find.text('Peito'), findsOneWidget);
  });
}
