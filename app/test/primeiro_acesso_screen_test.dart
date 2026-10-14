import 'package:diario_treino/features/inicio/primeiro_acesso_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Mostra as boas-vindas e os dois caminhos (PBI-09)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.claro,
        home: const PrimeiroAcessoScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsOneWidget);
    expect(find.text('MONTAR MINHAS FICHAS'), findsOneWidget);
    expect(find.text('Registrar sem ficha'), findsOneWidget);

    // Os três passos do "como funciona".
    expect(find.text('Monte suas fichas'), findsOneWidget);
    expect(find.text('Registre o treino'), findsOneWidget);
    expect(find.text('Acompanhe a evolução'), findsOneWidget);
  });
}
