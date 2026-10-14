import 'package:fl_chart/fl_chart.dart';
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
import 'progresso_models.dart';
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
      return const _CaixaGrafico(child: _MensagemGrafico(
        icone: LucideIcons.lineChart,
        texto: 'Selecione um exercício para ver sua evolução.',
      ));
    }

    final progressoAsync = ref.watch(progressoDoExercicioProvider);
    return progressoAsync.when(
      loading: () => const _CaixaGrafico(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _CaixaGrafico(
        child: _MensagemGrafico(
          icone: LucideIcons.cloudOff,
          texto: 'Não foi possível carregar o gráfico.',
          aoTentar: () => ref.invalidate(progressoDoExercicioProvider),
        ),
      ),
      data: (progresso) {
        if (progresso == null) {
          return const _CaixaGrafico(child: _MensagemGrafico(
            icone: LucideIcons.lineChart,
            texto: 'Selecione um exercício para ver sua evolução.',
          ));
        }
        if (!progresso.temGrafico || progresso.pontos.isEmpty) {
          return const _CaixaGrafico(child: _MensagemGrafico(
            icone: LucideIcons.calendarOff,
            texto: 'Sem dados no período para este exercício.',
          ));
        }
        return _GraficoComDados(progresso: progresso);
      },
    );
  }
}

/// Caixa com borda que contém o gráfico ou as mensagens de estado, com altura
/// fixa para a tela não "pular" entre estados.
class _CaixaGrafico extends StatelessWidget {
  const _CaixaGrafico({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: child,
    );
  }
}

class _MensagemGrafico extends StatelessWidget {
  const _MensagemGrafico({
    required this.icone,
    required this.texto,
    this.aoTentar,
  });

  final IconData icone;
  final String texto;
  final VoidCallback? aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 40, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text(texto,
              style: AppText.body.copyWith(color: cores.textSecondary),
              textAlign: TextAlign.center),
          if (aoTentar != null) ...[
            const SizedBox(height: AppSpacing.x16),
            FilledButton(
                onPressed: aoTentar, child: const Text('Tentar de novo')),
          ],
        ],
      ),
    );
  }
}

/// Resumo + LineChart quando há pontos. O título do eixo muda conforme a
/// métrica (CARGA → "Carga (kg)", TEMPO → "Tempo (s)").
class _GraficoComDados extends StatelessWidget {
  const _GraficoComDados({required this.progresso});
  final ProgressoExercicio progresso;

  bool get _ehCarga => progresso.metrica == 'CARGA';
  String get _unidade => _ehCarga ? 'kg' : 's';
  String get _tituloEixo => _ehCarga ? 'Carga (kg)' : 'Tempo (s)';

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final pontos = progresso.pontos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Resumo(progresso: progresso, unidade: _unidade, ehCarga: _ehCarga),
        const SizedBox(height: AppSpacing.x12),
        Text(_tituloEixo,
            style: AppText.caption.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        SizedBox(
          height: 220,
          child: LineChart(
            _dadosGrafico(context, pontos),
          ),
        ),
      ],
    );
  }

  LineChartData _dadosGrafico(
      BuildContext context, List<PontoProgresso> pontos) {
    final cores = AppColors.of(context);
    final valores = pontos.map((p) => p.valor).toList();
    final minY = valores.reduce((a, b) => a < b ? a : b);
    final maxY = valores.reduce((a, b) => a > b ? a : b);
    // Folga de 10% (mínimo 1) para a linha não encostar nas bordas.
    final folga = ((maxY - minY) * 0.1).clamp(1.0, double.infinity);
    final spots = <FlSpot>[
      for (var i = 0; i < pontos.length; i++)
        FlSpot(i.toDouble(), pontos[i].valor),
    ];

    return LineChartData(
      minX: 0,
      maxX: (pontos.length - 1).toDouble(),
      minY: minY - folga,
      maxY: maxY + folga,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: cores.lineDivider, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (valor, meta) {
              if (valor == meta.min || valor == meta.max) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(_numeroCurto(valor),
                    style: AppText.caption
                        .copyWith(color: cores.textSecondary)),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: _intervaloEixoX(pontos.length),
            getTitlesWidget: (valor, meta) {
              final i = valor.round();
              if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
              return SideTitleWidget(
                meta: meta,
                child: Text(_dataCurta(pontos[i].data),
                    style: AppText.caption
                        .copyWith(color: cores.textSecondary)),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: cores.chartLine,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4,
              color: cores.chartLine,
              strokeWidth: 2,
              strokeColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => cores.textStrong,
          getTooltipItems: (touchedSpots) => [
            for (final t in touchedSpots)
              LineTooltipItem(
                _textoTooltip(pontos[t.x.round()]),
                AppText.caption.copyWith(
                  color: Theme.of(context).colorScheme.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Texto do balão: data + valor; na força, mostra também as reps daquela
  /// carga (decisão do PO: "a maior carga, com quantas reps").
  String _textoTooltip(PontoProgresso p) {
    final valor = '${_numeroCurto(p.valor)} $_unidade';
    final data = _dataCurta(p.data);
    if (_ehCarga && p.repeticoes != null) {
      final reps = p.repeticoes!.round();
      return '$data\n$valor × $reps ${reps == 1 ? 'rep' : 'reps'}';
    }
    return '$data\n$valor';
  }

  static double? _intervaloEixoX(int n) {
    if (n <= 1) return 1;
    // No máximo ~5 rótulos no eixo para não embolar.
    final passos = (n / 5).ceil();
    return passos.toDouble();
  }

  /// "13/10".
  static String _dataCurta(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  /// Sem casa decimal quando é inteiro; senão, uma casa.
  static String _numeroCurto(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// Resumo do período: nº de sessões, variação do valor e quantas tiveram
/// observação.
class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.progresso,
    required this.unidade,
    required this.ehCarga,
  });

  final ProgressoExercicio progresso;
  final String unidade;
  final bool ehCarga;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final r = progresso.resumo;
    final itens = <String>[
      '${r.sessoes} ${r.sessoes == 1 ? 'sessão' : 'sessões'}',
      if (r.variacao != null) _textoVariacao(r.variacao!),
      if (r.sessoesComObservacao > 0)
        '${r.sessoesComObservacao} com obs.',
    ];

    return Semantics(
      label: 'Resumo do período: ${itens.join(', ')}',
      child: Text(itens.join(' · '),
          style: AppText.caption.copyWith(color: cores.textStrong)),
    );
  }

  String _textoVariacao(double v) {
    final sinal = v > 0 ? '+' : '';
    final n = v == v.roundToDouble()
        ? v.round().toString()
        : v.toStringAsFixed(1);
    return '$sinal$n $unidade no período';
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
