import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/exercicio_resumo.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';
import 'treino_ao_vivo_controller.dart';
import 'widgets_ao_vivo.dart';

enum _AcaoSaidaVivo { finalizar, continuarDepois, descartar }

/// Tela 14 do protótipo: treino ao vivo (TV-3). Cabeçalho com cronômetro vivo e
/// contador de séries, um card por exercício (barra de progresso + status) e os
/// botões de finalizar e sair. Tocar num card abre a tela do exercício (TV-4).
class TreinoAoVivoScreen extends ConsumerWidget {
  const TreinoAoVivoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(treinoAoVivoControllerProvider);

    if (estado == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Treino')),
        body: const Center(child: Text('Nenhum treino em andamento.')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final sair = await _aoTentarSair(context, ref);
        if (sair && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(estado.treinoNome),
          actions: [
            TextButton(
              onPressed: () => _finalizar(context, ref),
              child: const Text('Finalizar'),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              _Cabecalho(inicio: estado.inicio,
                  feitas: estado.seriesFeitas, total: estado.totalSeries),
              const SizedBox(height: AppSpacing.x20),
              for (var i = 0; i < estado.exercicios.length; i++) ...[
                _CardExercicioVivo(
                  exercicio: estado.exercicios[i],
                  aoTocar: () => context.push(Rotas.exercicioAoVivo, extra: i),
                ),
                const SizedBox(height: AppSpacing.entreCards),
              ],
              const SizedBox(height: AppSpacing.x8),
              SizedBox(
                height: AppSizes.touchMin,
                child: OutlinedButton.icon(
                  onPressed: () => _adicionarForaDaFicha(context, ref),
                  icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                  label: const Text('Adicionar exercício fora da ficha'),
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
              SizedBox(
                height: AppSizes.botaoPrincipal,
                child: FilledButton(
                  onPressed: () => _finalizar(context, ref),
                  child: const Text('FINALIZAR TREINO'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Finalizar: avisa se há séries pendentes e, confirmado, abre o resumo (TV-6).
  Future<void> _finalizar(BuildContext context, WidgetRef ref) async {
    final estado = ref.read(treinoAoVivoControllerProvider);
    if (estado == null) return;

    final pendentes = estado.totalSeries - estado.seriesFeitas;
    final exComPendencia = estado.exercicios
        .where((e) => e.series.any((s) => !s.feita))
        .length;

    if (pendentes > 0) {
      final plural = pendentes == 1 ? 'série sem marcar' : 'séries sem marcar';
      final exPlural = exComPendencia == 1 ? 'exercício' : 'exercícios';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Finalizar treino?'),
          content: Text(
              'Ainda tem $pendentes $plural em $exComPendencia $exPlural. '
              'Elas ficam como não realizadas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar ao treino'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar mesmo assim'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (context.mounted) context.push(Rotas.resumoTreino);
  }

  /// Diálogo de sair (reusa a lógica do PBI-37): finalizar / continuar depois /
  /// descartar. Devolve true quando a saída pode prosseguir.
  Future<bool> _aoTentarSair(BuildContext context, WidgetRef ref) async {
    final acao = await showDialog<_AcaoSaidaVivo>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do treino?'),
        content: const Text(
            'O treino continua salvo no aparelho. Você escolhe o que fazer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoSaidaVivo.descartar),
            child: const Text('Descartar treino'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoSaidaVivo.continuarDepois),
            child: const Text('Continuar depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _AcaoSaidaVivo.finalizar),
            child: const Text('Finalizar agora'),
          ),
        ],
      ),
    );

    switch (acao) {
      case _AcaoSaidaVivo.finalizar:
        if (context.mounted) await _finalizar(context, ref);
        return false; // o resumo assume daqui.
      case _AcaoSaidaVivo.continuarDepois:
        return true; // rascunho já salvo pelo autosave.
      case _AcaoSaidaVivo.descartar:
        if (!context.mounted) return false;
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar treino?'),
            content: const Text('O que você fez neste treino será perdido.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (confirmar == true) {
          ref.read(treinoAoVivoControllerProvider.notifier).encerrar();
          return true;
        }
        return false;
      case null:
        return false;
    }
  }

  Future<void> _adicionarForaDaFicha(BuildContext context, WidgetRef ref) async {
    final escolhido = await Navigator.of(context).push<ExercicioResumo>(
      MaterialPageRoute(
        builder: (_) => const SelecionarExercicioScreen(retornarCompleto: true),
      ),
    );
    if (escolhido == null) return;

    // Só usa `ref` (não `context`) depois do await, então não há risco de
    // BuildContext atravessando gap assíncrono.
    final porCodigo = await ref.read(metricasPorCodigoProvider.future);
    ref.read(treinoAoVivoControllerProvider.notifier).adicionarExercicio(
          ExercicioEdicao.foraDaFichaDoCatalogo(escolhido, porCodigo),
        );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho(
      {required this.inicio, required this.feitas, required this.total});

  final DateTime inicio;
  final int feitas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final h = inicio.hour.toString().padLeft(2, '0');
    final m = inicio.minute.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TREINO EM ANDAMENTO',
            style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CronometroVivo(inicio: inicio, estilo: AppText.displayL),
            const Spacer(),
            Semantics(
              label: '$feitas de $total séries feitas',
              child: Text('$feitas/$total séries',
                  style: AppText.title.copyWith(color: cores.textSecondary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        Text('Começou às $h:$m',
            style: AppText.caption.copyWith(color: cores.textSecondary)),
      ],
    );
  }
}

/// Card de um exercício no treino em andamento: nome, barra de progresso por
/// série e status. Toca para abrir a tela do exercício (TV-4).
class _CardExercicioVivo extends StatelessWidget {
  const _CardExercicioVivo({required this.exercicio, required this.aoTocar});

  final ExercicioEdicao exercicio;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final total = exercicio.series.length;
    final feitas = exercicio.series.where((s) => s.feita).length;
    final status = _status(total, feitas);

    return Semantics(
      button: true,
      label: '${exercicio.nome}, $status',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: aoTocar,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.paddingCard),
            decoration: BoxDecoration(
              border: Border.all(color: cores.lineDefault),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(exercicio.nome,
                          style: AppText.title, overflow: TextOverflow.ellipsis),
                    ),
                    Icon(LucideIcons.chevronRight,
                        size: AppSizes.iconeSm, color: cores.iconMuted),
                  ],
                ),
                const SizedBox(height: AppSpacing.x8),
                BarraSeries(total: total, feitas: feitas),
                const SizedBox(height: AppSpacing.x8),
                Text(status,
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(int total, int feitas) {
    if (total == 0) return 'sem séries';
    if (feitas == 0) return '0/$total · ainda não começou';
    if (feitas == total) return 'Concluído';
    return '$feitas/$total séries concluídas';
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
