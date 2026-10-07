import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/catalogo_screen.dart';
import 'package:diario_treino/features/catalogo/exercicio_resumo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ExercicioResumo _ex({
  required String nome,
  String? grupo,
  bool proprio = false,
}) =>
    ExercicioResumo(
      id: nome,
      nome: nome,
      grupoMuscular: grupo,
      modalidade: 'FORCA',
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      proprio: proprio,
    );

Widget _appComResultado(Future<List<ExercicioResumo>> Function(Ref ref) resultado) =>
    ProviderScope(
      overrides: [catalogoProvider.overrideWith(resultado)],
      child: const MaterialApp(home: CatalogoScreen()),
    );

void main() {
  testWidgets('Lista exercícios com grupo, forma de medir e selo Meu',
      (tester) async {
    await tester.pumpWidget(_appComResultado((ref) async => [
          _ex(nome: 'Supino reto', grupo: 'peito'),
          _ex(nome: 'Rosca direta minha', grupo: 'braço', proprio: true),
        ]));
    await tester.pumpAndSettle();

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Rosca direta minha'), findsOneWidget);
    // Grupo + forma de medir no subtítulo.
    expect(find.text('peito · Carga × Repetições'), findsOneWidget);
    // Selo "Meu" só no exercício próprio.
    expect(find.text('Meu'), findsOneWidget);
  });

  testWidgets('Estado vazio sugere criar exercício', (tester) async {
    await tester.pumpWidget(_appComResultado((ref) async => <ExercicioResumo>[]));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum exercício encontrado'), findsOneWidget);
    expect(find.text('Criar exercício'), findsOneWidget);
  });
}
