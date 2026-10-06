import 'package:diario_treino/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login valida e-mail e senha antes de tentar autenticar',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    // Toca em Entrar sem preencher nada: mostra as mensagens de validação.
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
  });
}
