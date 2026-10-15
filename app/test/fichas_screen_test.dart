import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/fichas_screen.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PlanoAtivo _plano(List<TreinoResumo> treinos) =>
    PlanoAtivo(id: 'p1', nome: 'Meu plano', treinos: treinos);

TreinoResumo _ficha(String nome, int ordem, {String? desc}) =>
    TreinoResumo(id: 'f$ordem', nome: nome, descricao: desc, ordem: ordem);

TreinoDetalhe _detalhe(String id, List<TreinoExercicioResumo> ex) =>
    TreinoDetalhe(id: id, nome: 'A', descricao: null, ordem: 1, exercicios: ex);

TreinoExercicioResumo _ex(String nome, int ordem) => TreinoExercicioResumo(
      id: 'te$ordem',
      exercicioId: 'e$ordem',
      nome: nome,
      grupoMuscular: 'peito',
      modalidade: 'FORCA',
      ordem: ordem,
      rodadas: 1,
      descansoSeg: null,
      instrucao: null,
      alvo: null,
    );

Widget _tela({
  required Future<PlanoAtivo?> Function(Ref ref) plano,
  TreinoDetalhe Function(String treinoId)? detalhe,
  String? fichaInicialId,
}) =>
    ProviderScope(
      overrides: [
        planoAtivoProvider.overrideWith(plano),
        if (detalhe != null)
          fichaDetalheProvider.overrideWith((ref, treinoId) async => detalhe(treinoId)),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: FichasScreen(fichaInicialId: fichaInicialId),
      ),
    );

void main() {
  testWidgets('Mostra uma aba por ficha e lista os exercícios da selecionada',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([
        _ficha('A', 1, desc: 'Peito e tríceps'),
        _ficha('B', 2),
        _ficha('C', 3),
      ]),
      detalhe: (id) => _detalhe(id, [_ex('Supino reto', 1), _ex('Crucifixo', 2)]),
    ));
    await tester.pumpAndSettle();

    // Três abas (ChoiceChip) — por ficha, não fixo em 3.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text('Peito e tríceps'), findsOneWidget);
    // Exercícios da ficha selecionada.
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Crucifixo'), findsOneWidget);
    expect(find.text('Adicionar exercício à ficha'), findsOneWidget);
  });

  testWidgets('Ficha sem exercícios mostra o estado vazio', (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, const []),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ficha sem exercícios'), findsOneWidget);
  });

  testWidgets('Estado vazio convida a criar a primeira ficha', (tester) async {
    await tester.pumpWidget(_tela(plano: (ref) async => null));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'CRIAR FICHA'), findsOneWidget);
  });

  testWidgets('PBI-50: ?ficha=<id> abre com a ficha correspondente selecionada',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([
        _ficha('A', 1, desc: 'Peito e tríceps'),
        _ficha('B', 2, desc: 'Costas e bíceps'),
        _ficha('C', 3, desc: 'Pernas'),
      ]),
      detalhe: (id) => _detalhe(id, [_ex('Exercício de $id', 1)]),
      fichaInicialId: 'f2', // id da ficha B (ver _ficha: 'f$ordem')
    ));
    await tester.pumpAndSettle();

    // O cabeçalho de detalhe mostra a ficha B (descrição distinta) e seus
    // exercícios, não a primeira ficha.
    expect(find.text('Costas e bíceps'), findsOneWidget);
    expect(find.text('Exercício de f2'), findsOneWidget);
  });

  testWidgets('PBI-50: ?ficha com id inexistente cai na primeira ficha',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([
        _ficha('A', 1, desc: 'Peito e tríceps'),
        _ficha('B', 2, desc: 'Costas e bíceps'),
      ]),
      detalhe: (id) => _detalhe(id, [_ex('Exercício de $id', 1)]),
      fichaInicialId: 'nao-existe',
    ));
    await tester.pumpAndSettle();

    // Sem erro: fica na primeira ficha (A).
    expect(find.text('Peito e tríceps'), findsOneWidget);
    expect(find.text('Exercício de f1'), findsOneWidget);
  });

  testWidgets('Excluir ficha pede confirmação explicando o histórico (PBI-36)',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, const []),
    ));
    await tester.pumpAndSettle();

    // Aciona "Excluir ficha" (ícone com tooltip).
    await tester.tap(find.byTooltip('Excluir ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir ficha?'), findsOneWidget);
    expect(
      find.textContaining(
          'Os treinos já registrados com esta ficha continuam no seu histórico'),
      findsOneWidget,
    );
    // Botão de confirmar com o rótulo da ação.
    expect(find.widgetWithText(FilledButton, 'Excluir ficha'), findsOneWidget);
  });
}
