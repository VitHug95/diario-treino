import 'package:diario_treino/features/auth/login_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login valida e-mail e senha antes de tentar autenticar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.claro, home: const LoginScreen()),
      ),
    );

    // Toca em ENTRAR sem preencher nada: mostra as mensagens de validação.
    final botao = find.widgetWithText(FilledButton, 'ENTRAR');
    await tester.ensureVisible(botao);
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(find.text('Informe um e-mail válido'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
  });
}
