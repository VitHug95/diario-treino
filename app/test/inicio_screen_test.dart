import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/inicio/inicio_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Tela inicial mostra o título e alterna o tema', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Testa a InicioScreen isolada (sem roteador/Firebase), com os temas reais.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.claro,
          darkTheme: AppTheme.escuro,
          home: const InicioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Diário de Treino'), findsOneWidget);

    // Alterna o tema pelo botão da AppBar e confirma que persistiu.
    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();

    expect(prefs.getString('tema_modo'), 'escuro');
  });
}
