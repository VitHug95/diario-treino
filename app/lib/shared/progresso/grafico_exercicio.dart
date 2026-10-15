import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../features/progresso/progresso_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';

/// Caixa com borda e altura fixa que contém o gráfico ou mensagens de estado,
/// para a tela não "pular" entre estados. Reutilizada pela aba Progresso e pela
/// aba Evolução da tela do exercício (TV-4).
class CaixaGrafico extends StatelessWidget {
  const CaixaGrafico({super.key, required this.child});
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

/// Mensagem de estado dentro da [CaixaGrafico] (nada selecionado, erro, vazio).
class MensagemGrafico extends StatelessWidget {
  const MensagemGrafico({
    super.key,
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

/// Resumo + LineChart interativo da evolução de um exercício (PBI-20/21).
/// Extraído da aba Progresso para ser reutilizado na aba Evolução da tela do
/// exercício (TV-4). O título do eixo muda conforme a métrica (CARGA/TEMPO);
/// pontos de sessões com observação têm cor própria; tocar num ponto o
/// seleciona e mostra a nota do dia abaixo, com link para o detalhe.
class GraficoExercicio extends StatefulWidget {
  const GraficoExercicio({super.key, required this.progresso});
  final ProgressoExercicio progresso;

  @override
  State<GraficoExercicio> createState() => _GraficoExercicioState();
}

class _GraficoExercicioState extends State<GraficoExercicio> {
  late int _selecionado;

  bool get _ehCarga => widget.progresso.metrica == 'CARGA';
  String get _unidade => _ehCarga ? 'kg' : 's';
  String get _tituloEixo => _ehCarga ? 'Carga (kg)' : 'Tempo (s)';
  List<PontoProgresso> get _pontos => widget.progresso.pontos;

  @override
  void initState() {
    super.initState();
    _selecionado = _indiceInicial();
  }

  /// Última sessão com observação; se nenhuma tiver, o ponto mais recente.
  int _indiceInicial() {
    for (var i = _pontos.length - 1; i >= 0; i--) {
      if (_pontos[i].temObservacao) return i;
    }
    return _pontos.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temAlgumaObs = _pontos.any((p) => p.temObservacao);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Resumo(
            progresso: widget.progresso, unidade: _unidade, ehCarga: _ehCarga),
        const SizedBox(height: AppSpacing.x12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_tituloEixo,
                style: AppText.caption.copyWith(color: cores.textSecondary)),
            if (temAlgumaObs) _Legenda(cores: cores),
          ],
        ),
        const SizedBox(height: AppSpacing.x8),
        SizedBox(
          height: 220,
          child: LineChart(_dadosGrafico(context)),
        ),
        const SizedBox(height: AppSpacing.x12),
        _DetalhePonto(
          ponto: _pontos[_selecionado],
          unidade: _unidade,
          ehCarga: _ehCarga,
        ),
      ],
    );
  }

  LineChartData _dadosGrafico(BuildContext context) {
    final cores = AppColors.of(context);
    final pontos = _pontos;
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
            getDotPainter: (spot, _, __, indice) => _pintorPonto(
              context,
              indice: indice,
              comObs: pontos[indice].temObservacao,
              selecionado: indice == _selecionado,
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
        touchCallback: (evento, resposta) {
          if (!evento.isInterestedForInteractions) return;
          final spot = resposta?.lineBarSpots?.firstOrNull;
          if (spot == null) return;
          final i = spot.x.round();
          if (i >= 0 && i < pontos.length && i != _selecionado) {
            setState(() => _selecionado = i);
          }
        },
      ),
    );
  }

  FlDotCirclePainter _pintorPonto(
    BuildContext context, {
    required int indice,
    required bool comObs,
    required bool selecionado,
  }) {
    final cores = AppColors.of(context);
    final cor = comObs ? cores.obs : cores.chartLine;
    return FlDotCirclePainter(
      radius: selecionado ? 7 : 4,
      color: cor,
      strokeWidth: selecionado ? 3 : 2,
      strokeColor: Theme.of(context).colorScheme.surface,
    );
  }

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
    final passos = (n / 5).ceil();
    return passos.toDouble();
  }

  static String _dataCurta(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }

  static String _numeroCurto(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// Legenda do ponto com observação (bolinha laranja + texto).
class _Legenda extends StatelessWidget {
  const _Legenda({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pontos em destaque têm observação',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.x10,
            height: AppSpacing.x10,
            decoration: BoxDecoration(color: cores.obs, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x6),
          Text('com observação',
              style: AppText.caption.copyWith(color: cores.textSecondary)),
        ],
      ),
    );
  }
}

/// Cartão abaixo do gráfico com os dados do ponto selecionado: data, valor
/// (e reps na força) e a observação do dia — ou "Sem observação neste dia".
class _DetalhePonto extends StatelessWidget {
  const _DetalhePonto({
    required this.ponto,
    required this.unidade,
    required this.ehCarga,
  });

  final PontoProgresso ponto;
  final String unidade;
  final bool ehCarga;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temObs = ponto.temObservacao;

    final valorTxt = StringBuffer('${_numeroCurto(ponto.valor)} $unidade');
    if (ehCarga && ponto.repeticoes != null) {
      final reps = ponto.repeticoes!.round();
      valorTxt.write(' × $reps ${reps == 1 ? 'rep' : 'reps'}');
    }

    return Semantics(
      label: temObs
          ? 'Sessão de ${_dataLonga(ponto.data)}, $valorTxt. '
              'Observação: ${ponto.observacao}'
          : 'Sessão de ${_dataLonga(ponto.data)}, $valorTxt. '
              'Sem observação neste dia.',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: temObs ? cores.obsTint : Theme.of(context).colorScheme.surface,
          border: Border.all(color: temObs ? cores.obsLine : cores.lineDefault),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.all(AppSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_dataLonga(ponto.data),
                      style: AppText.titleS.copyWith(
                          color: temObs ? cores.obsTitle : cores.textStrong)),
                ),
                Text(valorTxt.toString(),
                    style: AppText.label.copyWith(color: cores.textStrong)),
              ],
            ),
            const SizedBox(height: AppSpacing.x8),
            Text(
              temObs ? ponto.observacao! : 'Sem observação neste dia.',
              style: AppText.body.copyWith(
                  color: temObs ? cores.obsBody : cores.textSecondary),
            ),
            const SizedBox(height: AppSpacing.x8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(
                  Rotas.detalheSessao,
                  extra: DetalheSessaoArgs(sessaoId: ponto.sessaoId),
                ),
                icon: const Icon(LucideIcons.externalLink,
                    size: AppSizes.iconeSm),
                label: const Text('Abrir sessão'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dataLonga(DateTime d) {
    const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    final dia = dias[d.weekday - 1];
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dia, $dd/$mm/${d.year}';
  }

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
      if (r.sessoesComObservacao > 0) '${r.sessoesComObservacao} com obs.',
    ];

    return Semantics(
      label: 'Resumo do período: ${itens.join(', ')}',
      child: Text(itens.join(' · '),
          style: AppText.caption.copyWith(color: cores.textStrong)),
    );
  }

  String _textoVariacao(double v) {
    final sinal = v > 0 ? '+' : '';
    final n =
        v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    return '$sinal$n $unidade no período';
  }
}
