import 'package:diario_treino/features/sessao/registrar_sessao_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Treino livre começa vazio com adicionar e salvar como ficha (PBI-19)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.claro,
          home: const TreinoLivreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Treino livre'), findsOneWidget);
    // Começa sem exercícios, com o convite para adicionar.
    expect(find.textContaining('Nenhum exercício ainda'), findsOneWidget);
    expect(find.text('Adicionar exercício'), findsOneWidget);
    // Opção de também salvar como ficha.
    expect(find.text('Salvar também como ficha'), findsOneWidget);
    // Botão de finalizar o treino.
    expect(find.text('FINALIZAR TREINO'), findsOneWidget);
  });
}
