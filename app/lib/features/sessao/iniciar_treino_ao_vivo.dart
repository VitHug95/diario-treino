import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/rotas/app_router.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';
import 'treino_ao_vivo_controller.dart';
import 'treino_em_andamento.dart';

/// Pontes que ligam a flag `treinoAoVivoHabilitado` às telas existentes: abrem o
/// treino ao vivo (tela 14, TV-3) em vez do formulário de registro. Ficam aqui
/// (e não nas telas) para o fichas_screen e o inicio_screen compartilharem a
/// mesma montagem do estado vivo.

/// Inicia um treino ao vivo a partir de uma ficha. Se já houver um treino em
/// andamento desta mesma ficha salvo no aparelho, retoma de onde parou; senão
/// carrega o rascunho pré-preenchido (PBI-15) e começa do zero. Mostra um
/// indicador enquanto carrega e navega para a tela 14.
Future<void> iniciarTreinoAoVivoDaFicha(
  BuildContext context,
  WidgetRef ref, {
  required String treinoId,
  required String treinoNome,
}) async {
  final controller = ref.read(treinoAoVivoControllerProvider.notifier);

  // Já existe um treino em andamento desta ficha? Retoma sem recarregar.
  final emAndamento = ref.read(treinoEmAndamentoProvider);
  if (emAndamento != null && emAndamento.treinoId == treinoId) {
    controller.retomarDoRascunho();
    if (context.mounted) context.push(Rotas.treinoAoVivo);
    return;
  }

  // Carrega o rascunho pré-preenchido da ficha. Barra de progresso enquanto vai.
  // showDialog usa o navigator RAIZ por padrão; pegar o mesmo aqui. Com o
  // Navigator.of(context) simples, dentro da casca de abas, o pop() atingia
  // o navigator da aba (e não o diálogo) e o indicador ficava preso.
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final rascunho =
        await ref.read(sessaoRepositoryProvider).obterRascunho(treinoId);
    navigator.pop(); // fecha o indicador

    controller.iniciar(
      treinoId: treinoId,
      treinoNome: treinoNome,
      treinoLivre: false,
      data: rascunho.data,
      exercicios:
          rascunho.exercicios.map(ExercicioEdicao.doRascunho).toList(),
    );
    if (context.mounted) context.push(Rotas.treinoAoVivo);
  } on SessaoException catch (e) {
    navigator.pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }
}

/// Retoma um treino ao vivo em andamento salvo no aparelho (card "Continuar
/// treino" da tela inicial) e abre a tela 14. Devolve false quando não havia
/// rascunho para retomar (o chamador cai no comportamento antigo).
bool retomarTreinoAoVivo(BuildContext context, WidgetRef ref) {
  final retomou = ref.read(treinoAoVivoControllerProvider.notifier).retomarDoRascunho();
  if (retomou && context.mounted) {
    context.push(Rotas.treinoAoVivo);
  }
  return retomou;
}
