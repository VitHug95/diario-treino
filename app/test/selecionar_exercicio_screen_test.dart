import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/exercicio_resumo.dart';
import 'package:diario_treino/features/catalogo/selecionar_exercicio_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ExercicioResumo _ex(String nome) => ExercicioResumo(
      id: nome,
      nome: nome,
      grupoMuscular: 'peito',
      membroId: 1,
      membroNome: 'Peito',
      musculoId: 1,
      musculoNome: 'Peitoral',
      modalidade: 'FORCA',
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      proprio: false,
    );

Widget _app(Future<List<ExercicioResumo>> Function(Ref ref) resultado) =>
    ProviderScope(
      overrides: [
        catalogoProvider.overrideWith(resultado),
        // Chips de membro: sem rede nos testes.
        membrosProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: const SelecionarExercicioScreen(),
      ),
    );

void main() {
  testWidgets('Mostra o atalho "Criar exercício novo" com a lista cheia',
      (tester) async {
    await tester.pumpWidget(_app((ref) async => [_ex('Supino reto')]));
    await tester.pumpAndSettle();

    expect(find.text('Supino reto'), findsOneWidget);
    // Botão fixo de criar sempre disponível no rodapé.
    expect(find.text('Criar exercício novo'), findsOneWidget);
  });

  testWidgets('Estado vazio sugere criar usando o texto buscado',
      (tester) async {
    await tester.pumpWidget(_app((ref) async => <ExercicioResumo>[]));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum exercício encontrado'), findsOneWidget);

    // Digita uma busca: o estado vazio passa a sugerir criar com aquele nome.
    await tester.enterText(find.byType(TextField), 'Agachamento búlgaro');
    // Espera o debounce da busca (350ms) e o rebuild.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Criar "Agachamento búlgaro"'), findsOneWidget);
  });

  testWidgets('Abre com a busca limpa mesmo se havia filtro anterior',
      (tester) async {
    // Simula o provider global tendo sobrado uma busca de uma seleção anterior.
    final container = ProviderContainer(
      overrides: [
        catalogoProvider.overrideWith((ref) async => [_ex('Supino reto')]),
        membrosProvider.overrideWith((ref) async => []),
      ],
    );
    addTearDown(container.dispose);
    container.read(catalogoFiltroProvider.notifier).definirBusca('supino');
    container.read(catalogoFiltroProvider.notifier).definirMembro(1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.claro,
          // A lista reflete o filtro atual: se não limpar, viria vazia/filtrada.
          home: const SelecionarExercicioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Depois de montar, o seletor zerou o filtro global.
    final filtro = container.read(catalogoFiltroProvider);
    expect(filtro.busca, '');
    expect(filtro.membroId, isNull);
    // E o campo de busca aparece vazio.
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.controller?.text ?? '', '');
  });
}
