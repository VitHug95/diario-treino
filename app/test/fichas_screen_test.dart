import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/fichas_screen.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _tela(Future<PlanoAtivo?> Function(Ref ref) resultado) => ProviderScope(
      overrides: [planoAtivoProvider.overrideWith(resultado)],
      child: MaterialApp(theme: AppTheme.claro, home: const FichasScreen()),
    );

PlanoAtivo _plano(List<TreinoResumo> treinos) =>
    PlanoAtivo(id: 'p1', nome: 'Meu plano', treinos: treinos);

TreinoResumo _ficha(String nome, int ordem, {String? desc}) =>
    TreinoResumo(id: 'f$ordem', nome: nome, descricao: desc, ordem: ordem);

void main() {
  testWidgets('Mostra uma aba por ficha e o nome da selecionada', (tester) async {
    await tester.pumpWidget(_tela((ref) async => _plano([
          _ficha('A', 1, desc: 'Peito e tríceps'),
          _ficha('B', 2),
          _ficha('C', 3),
        ])));
    await tester.pumpAndSettle();

    // Três abas (ChoiceChip) — não é fixo em 3, é por ficha.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    // A primeira ficha vem selecionada: nome e descrição aparecem.
    expect(find.text('Peito e tríceps'), findsOneWidget);
  });

  testWidgets('Estado vazio convida a criar a primeira ficha', (tester) async {
    await tester.pumpWidget(_tela((ref) async => null));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'CRIAR FICHA'), findsOneWidget);
  });
}
