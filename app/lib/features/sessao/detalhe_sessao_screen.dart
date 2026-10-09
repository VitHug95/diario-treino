import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'registrar_sessao_screen.dart';
import 'sessao_models.dart';
import 'sessao_repository.dart';

/// Tela 11 do protótipo: ver uma sessão registrada, com atalhos para editar e
/// excluir (PBI-18).
class DetalheSessaoScreen extends ConsumerWidget {
  const DetalheSessaoScreen({
    super.key,
    required this.sessaoId,
    this.treinoNome,
  });

  final String sessaoId;
  final String? treinoNome;

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final detalhe = ref.read(sessaoDetalheProvider(sessaoId)).value;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistrarSessaoScreen(
          treinoId: detalhe?.treinoId ?? '',
          treinoNome: detalhe?.treinoNome ?? 'treino',
          sessaoId: sessaoId,
        ),
      ),
    );
    // Ao voltar da edição, recarrega para refletir as mudanças.
    ref.invalidate(sessaoDetalheProvider(sessaoId));
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: const Text(
            'Esta sessão sai do histórico e dos gráficos. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(sessaoRepositoryProvider).excluirSessao(sessaoId);
      if (context.mounted) context.go(Rotas.inicio);
    } on SessaoException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalhe = ref.watch(sessaoDetalheProvider(sessaoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino'),
        actions: [
          IconButton(
            onPressed: () => _editar(context, ref),
            icon: const Icon(LucideIcons.pencil, size: AppSizes.iconeSm),
            tooltip: 'Editar treino',
          ),
          IconButton(
            onPressed: () => _excluir(context, ref),
            icon: const Icon(LucideIcons.trash2, size: AppSizes.iconeSm),
            tooltip: 'Excluir treino',
          ),
          const SizedBox(width: AppSpacing.x8),
        ],
      ),
      body: detalhe.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Erro(aoTentar: () => ref.invalidate(sessaoDetalheProvider(sessaoId))),
        data: (dados) => _Conteudo(detalhe: dados),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.detalhe});
  final SessaoDetalhe detalhe;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final d = detalhe.data;
    final dataFmt =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        // Cabeçalho: ficha, data e duração.
        Text((detalhe.treinoNome ?? 'Treino livre').toUpperCase(),
            style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x4),
        Text(dataFmt, style: AppText.displayS),
        if (detalhe.duracaoMin != null) ...[
          const SizedBox(height: AppSpacing.x4),
          Row(
            children: [
              Icon(LucideIcons.clock, size: AppSizes.iconeSm, color: cores.iconMuted),
              const SizedBox(width: AppSpacing.x6),
              Text('${detalhe.duracaoMin} min',
                  style: AppText.body.copyWith(color: cores.textSecondary)),
            ],
          ),
        ],
        if (detalhe.observacao != null && detalhe.observacao!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x16),
          _BlocoObservacao(texto: detalhe.observacao!, cores: cores),
        ],
        const SizedBox(height: AppSpacing.x24),
        Text('EXERCÍCIOS',
            style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        for (final ex in detalhe.exercicios)
          _CardExercicio(exercicio: ex, cores: cores),
      ],
    );
  }
}

/// Bloco de observação do dia — tratamento de destaque (obsTint/obsLine).
class _BlocoObservacao extends StatelessWidget {
  const _BlocoObservacao({required this.texto, required this.cores});
  final String texto;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      decoration: BoxDecoration(
        color: cores.obsTint,
        border: Border.all(color: cores.obsLine),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OBSERVAÇÃO DO DIA',
              style: AppText.overline.copyWith(color: cores.obsTitle)),
          const SizedBox(height: AppSpacing.x6),
          Text(texto, style: AppText.body.copyWith(color: cores.obsBody)),
        ],
      ),
    );
  }
}

class _CardExercicio extends StatelessWidget {
  const _CardExercicio({required this.exercicio, required this.cores});
  final ExercicioSessaoDetalhe exercicio;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    final subtitulo = [
      if (exercicio.grupoMuscular != null && exercicio.grupoMuscular!.isNotEmpty)
        exercicio.grupoMuscular!,
      exercicio.modalidade,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.entreCards),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercicio.nome, style: AppText.title),
                    if (subtitulo.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x4),
                      Text(subtitulo,
                          style: AppText.caption.copyWith(color: cores.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (exercicio.foraDaFicha) _Chip(texto: 'Fora da ficha', cores: cores),
            ],
          ),
          if (exercicio.plano != null) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('Plano: ${exercicio.plano}',
                style: AppText.caption.copyWith(color: cores.primaryText)),
          ],
          const SizedBox(height: AppSpacing.x12),
          if (exercicio.naoRealizado)
            Row(
              children: [
                Icon(LucideIcons.minusCircle, size: AppSizes.iconeSm, color: cores.iconMuted),
                const SizedBox(width: AppSpacing.x6),
                Text('Não realizado',
                    style: AppText.bodyS.copyWith(color: cores.textSecondary)),
              ],
            )
          else
            for (final s in exercicio.series) _LinhaSerie(serie: s, cores: cores),
        ],
      ),
    );
  }
}

class _LinhaSerie extends StatelessWidget {
  const _LinhaSerie({required this.serie, required this.cores});
  final SerieDetalhe serie;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    // Monta "30 kg × 10" ou, no peso corporal, só o volume ("45 s").
    final vol = _fmt(serie.volume);
    final volComUnidade = '$vol ${serie.volumeMetricaNome}'.trimRight();
    final texto = serie.intensidadePorPesoCorporal
        ? volComUnidade
        : '${_fmt(serie.intensidade)} ${serie.intensidadeMetricaNome} × $volComUnidade';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${serie.rodada}',
                style: AppText.numeralS.copyWith(color: cores.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.x8),
          Expanded(child: Text(texto, style: AppText.body)),
          if (serie.descansoSeg != null)
            Text('${serie.descansoSeg}s',
                style: AppText.caption.copyWith(color: cores.textSecondary)),
        ],
      ),
    );
  }

  static String _fmt(double? v) {
    if (v == null) return '—';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().replaceAll('.', ',');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.cores});
  final String texto;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: cores.lineDefault),
      ),
      child: Text(texto, style: AppText.caption.copyWith(color: cores.textSecondary)),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.aoTentar});
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Não foi possível carregar o treino.', style: AppText.title),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
