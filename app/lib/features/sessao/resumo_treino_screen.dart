import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'treino_ao_vivo_controller.dart';

/// Tela 16 do protótipo: resumo do treino antes de salvar (TV-6). Conteúdo
/// preenchido na Fatia 8. Por ora, observa o controller para a rota existir.
class ResumoTreinoScreen extends ConsumerWidget {
  const ResumoTreinoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(treinoAoVivoControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do treino')),
      body: Center(
        child: Text(estado == null
            ? 'Nenhum treino em andamento.'
            : '${estado.seriesFeitas}/${estado.totalSeries} séries feitas'),
      ),
    );
  }
}
