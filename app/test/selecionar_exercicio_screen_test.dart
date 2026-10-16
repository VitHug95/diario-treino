import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/exercicio_resumo.dart';
import 'package:diario_treino/features/catalogo/membro.dart';
import 'package:diario_treino/features/catalogo/selecionar_exercicio_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ExercicioResumo _ex(String nome, {int membro = 1, bool proprio = false}) => ExercicioResumo(
      id: nome,
      nome: nome,
      grupoMuscular: null,
      membroId: membro,
      membroNome: membro == 1 ? 'Peito' : 'Costas',
      musculoId: null,
      musculoNome: membro == 1 ? 'Peitoral' : 'Dorsal',
      modalidade: 'FORCA',
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      proprio: proprio,
    );

const _membros = [
  Membro(id: 1, codigo: 'PEITO', nome: 'Peito', ordem: 1, musculos: []),
  Membro(id: 2, codigo: 'COSTAS', nome: 'Costas', ordem: 2, musculos: []),
];

/// Abre o seletor por cima de uma tela que guarda o que ele devolveu.
class _Abridor extends StatefulWidget {
  const _Abridor();

  @override
  State<_Abridor> createState() => _AbridorState();
}

class _AbridorState extends State<_Abridor> {
  String _resultado = 'nada';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Text('Resultado: $_resultado'),
            TextButton(
              onPressed: () async {
                final r = await Navigator.of(context).push<List<ExercicioResumo>>(
                  MaterialPageRoute(
                      builder: (_) => const SelecionarExercicioScreen(destino: 'Treino A')),
                );
                setState(() => _resultado = r == null ? 'nulo' : r.map((e) => e.nome).join(','));
              },
              child: const Text('Abrir'),
            ),
          ],
        ),
      );
}

Future<void> _abrir(WidgetTester tester, List<ExercicioResumo> itens) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      catalogoProvider.overrideWith((ref) async => itens),
      membrosProvider.overrideWith((ref) async => _membros),
    ],
    child: MaterialApp(theme: AppTheme.claro, home: const _Abridor()),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

final _tres = [_ex('Supino reto'), _ex('Crucifixo'), _ex('Remada', membro: 2, proprio: true)];

void main() {
  testWidgets('PBI-49: cabeçalho, sem "Fechar", criar como primeira linha', (tester) async {
    await _abrir(tester, _tres);

    expect(find.text('Adicionar exercícios'), findsOneWidget);
    expect(find.text('TREINO A'), findsOneWidget);
    expect(find.text('Fechar'), findsNothing);
    expect(find.byTooltip('Voltar sem adicionar'), findsOneWidget);
    expect(find.text('Criar exercício novo'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Criar exercício novo')).dy,
        lessThan(tester.getTopLeft(find.text('Supino reto')).dy));
    // "Meu" e "músculo · forma de medir".
    expect(find.text('Meu'), findsOneWidget);
    expect(find.text('Peitoral · Carga × Repetições'), findsNWidgets(2));
  });

  testWidgets('PBI-49: adiciona vários na ordem tocada', (tester) async {
    await _abrir(tester, _tres);

    // Sem seleção, o botão fica desabilitado e pede para escolher.
    expect(find.text('ESCOLHA OS EXERCÍCIOS'), findsOneWidget);
    await tester.tap(find.text('ESCOLHA OS EXERCÍCIOS'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar exercícios'), findsOneWidget);

    await tester.tap(find.text('Remada'));
    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    expect(find.text('ADICIONAR 2 EXERCÍCIOS'), findsOneWidget);

    await tester.tap(find.text('ADICIONAR 2 EXERCÍCIOS'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado: Remada,Supino reto'), findsOneWidget);
  });

  testWidgets('PBI-49: tocar de novo desfaz, com rótulos Adicionar/Remover', (tester) async {
    await _abrir(tester, _tres);

    expect(find.bySemanticsLabel('Adicionar Crucifixo'), findsOneWidget);
    await tester.tap(find.text('Crucifixo'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Remover Crucifixo'), findsOneWidget);
    expect(find.text('ADICIONAR 1 EXERCÍCIO'), findsOneWidget);

    await tester.tap(find.text('Crucifixo'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Adicionar Crucifixo'), findsOneWidget);
    expect(find.text('ESCOLHA OS EXERCÍCIOS'), findsOneWidget);

    // Linha com alvo de 44 px.
    expect(tester.getSize(find.bySemanticsLabel('Adicionar Crucifixo')).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('PBI-49: voltar não adiciona nada', (tester) async {
    await _abrir(tester, _tres);

    await tester.tap(find.text('Supino reto'));
    await tester.tap(find.byTooltip('Voltar sem adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado: nulo'), findsOneWidget);
  });

  testWidgets('PBI-49: filtro mantém as escolhas de outros membros no contador',
      (tester) async {
    await _abrir(tester, _tres);

    await tester.tap(find.text('Remada')); // Costas
    await tester.pumpAndSettle();

    // Folha do filtro com a contagem de cada opção.
    await tester.tap(find.bySemanticsLabel(RegExp('^Filtrar por músculo: Todos')));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget); // Todos
    expect(find.text('2'), findsOneWidget); // Peito
    expect(find.text('1'), findsOneWidget); // Costas
    await tester.tap(find.text('Peito').last);
    await tester.pumpAndSettle();

    expect(find.text('Remada'), findsNothing);
    await tester.tap(find.text('Crucifixo'));
    await tester.pumpAndSettle();
    expect(find.text('ADICIONAR 2 EXERCÍCIOS'), findsOneWidget);
  });

  testWidgets('PBI-49: busca sem resultado mostra um único "Criar"', (tester) async {
    await _abrir(tester, const []);

    await tester.enterText(find.byType(TextField), 'Agachamento búlgaro');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Criar "Agachamento búlgaro"'), findsOneWidget);
    expect(find.text('Criar exercício novo'), findsNothing);

    // Limpar (x) apaga a busca.
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Criar exercício novo'), findsOneWidget);
  });

  testWidgets('Abre com a busca limpa mesmo se havia filtro anterior', (tester) async {
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
        child: MaterialApp(theme: AppTheme.claro, home: const SelecionarExercicioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final filtro = container.read(catalogoFiltroProvider);
    expect(filtro.busca, '');
    expect(filtro.membroId, isNull);
    final campo = tester.widget<TextField>(find.byType(TextField));
    expect(campo.controller?.text ?? '', '');
  });
}
