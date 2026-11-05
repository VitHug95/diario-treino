import 'package:diario_treino/shared/mostrar_aviso.dart';
import 'package:diario_treino/theme/app_colors.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tela mínima com um botão que dispara [acao] com um BuildContext real.
Widget _tela(void Function(BuildContext) acao, {ThemeData? tema}) => MaterialApp(
      theme: tema ?? AppTheme.claro,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => acao(context),
            child: const Text('disparar'),
          ),
        ),
      ),
    );

SnackBar _snack(WidgetTester tester) => tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  // O tema é montado DENTRO do teste: o AppTheme carrega as fontes e precisa do
  // binding já inicializado (no corpo do main() ele ainda não existe).
  for (final escuro in [false, true]) {
    testWidgets(
        'PBI-75 (${escuro ? 'escuro' : 'claro'}): mostrarAviso é a pílula, sem ação e some sozinha',
        (tester) async {
      final tema = escuro ? AppTheme.escuro : AppTheme.claro;
      await tester.pumpWidget(_tela((c) => mostrarAviso(c, 'Ficha criada'), tema: tema));
      await tester.tap(find.text('disparar'));
      await tester.pump();

      final s = _snack(tester);
      final cores = tema.extension<AppColors>()!;
      expect(find.text('Ficha criada'), findsOneWidget);
      expect(s.behavior, SnackBarBehavior.floating);
      expect(s.shape, isA<StadiumBorder>());
      expect(s.backgroundColor, cores.primaryTint);
      expect(s.action, isNull);
      expect(s.duration, const Duration(seconds: 2));
    });
  }

  testWidgets('PBI-75: mostrarErro NÃO é a pílula (erro não parece confirmação)',
      (tester) async {
    await tester.pumpWidget(_tela((c) => mostrarErro(c, 'Convite não encontrado.')));
    await tester.tap(find.text('disparar'));
    await tester.pump();

    final s = _snack(tester);
    final cores = AppTheme.claro.extension<AppColors>()!;
    expect(find.text('Convite não encontrado.'), findsOneWidget);
    expect(s.shape, isNot(isA<StadiumBorder>()));
    expect(s.backgroundColor, isNot(cores.primaryTint));
  });

  testWidgets('PBI-75: um aviso novo substitui o anterior (não empilha)', (tester) async {
    var n = 0;
    await tester.pumpWidget(_tela((c) => mostrarAviso(c, 'Aviso ${++n}')));
    await tester.tap(find.text('disparar'));
    await tester.pump();
    await tester.tap(find.text('disparar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Aviso 1'), findsNothing);
    expect(find.text('Aviso 2'), findsOneWidget);
  });
}
