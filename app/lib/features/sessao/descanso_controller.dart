import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/relogio.dart';

/// Estado de um descanso em andamento (TV-5). O tempo restante NÃO fica guardado
/// aqui tickando: guarda-se só o instante em que o descanso termina ([fim]) e a
/// duração total; o restante é sempre calculado por `fim - agora`. Assim o valor
/// fica certo mesmo com a aba em segundo plano (o navegador segura timers).
class DescansoEstado {
  const DescansoEstado({required this.fim, required this.total});

  /// Instante em que o descanso acaba.
  final DateTime fim;

  /// Duração total escolhida (para a barra de progresso e os ajustes +/-).
  final Duration total;

  /// Tempo que falta, dado o [agora]. Nunca negativo.
  Duration restante(DateTime agora) {
    final r = fim.difference(agora);
    return r.isNegative ? Duration.zero : r;
  }

  /// True quando o tempo já zerou.
  bool acabou(DateTime agora) => !agora.isBefore(fim);
}

/// Controla o descanso entre séries (TV-5). Um descanso só começa quando a
/// série traz um tempo informado (> 0): se a ficha não define descanso, o campo
/// fica nulo e nada dispara (decisão do PO). Os ajustes +/- mexem no [fim]
/// relativo ao agora, não acumulam ticks.
class DescansoController extends Notifier<DescansoEstado?> {
  @override
  DescansoEstado? build() => null;

  Relogio get _relogio => ref.read(relogioProvider);

  /// Passo dos botões +/- (15 segundos).
  static const passo = Duration(seconds: 15);

  /// Inicia um descanso de [segundos]. Nulo, zero ou negativo = não dispara
  /// (ex.: ficha sem tempo de descanso). Devolve true quando de fato começou.
  bool iniciar(int? segundos) {
    if (segundos == null || segundos <= 0) {
      // Sem descanso definido: garante que nada fique visível de um anterior.
      state = null;
      return false;
    }
    final total = Duration(seconds: segundos);
    state = DescansoEstado(fim: _relogio.agora().add(total), total: total);
    return true;
  }

  /// Soma 15s ao descanso (empurra o fim e aumenta o total mostrado).
  void adicionar() => _ajustar(passo);

  /// Tira 15s do descanso; se zerar, encerra. O total nunca fica negativo.
  void subtrair() => _ajustar(-passo);

  void _ajustar(Duration delta) {
    final atual = state;
    if (atual == null) return;
    final agora = _relogio.agora();
    final novoRestante = atual.restante(agora) + delta;
    if (novoRestante <= Duration.zero) {
      state = null;
      return;
    }
    final novoTotal = atual.total + delta;
    state = DescansoEstado(
      fim: agora.add(novoRestante),
      total: novoTotal < novoRestante ? novoRestante : novoTotal,
    );
  }

  /// Encerra o descanso (pular ou acabou o tempo).
  void encerrar() => state = null;
}

/// Descanso entre séries em andamento (TV-5). Nulo = sem descanso ativo.
final descansoControllerProvider =
    NotifierProvider<DescansoController, DescansoEstado?>(
  DescansoController.new,
);
