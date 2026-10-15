import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'treino_ao_vivo_controller.dart';

/// Tela 14 do protótipo: treino ao vivo (TV-3). Cabeçalho com cronômetro e
/// contador, um card por exercício e os botões de finalizar/sair.
///
/// Conteúdo preenchido na Fatia 4. Por ora, observa o controller para a rota
/// existir e a navegação ser montada (Fatia 3).
class TreinoAoVivoScreen extends ConsumerWidget {
  const TreinoAoVivoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(treinoAoVivoControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(estado?.treinoNome ?? 'Treino')),
      body: Center(
        child: Text(estado == null
            ? 'Nenhum treino em andamento.'
            : '${estado.seriesFeitas}/${estado.totalSeries} séries feitas'),
      ),
    );
  }
}

/// Tela do exercício no treino ao vivo (TV-4), série por série. Conteúdo na
/// Fatia 6. Recebe o índice do exercício na lista do treino ao vivo.
class ExercicioAoVivoScreen extends ConsumerWidget {
  const ExercicioAoVivoScreen({super.key, required this.indice});

  final int indice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(treinoAoVivoControllerProvider);
    final exercicio = (estado != null && indice < estado.exercicios.length)
        ? estado.exercicios[indice]
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(exercicio?.nome ?? 'Exercício')),
      body: Center(child: Text(exercicio?.nome ?? 'Exercício não encontrado')),
    );
  }
}
