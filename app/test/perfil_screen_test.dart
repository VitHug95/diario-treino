import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/perfil_api.dart';
import 'package:diario_treino/features/auth/perfil_screen.dart';
import 'package:diario_treino/features/educador/educador_models.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _tela({Perfil? perfil, List<ConvitePendente> convites = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      perfilProvider.overrideWith((ref) async =>
          perfil ??
          const Perfil(
            id: 'u1',
            nome: 'Vitor Hugo',
            email: 'vitor@teste.local',
            papeis: ['ATLETA'],
          )),
      convitesPendentesProvider.overrideWith((ref) async => convites),
    ],
    child: MaterialApp(theme: AppTheme.claro, home: const PerfilScreen()),
  );
}

void main() {
  testWidgets('Mostra nome e e-mail do GET /me', (tester) async {
    await tester.pumpWidget(await _tela());
    await tester.pumpAndSettle();

    expect(find.text('Vitor Hugo'), findsOneWidget);
    expect(find.text('vitor@teste.local'), findsOneWidget);
  });

  testWidgets('Oferece as três opções de tema', (tester) async {
    await tester.pumpWidget(await _tela());
    await tester.pumpAndSettle();

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
  });

  testWidgets('Excluir conta exige digitar EXCLUIR para liberar', (tester) async {
    await tester.pumpWidget(await _tela());
    await tester.pumpAndSettle();

    // Abre o diálogo. A seção educador empurra o botão para baixo da viewport;
    // rola a lista até ele antes de tocar.
    await tester.scrollUntilVisible(find.text('Excluir conta'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();

    // O botão de confirmar começa desabilitado.
    final botaoConfirmar = find.widgetWithText(FilledButton, 'Excluir conta');
    expect(tester.widget<FilledButton>(botaoConfirmar).onPressed, isNull);

    // Digitar algo errado não libera.
    await tester.enterText(find.byType(TextField), 'apagar');
    await tester.pump();
    expect(tester.widget<FilledButton>(botaoConfirmar).onPressed, isNull);

    // Digitar EXCLUIR (aceita caixa diferente) libera.
    await tester.enterText(find.byType(TextField), 'excluir');
    await tester.pump();
    expect(tester.widget<FilledButton>(botaoConfirmar).onPressed, isNotNull);
  });

  // ---- PBI-88: gate do modo educador por papel ----

  testWidgets('Atleta sem o papel educador vê "Ativar modo educador"',
      (tester) async {
    await tester.pumpWidget(await _tela(
      perfil: const Perfil(
        id: 'u1', nome: 'Vitor', email: 'v@teste.local', papeis: ['ATLETA']),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ativar modo educador'), findsOneWidget);
    // Sem o papel, não oferece as ações de educador.
    expect(find.text('Meus alunos'), findsNothing);
    expect(find.text('Convidar aluno'), findsNothing);
    // "Convites recebidos" aparece para qualquer um (pode ser convidado).
    expect(find.text('Convites recebidos'), findsOneWidget);
  });

  testWidgets('Quem tem o papel educador vê "Meus alunos" e "Convidar aluno"',
      (tester) async {
    await tester.pumpWidget(await _tela(
      perfil: const Perfil(
        id: 'u1', nome: 'Vitor', email: 'v@teste.local',
        papeis: ['ATLETA', 'EDUCADOR']),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Meus alunos'), findsOneWidget);
    expect(find.text('Convidar aluno'), findsOneWidget);
    expect(find.text('Ativar modo educador'), findsNothing);
  });

  testWidgets('Convites pendentes mostram a contagem no Perfil', (tester) async {
    await tester.pumpWidget(await _tela(
      convites: const [
        ConvitePendente(
          vinculoId: 'v1', educadorId: 'e1',
          educadorNome: 'Prof. Ana', educadorEmail: 'ana@teste.local'),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 convite(s) aguardando'), findsOneWidget);
  });
}
