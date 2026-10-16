import 'package:diario_treino/shared/estado_erro.dart';
import 'package:diario_treino/shared/estado_vazio.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: AppTheme.claro, home: Scaffold(body: child));

void main() {
  testWidgets('EstadoErro mostra a mensagem e aciona aoTentar', (tester) async {
    var tentou = 0;
    await tester.pumpWidget(_app(EstadoErro(
      mensagem: 'Não foi possível carregar as fichas.',
      aoTentar: () => tentou++,
    )));

    expect(find.text('Não foi possível carregar as fichas.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tentar de novo'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tentar de novo'));
    expect(tentou, 1);
  });

  testWidgets('EstadoVazio com ação mostra título, texto e o botão', (tester) async {
    var criou = 0;
    await tester.pumpWidget(_app(EstadoVazio(
      icone: LucideIcons.clipboardList,
      titulo: 'Nenhuma ficha ainda',
      texto: 'Crie o Treino A para começar.',
      acao: FilledButton(
        onPressed: () => criou++,
        child: const Text('CRIAR FICHA'),
      ),
    )));

    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
    expect(find.text('Crie o Treino A para começar.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'CRIAR FICHA'));
    expect(criou, 1);
  });

  testWidgets('EstadoVazio sem ação não mostra botão', (tester) async {
    await tester.pumpWidget(_app(const EstadoVazio(
      icone: LucideIcons.calendarOff,
      titulo: 'Nenhum treino neste período',
      texto: 'Registre um treino para acompanhar.',
    )));

    expect(find.text('Nenhum treino neste período'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
