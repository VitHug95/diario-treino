import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../shared/progresso/grafico_exercicio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../sessao/sessao_models.dart';
import '../sessao/sessao_repository.dart';
import 'progresso_repository.dart';

/// Tela 4 do protótipo (aba Progresso). Em cima, o gráfico de evolução por
/// exercício (PBI-20): seletor de exercício + linha da maior carga (ou maior
/// tempo, em isometria) por sessão. Embaixo, a lista das sessões do período
/// (PBI-22). O filtro de período é compartilhado pelos dois.
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
          onRefresh: () async {
            ref.invalidate(sessoesDoPeriodoProvider);
            ref.invalidate(exerciciosComHistoricoProvider);
            ref.invalidate(progressoDoExercicioProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              Text('EVOLUÇÃO',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              const _SeletorExercicio(),
              const SizedBox(height: AppSpacing.x16),
              const _GraficoEvolucao(),
              const SizedBox(height: AppSpacing.x28),
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

/// Dropdown dos exercícios que o atleta já treinou (PBI-20). Enquanto carrega,
/// mostra um placeholder; se não houver histórico, uma dica curta.
class _SeletorExercicio extends ConsumerWidget {
  const _SeletorExercicio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final exerciciosAsync = ref.watch(exerciciosComHistoricoProvider);
    final selecionado = ref.watch(exercicioSelecionadoProvider);

    return exerciciosAsync.when(
      loading: () => const _CampoSeletorVazio(texto: 'Carregando exercícios…'),
      error: (_, __) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        onTap: () => ref.invalidate(exerciciosComHistoricoProvider),
        child: const _CampoSeletorVazio(
            texto: 'Erro ao carregar. Toque para tentar de novo.'),
      ),
      data: (exercicios) {
        if (exercicios.isEmpty) {
          return const _CampoSeletorVazio(
              texto: 'Nenhum exercício com histórico ainda.');
        }
        // Garante que o valor selecionado ainda existe na lista atual.
        final valorValido =
            exercicios.any((e) => e.id == selecionado) ? selecionado : null;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.campoForm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
          child: Semantics(
            label: 'Exercício do gráfico',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: valorValido,
                hint: Text('Selecione um exercício',
                    style:
                        AppText.body.copyWith(color: cores.textSecondary)),
                icon: Icon(LucideIcons.chevronDown,
                    color: cores.iconMuted, size: AppSizes.iconeMd),
                borderRadius: BorderRadius.circular(AppRadius.campoForm),
                items: [
                  for (final e in exercicios)
                    DropdownMenuItem<String>(
                      value: e.id,
                      child: Text(e.nome,
                          style: AppText.body.copyWith(color: cores.textStrong),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => ref
                    .read(exercicioSelecionadoProvider.notifier)
                    .selecionar(id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CampoSeletorVazio extends StatelessWidget {
  const _CampoSeletorVazio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      height: AppSizes.campoForm,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
      child: Text(texto,
          style: AppText.body.copyWith(color: cores.textSecondary)),
    );
  }
}

/// Área do gráfico: reage ao exercício selecionado e ao período. Estados:
/// nada selecionado, carregando, erro, sem dados e, por fim, o gráfico.
class _GraficoEvolucao extends ConsumerWidget {
  const _GraficoEvolucao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecionado = ref.watch(exercicioSelecionadoProvider);
    if (selecionado == null) {
      return const CaixaGrafico(child: MensagemGrafico(
        icone: LucideIcons.lineChart,
        texto: 'Selecione um exercício para ver sua evolução.',
      ));
    }

    final progressoAsync = ref.watch(progressoDoExercicioProvider);
    return progressoAsync.when(
      loading: () => const CaixaGrafico(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => CaixaGrafico(
        child: MensagemGrafico(
          icone: LucideIcons.cloudOff,
          texto: 'Não foi possível carregar o gráfico.',
          aoTentar: () => ref.invalidate(progressoDoExercicioProvider),
        ),
      ),
      data: (progresso) {
        if (progresso == null) {
          return const CaixaGrafico(child: MensagemGrafico(
            icone: LucideIcons.lineChart,
            texto: 'Selecione um exercício para ver sua evolução.',
          ));
        }
        if (!progresso.temGrafico || progresso.pontos.isEmpty) {
          return const CaixaGrafico(child: MensagemGrafico(
            icone: LucideIcons.calendarOff,
            texto: 'Sem dados no período para este exercício.',
          ));
        }
        // key por exercício+período: reinicia o ponto selecionado ao trocar.
        return GraficoExercicio(
          key: ValueKey('${progresso.exercicioId}-${progresso.pontos.length}'),
          progresso: progresso,
        );
      },
    );
  }
}

/// Caixa com borda que contém o gráfico ou as mensagens de estado, com altura
// O gráfico de evolução foi extraído para shared/progresso/grafico_exercicio.dart
// (TV-4): CaixaGrafico, MensagemGrafico e GraficoExercicio, reusados aqui e na
// aba Evolução da tela do exercício.

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
