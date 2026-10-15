import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/features/sessao/descanso_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relógio controlável: o teste avança o "agora" à mão para medir o restante
/// sem esperar o tempo real.
class _RelogioFake implements Relogio {
  _RelogioFake(this._agora);
  DateTime _agora;
  void avancar(Duration d) => _agora = _agora.add(d);
  @override
  DateTime agora() => _agora;
}

ProviderContainer _container(_RelogioFake relogio) => ProviderContainer(
      overrides: [relogioProvider.overrideWithValue(relogio)],
    );

void main() {
  test('não dispara quando a ficha não informa descanso (nulo) — decisão do PO',
      () {
    final relogio = _RelogioFake(DateTime(2026, 10, 15, 19, 0));
    final c = _container(relogio);
    final ctrl = c.read(descansoControllerProvider.notifier);

    expect(ctrl.iniciar(null), isFalse);
    expect(c.read(descansoControllerProvider), isNull);

    // Zero ou negativo também não dispara.
    expect(ctrl.iniciar(0), isFalse);
    expect(c.read(descansoControllerProvider), isNull);
  });

  test('dispara com tempo informado e o restante cai conforme o relógio anda',
      () {
    final relogio = _RelogioFake(DateTime(2026, 10, 15, 19, 0));
    final c = _container(relogio);
    final ctrl = c.read(descansoControllerProvider.notifier);

    expect(ctrl.iniciar(90), isTrue);
    final estado = c.read(descansoControllerProvider)!;
    expect(estado.restante(relogio.agora()), const Duration(seconds: 90));

    relogio.avancar(const Duration(seconds: 30));
    expect(estado.restante(relogio.agora()), const Duration(seconds: 60));

    // Passou do fim: restante nunca negativo e "acabou" vira true.
    relogio.avancar(const Duration(seconds: 120));
    expect(estado.restante(relogio.agora()), Duration.zero);
    expect(estado.acabou(relogio.agora()), isTrue);
  });

  test('+15s e −15s ajustam o restante pelo passo', () {
    final relogio = _RelogioFake(DateTime(2026, 10, 15, 19, 0));
    final c = _container(relogio);
    final ctrl = c.read(descansoControllerProvider.notifier);

    ctrl.iniciar(60);
    ctrl.adicionar();
    expect(c.read(descansoControllerProvider)!.restante(relogio.agora()),
        const Duration(seconds: 75));

    ctrl.subtrair();
    ctrl.subtrair();
    expect(c.read(descansoControllerProvider)!.restante(relogio.agora()),
        const Duration(seconds: 45));
  });

  test('−15s abaixo de zero encerra o descanso', () {
    final relogio = _RelogioFake(DateTime(2026, 10, 15, 19, 0));
    final c = _container(relogio);
    final ctrl = c.read(descansoControllerProvider.notifier);

    ctrl.iniciar(10); // menos que o passo de 15s
    ctrl.subtrair();
    expect(c.read(descansoControllerProvider), isNull);
  });

  test('encerrar (pular) zera o estado', () {
    final relogio = _RelogioFake(DateTime(2026, 10, 15, 19, 0));
    final c = _container(relogio);
    final ctrl = c.read(descansoControllerProvider.notifier);

    ctrl.iniciar(60);
    expect(c.read(descansoControllerProvider), isNotNull);
    ctrl.encerrar();
    expect(c.read(descansoControllerProvider), isNull);
  });
}
