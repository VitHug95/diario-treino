import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/inicio/inicio_screen.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Tela inicial saúda o atleta e alterna o tema', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Sem Firebase no teste: estado de autenticação sem usuário.
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          darkTheme: AppTheme.escuro,
          home: const InicioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sem usuário, o nome cai no padrão "Atleta".
    expect(find.text('BORA, ATLETA'), findsOneWidget);

    // Alterna o tema pelo botão e confirma que persistiu.
    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();

    expect(prefs.getString('tema_modo'), 'escuro');
  });
}
