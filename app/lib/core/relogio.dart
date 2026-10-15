import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fonte do "agora". O cronômetro do treino (TV-3) e o descanso (TV-5) calculam
/// o tempo por diferença de horário (`agora - início/fim`), nunca acumulando
/// ticks — o navegador segura timers com a aba em segundo plano. Isolar o
/// relógio aqui deixa esse cálculo testável sem esperar o tempo real passar.
abstract interface class Relogio {
  DateTime agora();
}

class RelogioDoSistema implements Relogio {
  const RelogioDoSistema();

  @override
  DateTime agora() => DateTime.now();
}

/// Relógio do app. Testes sobrepõem com um fake para controlar o tempo.
final relogioProvider = Provider<Relogio>((ref) => const RelogioDoSistema());
