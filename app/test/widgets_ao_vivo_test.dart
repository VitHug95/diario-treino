import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/features/sessao/descanso_controller.dart';
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

/// Relógio que anda quando o teste manda (para o descanso passar de zero).
class _RelogioMutavel implements Relogio {
  _RelogioMutavel(this.valor);
  DateTime valor;
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

  group('formatarSaldo (PBI-90)', () {
    test('positivo igual à duração; negativo ganha o sinal de menos', () {
      expect(formatarSaldo(const Duration(seconds: 34)), '00:34');
      expect(formatarSaldo(const Duration(seconds: -5)), '−00:05');
      expect(formatarSaldo(const Duration(minutes: -1, seconds: -2)), '−01:02');
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

  testWidgets(
      'PBI-90: o descanso não some ao zerar; conta negativo, avisa e "Voltar ao treino" encerra',
      (tester) async {
    final relogio = _RelogioMutavel(DateTime(2026, 10, 15, 19, 0));
    await tester.pumpWidget(_comTema(const BarraDescanso(), relogio: relogio));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(BarraDescanso)));

    // Descanso de 30s: contando, com os dois ajustes e "Pular".
    container.read(descansoControllerProvider.notifier).iniciar(30);
    await tester.pump();
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('Descanso'), findsOneWidget);
    expect(find.text('−15s'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);

    // 35s depois: passou 5s do tempo. Continua na tela, negativo, com o aviso.
    relogio.valor = DateTime(2026, 10, 15, 19, 0, 35);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(descansoControllerProvider), isNotNull);
    expect(find.text('−00:05'), findsOneWidget);
    expect(find.text('Descanso acabou, volte ao treino'), findsOneWidget);
    // Tirar 15s não faz sentido depois de zerar; "Pular" vira "Voltar ao treino".
    expect(find.text('−15s'), findsNothing);
    expect(find.text('Pular'), findsNothing);
    expect(find.text('+15s'), findsOneWidget);

    // Ele segue contando enquanto o atleta não age.
    relogio.valor = DateTime(2026, 10, 15, 19, 1, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('−00:30'), findsOneWidget);

    // "Voltar ao treino" encerra o descanso.
    await tester.tap(find.text('Voltar ao treino'));
    await tester.pump();
    expect(container.read(descansoControllerProvider), isNull);
    expect(find.text('Descanso acabou, volte ao treino'), findsNothing);
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
