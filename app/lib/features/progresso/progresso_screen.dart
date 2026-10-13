import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../sessao/sessao_models.dart';
import '../sessao/sessao_repository.dart';

/// Tela 4 do protótipo (aba Progresso), parte PBI-22: lista das sessões do
/// período, mais recente primeiro. O gráfico de evolução (PBI-20/21) entra
/// depois, acima da lista.
class ProgressoScreen extends ConsumerWidget {
  const ProgressoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final periodo = ref.watch(periodoSessoesProvider);
    final sessoesAsync = ref.watch(sessoesDoPeriodoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progresso')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(sessoesDoPeriodoProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              Text('SESSÕES',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              _SeletorPeriodo(
                selecionado: periodo,
                aoSelecionar: (p) =>
                    ref.read(periodoSessoesProvider.notifier).definir(p),
              ),
              const SizedBox(height: AppSpacing.x16),
              sessoesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.x28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _Erro(
                  aoTentar: () => ref.invalidate(sessoesDoPeriodoProvider),
                ),
                data: (sessoes) => sessoes.isEmpty
                    ? const _Vazio()
                    : Column(
                        children: [
                          for (final s in sessoes) ...[
                            _CardSessao(sessao: s),
                            const SizedBox(height: AppSpacing.entreItens),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeletorPeriodo extends StatelessWidget {
  const _SeletorPeriodo({required this.selecionado, required this.aoSelecionar});

  final PeriodoSessoes selecionado;
  final ValueChanged<PeriodoSessoes> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in PeriodoSessoes.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x8),
            child: ChoiceChip(
              label: Text(p.rotulo),
              selected: p == selecionado,
              showCheckmark: false,
              onSelected: (_) => aoSelecionar(p),
            ),
          ),
      ],
    );
  }
}

/// Item da lista: data, ficha (ou "Treino livre"), nº de exercícios, duração e
/// selo "Obs." quando há observação. Toca abre o detalhe (PBI-18).
class _CardSessao extends StatelessWidget {
  const _CardSessao({required this.sessao});

  final SessaoResumo sessao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final titulo = sessao.treinoNome ?? 'Treino livre';

    final detalhes = <String>[
      '${sessao.quantidadeExercicios} '
          '${sessao.quantidadeExercicios == 1 ? 'exercício' : 'exercícios'}',
      if (sessao.duracaoMin != null) '${sessao.duracaoMin} min',
    ].join(' · ');

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.push(
          Rotas.detalheSessao,
          extra: DetalheSessaoArgs(
              sessaoId: sessao.id, treinoNome: sessao.treinoNome),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_dataLonga(sessao.data), style: AppText.title),
                        if (sessao.temObservacao) ...[
                          const SizedBox(width: AppSpacing.x8),
                          _SeloObs(cores: cores),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    Text(titulo,
                        style: AppText.body.copyWith(color: cores.textStrong)),
                    const SizedBox(height: AppSpacing.x4),
                    Text(detalhes,
                        style: AppText.caption.copyWith(color: cores.textSecondary)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  color: cores.iconMuted, size: AppSizes.iconeMd),
            ],
          ),
        ),
      ),
    );
  }

  /// "ter, 13/10/2026".
  static String _dataLonga(DateTime d) {
    const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    final dia = dias[d.weekday - 1];
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dia, $dd/$mm/${d.year}';
  }
}

class _SeloObs extends StatelessWidget {
  const _SeloObs({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tem observação',
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
        decoration: BoxDecoration(
          color: cores.obsTint,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: cores.obsLine),
        ),
        child: Text('Obs.',
            style: AppText.caption.copyWith(color: cores.obsTitle)),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x28),
      child: Column(
        children: [
          Icon(LucideIcons.calendarOff, size: 48, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Nenhum treino neste período',
              style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x8),
          Text('Registre um treino para começar a acompanhar sua evolução.',
              style: AppText.body.copyWith(color: cores.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.aoTentar});
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x24),
      child: Column(
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Não foi possível carregar as sessões.',
              style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
