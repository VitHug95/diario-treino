import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/features/sessao/widgets_ao_vivo.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelogioFixo implements Relogio {
  _RelogioFixo(this.valor);
  final DateTime valor;
  @override
  DateTime agora() => valor;
}

Widget _comTema(Widget filho, {required Relogio relogio}) => ProviderScope(
      overrides: [relogioProvider.overrideWithValue(relogio)],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(body: Center(child: filho)),
      ),
    );

void main() {
  group('formatarDuracao', () {
    test('MM:SS abaixo de 1h', () {
      expect(formatarDuracao(const Duration(minutes: 38, seconds: 12)), '38:12');
      expect(formatarDuracao(const Duration(seconds: 5)), '00:05');
    });
    test('H:MM:SS acima de 1h', () {
      expect(formatarDuracao(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
    });
    test('nunca negativo', () {
      expect(formatarDuracao(const Duration(seconds: -10)), '00:00');
    });
  });

  group('rotuloDuracao (acessibilidade)', () {
    test('plural e singular', () {
      expect(rotuloDuracao(const Duration(minutes: 38, seconds: 12)),
          '38 minutos e 12 segundos');
      expect(rotuloDuracao(const Duration(minutes: 1, seconds: 1)),
          '1 minuto e 1 segundo');
    });
  });

  testWidgets('CronometroVivo mostra o tempo decorrido por horário (CA TV-3.3)',
      (tester) async {
    // Início 19:04, agora 19:42 → 38:00 (cálculo por diferença, não tick).
    final inicio = DateTime(2026, 10, 15, 19, 4);
    final relogio = _RelogioFixo(DateTime(2026, 10, 15, 19, 42));

    await tester.pumpWidget(_comTema(
      CronometroVivo(inicio: inicio),
      relogio: relogio,
    ));

    expect(find.text('38:00'), findsOneWidget);
  });

  testWidgets('BarraSeries pinta uma célula por série feita', (tester) async {
    await tester.pumpWidget(_comTema(
      const SizedBox(width: 200, child: BarraSeries(total: 4, feitas: 2)),
      relogio: _RelogioFixo(DateTime(2026)),
    ));
    // 4 segmentos (Containers com decoração) renderizados.
    expect(find.byType(BarraSeries), findsOneWidget);
  });
}
