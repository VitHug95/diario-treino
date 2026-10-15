import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/features/sessao/stepper_metrica.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Monta o stepper sozinho dentro de um MaterialApp com o tema do app (os
/// widgets leem cores da AppColors, então o tema precisa estar presente).
Future<void> _montar(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.claro,
    home: Scaffold(body: Padding(
      padding: const EdgeInsets.all(16),
      child: child,
    )),
  ));
}

void main() {
  group('PassosMetrica', () {
    test('passo por código de métrica (TV-3)', () {
      expect(PassosMetrica.passo(MetricaCodigos.cargaKg), 2.5);
      expect(PassosMetrica.passo(MetricaCodigos.repeticoes), 1);
      expect(PassosMetrica.passo(MetricaCodigos.tempoSeg), 5);
      expect(PassosMetrica.passo(MetricaCodigos.zona), 1);
      expect(PassosMetrica.passo(MetricaCodigos.distanciaM), 100);
    });

    test('peso corporal não tem passo (sem stepper de intensidade)', () {
      expect(PassosMetrica.passo(MetricaCodigos.pesoCorporal), isNull);
    });

    test('zona é limitada de 1 a 5 (MER 3.4)', () {
      expect(PassosMetrica.faixa(MetricaCodigos.zona), (1.0, 5.0));
    });
  });

  testWidgets('+ soma o passo da carga (2,5) e reescreve o texto',
      (tester) async {
    final controlador = TextEditingController(text: '30');
    await _montar(
      tester,
      StepperMetrica(
        codigo: MetricaCodigos.cargaKg,
        controlador: controlador,
        rotulo: 'Carga',
      ),
    );

    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pump();
    expect(controlador.text, '32,5');

    await tester.tap(find.byIcon(LucideIcons.minus));
    await tester.pump();
    expect(controlador.text, '30');
  });

  testWidgets('− nunca passa de zero e zona não passa de 5', (tester) async {
    final zona = TextEditingController(text: '5');
    await _montar(
      tester,
      StepperMetrica(
        codigo: MetricaCodigos.zona,
        controlador: zona,
        rotulo: 'Zona',
      ),
    );

    // Já no teto: + mantém em 5.
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pump();
    expect(zona.text, '5');

    // Desce até o piso (1) e não passa dele.
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
    }
    expect(zona.text, '1');
  });
}
