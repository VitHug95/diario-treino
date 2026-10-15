import 'package:diario_treino/shared/dialogos_perigo.dart';
import 'package:diario_treino/theme/app_colors.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Diálogos da PBI-53. Um ÚNICO `testWidgets`: o google_fonts, sem rede nos
/// testes, deixa um fetch de fonte pendente que, entre dois testes que abrem
/// diálogo, resolve fora da test zone e derruba a suíte. Com um teste só (vários
/// cenários em sequência, fechando cada diálogo) isso não ocorre.
///
/// Verificado no tema claro. As cores vêm 100% de tokens (`cores.dangerFill` e
/// `cores.danger`), então o comportamento no tema escuro é o mesmo por
/// construção — a conferência visual nos dois temas faz parte do DoD.
void main() {
  testWidgets('PBI-53: perigo em vermelho e saída do treino em coluna',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.claro,
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Center(child: Text('base')));
      }),
    ));
    final cores = AppColors.of(ctx);

    // --- confirmarPerigo: confirmar vermelho cheio (CA 1), cancelar mesmo peso ---
    final fConfirmar = confirmarPerigo(
      ctx,
      titulo: 'Descartar treino?',
      texto: 'O que você preencheu neste treino será perdido.',
      rotuloConfirmar: 'Descartar',
      rotuloCancelar: 'Voltar',
    );
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(FilledButton, 'Descartar');
    expect(confirmar, findsOneWidget);
    final fundo =
        tester.widget<FilledButton>(confirmar).style!.backgroundColor!.resolve({});
    expect(fundo, cores.dangerFill);
    // Cancelar com o mesmo tamanho (ambos 48 px).
    expect(find.widgetWithText(OutlinedButton, 'Voltar'), findsOneWidget);
    final alturas = tester
        .widgetList<SizedBox>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SizedBox),
        ))
        .map((s) => s.height)
        .whereType<double>()
        .toSet();
    expect(alturas, contains(48.0));

    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    expect(await fConfirmar, isTrue);

    // --- confirmarPerigo: cancelar devolve false ---
    final fCancelar = confirmarPerigo(
      ctx,
      titulo: 'Excluir ficha?',
      texto: 'A ficha sai da lista.',
      rotuloConfirmar: 'Excluir ficha',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(await fCancelar, isFalse);

    // --- dialogoSairDoTreino: três botões em coluna, da ordem segura à perigosa ---
    final fSair = dialogoSairDoTreino(ctx);
    await tester.pumpAndSettle();

    final finalizar = find.widgetWithText(FilledButton, 'Finalizar agora');
    final continuar = find.widgetWithText(OutlinedButton, 'Continuar depois');
    final descartar = find.widgetWithText(TextButton, 'Descartar treino');
    expect(finalizar, findsOneWidget);
    expect(continuar, findsOneWidget);
    expect(descartar, findsOneWidget);
    // Ordem de cima para baixo (CA 3).
    expect(tester.getTopLeft(finalizar).dy,
        lessThan(tester.getTopLeft(continuar).dy));
    expect(tester.getTopLeft(continuar).dy,
        lessThan(tester.getTopLeft(descartar).dy));
    // Descartar é texto vermelho (danger).
    final corDescartar =
        tester.widget<TextButton>(descartar).style!.foregroundColor!.resolve({});
    expect(corDescartar, cores.danger);

    await tester.tap(finalizar);
    await tester.pumpAndSettle();
    expect(await fSair, SaidaTreino.finalizar);
  });
}
