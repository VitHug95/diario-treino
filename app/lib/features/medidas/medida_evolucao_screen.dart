import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable, ProviderOrFamily;
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../shared/progresso/grafico_exercicio.dart'
    show CaixaGrafico, MensagemGrafico;
import '../educador/corpo_do_aluno.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'medidas_formato.dart';
import 'medidas_models.dart';
import 'medidas_repository.dart';

/// Evolução de uma medida (E12 / PBI-94, tela 26): filtros de período, gráfico
/// de linha, primeira/última/variação e a lista dos registros em texto. Serve a
/// qualquer tipo, inclusive o peso (em kg). O eixo vertical NÃO começa do zero:
/// usa a faixa dos dados com folga, senão uma queda de 3 cm viraria uma linha
/// reta. Só leitura: para corrigir um valor, edite o dia nas medidas.
///
/// Reaproveita a [CaixaGrafico] e a [MensagemGrafico] do gráfico de exercício
/// (caixa de altura fixa para a tela não pular entre estados). O gráfico em si é
/// próprio: o do exercício é por sessão e tem observação, este é por dia.
class MedidaEvolucaoScreen extends ConsumerStatefulWidget {
  const MedidaEvolucaoScreen({
    super.key,
    required this.tipo,
    this.atletaId,
    this.alunoNome,
  });

  final TipoMedida tipo;

  /// Educador vendo a medida do aluno (PBI-96): mesma tela, só leitura, pela
  /// rota do aluno. Nulo = as medidas do próprio usuário.
  final String? atletaId;
  final String? alunoNome;

  @override
  ConsumerState<MedidaEvolucaoScreen> createState() =>
      _MedidaEvolucaoScreenState();
}

class _MedidaEvolucaoScreenState extends ConsumerState<MedidaEvolucaoScreen> {
  PeriodoMedida _periodo = PeriodoMedida.dias90;

  /// Ponto tocado no gráfico (índice em `pontos`). Nulo = o mais recente.
  int? _selecionado;

  @override
  Widget build(BuildContext context) {
    final atletaId = widget.atletaId;
    final ProviderListenable<AsyncValue<EvolucaoMedida>> fonte = atletaId == null
        ? evolucaoMedidaProvider((tipo: widget.tipo, periodo: _periodo))
        : evolucaoMedidaDoAlunoProvider(
            (atletaId: atletaId, tipo: widget.tipo, periodo: _periodo));
    final ProviderOrFamily leitura = atletaId == null
        ? evolucaoMedidaProvider((tipo: widget.tipo, periodo: _periodo))
        : evolucaoMedidaDoAlunoProvider(
            (atletaId: atletaId, tipo: widget.tipo, periodo: _periodo));
    final evolucao = ref.watch(fonte);
    final titulo = widget.alunoNome == null
        ? widget.tipo.rotulo
        : '${widget.tipo.rotulo} · ${widget.alunoNome}';

    return Scaffold(
      appBar: AppBar(title: Text(titulo, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          children: [
            _SeletorPeriodo(
              selecionado: _periodo,
              aoSelecionar:
                  (p) => setState(() {
                    _periodo = p;
                    _selecionado = null;
                  }),
            ),
            const SizedBox(height: AppSpacing.x16),
            evolucao.when(
              // Ao salvar uma medida o gráfico é buscado de novo; segue na tela.
              skipLoadingOnReload: true,
              loading:
                  () => const CaixaGrafico(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (erro, __) => CaixaGrafico(
                    // O aluno trancou as medidas no meio do caminho (403).
                    child: erro is CorpoTrancadoException
                        ? const MensagemGrafico(
                            icone: LucideIcons.lock,
                            texto: 'O aluno não compartilhou as medidas.',
                          )
                        : MensagemGrafico(
                            icone: LucideIcons.cloudOff,
                            texto: 'Não foi possível carregar a evolução.',
                            aoTentar: () => tentarDeNovo(ref, [leitura]),
                          ),
                  ),
              data: (dados) {
                if (dados.vazia) {
                  return const CaixaGrafico(
                    child: MensagemGrafico(
                      icone: LucideIcons.lineChart,
                      texto: 'Sem registros neste período',
                    ),
                  );
                }
                final indice = (_selecionado ?? dados.pontos.length - 1).clamp(
                  0,
                  dados.pontos.length - 1,
                );
                return _Conteudo(
                  evolucao: dados,
                  selecionado: indice,
                  aoSelecionar: (i) {
                    if (i != indice) setState(() => _selecionado = i);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SeletorPeriodo extends StatelessWidget {
  const _SeletorPeriodo({
    required this.selecionado,
    required this.aoSelecionar,
  });

  final PeriodoMedida selecionado;
  final ValueChanged<PeriodoMedida> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    // Wrap: com fonte grande os quatro filtros descem para a linha de baixo.
    return Wrap(
      spacing: AppSpacing.x8,
      runSpacing: AppSpacing.x8,
      children: [
        for (final p in PeriodoMedida.values)
          ChoiceChip(
            label: Text(p.rotulo),
            selected: p == selecionado,
            showCheckmark: false,
            onSelected: (_) => aoSelecionar(p),
          ),
      ],
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.evolucao,
    required this.selecionado,
    required this.aoSelecionar,
  });

  final EvolucaoMedida evolucao;
  final int selecionado;
  final ValueChanged<int> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final tipo = evolucao.tipo;
    final pontos = evolucao.pontos;
    final escolhido = pontos[selecionado];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Cartoes(evolucao: evolucao),
        const SizedBox(height: AppSpacing.x16),
        // Resumo falado do gráfico inteiro (início, fim, variação); a lista logo
        // abaixo é a alternativa em texto de cada ponto.
        Semantics(
          container: true,
          label: _resumoFalado(evolucao),
          child: ExcludeSemantics(
            child: CaixaGrafico(
              child: LineChart(
                _dados(context, evolucao, selecionado, aoSelecionar),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Semantics(
          liveRegion: true,
          container: true,
          label:
              'Ponto selecionado: ${dataCompleta(escolhido.data)}, '
              '${falarValor(escolhido.valor, tipo)}',
          excludeSemantics: true,
          child: Text(
            '${dataCompleta(escolhido.data)} · ${formatarComUnidade(escolhido.valor, tipo)}',
            style: AppText.label.copyWith(color: cores.textStrong),
          ),
        ),
        const SizedBox(height: AppSpacing.x24),
        Text(
          'REGISTROS DO PERÍODO',
          style: AppText.overline.copyWith(color: cores.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x8),
        _ListaRegistros(evolucao: evolucao),
      ],
    );
  }

  /// "Cintura de 87,0 centímetros em 10/08 para 84,0 centímetros em 05/11,
  /// queda de 3,0 centímetros".
  static String _resumoFalado(EvolucaoMedida e) {
    final tipo = e.tipo;
    final primeira = e.primeira!;
    final ultima = e.ultima!;
    if (e.pontos.length == 1) {
      return '${tipo.rotulo}: ${falarValor(ultima.valor, tipo)} em '
          '${dataCurta(ultima.data)}, um registro no período';
    }
    return '${tipo.rotulo} de ${falarValor(primeira.valor, tipo)} em '
        '${dataCurta(primeira.data)} para ${falarValor(ultima.valor, tipo)} em '
        '${dataCurta(ultima.data)}, ${falarTendencia(e.variacao ?? 0, tipo)}';
  }

  static int _dias(DateTime a, DateTime base) =>
      DateTime.utc(
        a.year,
        a.month,
        a.day,
      ).difference(DateTime.utc(base.year, base.month, base.day)).inDays;

  static String _numeroCurto(double v) =>
      v == v.roundToDouble() ? v.round().toString() : formatarValor(v);

  static LineChartData _dados(
    BuildContext context,
    EvolucaoMedida e,
    int selecionado,
    ValueChanged<int> aoSelecionar,
  ) {
    final cores = AppColors.of(context);
    final tipo = e.tipo;
    final pontos = e.pontos;
    final base = pontos.first.data;
    final totalDias = _dias(pontos.last.data, base);
    final umSo = pontos.length == 1;

    final valores = pontos.map((p) => p.valor);
    final menor = valores.reduce((a, b) => a < b ? a : b);
    final maior = valores.reduce((a, b) => a > b ? a : b);
    // Folga de 15% (mínimo 1) em volta dos dados: o eixo NÃO parte do zero.
    final folga = ((maior - menor) * 0.15).clamp(1.0, double.infinity);

    final spots = [
      for (final p in pontos) FlSpot(_dias(p.data, base).toDouble(), p.valor),
    ];

    return LineChartData(
      minX: umSo ? -1 : 0,
      maxX: umSo ? 1 : totalDias.toDouble(),
      minY: menor - folga,
      maxY: maior + folga,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine:
            (_) => FlLine(color: cores.lineDivider, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (valor, meta) {
              if (valor == meta.min || valor == meta.max) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  _numeroCurto(valor),
                  style: AppText.caption.copyWith(color: cores.textSecondary),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval:
                umSo
                    ? 1
                    : (totalDias / 3).ceilToDouble().clamp(1, double.infinity),
            getTitlesWidget: (valor, meta) {
              // Com um ponto só, rotula apenas o dia dele.
              if (umSo && valor != 0) return const SizedBox.shrink();
              final data = DateTime(
                base.year,
                base.month,
                base.day + valor.round(),
              );
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  dataCurta(data),
                  style: AppText.caption.copyWith(color: cores.textSecondary),
                ),
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
          // Com um ponto só, o ponto aparece e a linha não existe.
          dotData: FlDotData(
            show: true,
            getDotPainter:
                (spot, _, __, indice) => FlDotCirclePainter(
                  radius: indice == selecionado ? 7 : 4,
                  color: cores.chartLine,
                  strokeWidth: indice == selecionado ? 3 : 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        // 22 px de raio = alvo de 44 px por ponto.
        touchSpotThreshold: 22,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => cores.textStrong,
          getTooltipItems:
              (tocados) => [
                for (final t in tocados)
                  LineTooltipItem(
                    '${dataCurta(pontos[t.spotIndex].data)}\n'
                    '${formatarComUnidade(pontos[t.spotIndex].valor, tipo)}',
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
          if (spot != null) aoSelecionar(spot.spotIndex);
        },
      ),
    );
  }
}

/// Primeira, última e variação do período. A variação leva seta e sinal: a
/// direção nunca depende só de cor.
class _Cartoes extends StatelessWidget {
  const _Cartoes({required this.evolucao});

  final EvolucaoMedida evolucao;

  @override
  Widget build(BuildContext context) {
    final tipo = evolucao.tipo;
    final primeira = evolucao.primeira!;
    final ultima = evolucao.ultima!;
    final variacao = evolucao.variacao;

    final String variacaoTexto;
    final String variacaoFalada;
    IconData? icone;
    if (variacao == null) {
      variacaoTexto = '—';
      variacaoFalada = 'Variação: precisa de dois registros';
    } else {
      variacaoTexto = formatarVariacao(variacao, tipo);
      variacaoFalada = 'Variação: ${falarTendencia(variacao, tipo)}';
      icone =
          variacao.abs() < 0.05
              ? LucideIcons.minus
              : (variacao < 0
                  ? LucideIcons.trendingDown
                  : LucideIcons.trendingUp);
    }

    // IntrinsicHeight: os três cartões ficam da mesma altura numa lista rolável.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Cartao(
              titulo: 'Primeira',
              valor: formatarComUnidade(primeira.valor, tipo),
              detalhe: dataCurta(primeira.data),
              rotuloFalado:
                  'Primeira: ${falarValor(primeira.valor, tipo)} em ${dataCurta(primeira.data)}',
            ),
          ),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: _Cartao(
              titulo: 'Última',
              valor: formatarComUnidade(ultima.valor, tipo),
              detalhe: dataCurta(ultima.data),
              rotuloFalado:
                  'Última: ${falarValor(ultima.valor, tipo)} em ${dataCurta(ultima.data)}',
            ),
          ),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: _Cartao(
              titulo: 'Variação',
              valor: variacaoTexto,
              icone: icone,
              detalhe: variacao == null ? '1 registro' : 'no período',
              rotuloFalado: variacaoFalada,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({
    required this.titulo,
    required this.valor,
    required this.detalhe,
    required this.rotuloFalado,
    this.icone,
  });

  final String titulo;
  final String valor;
  final String detalhe;
  final String rotuloFalado;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      container: true,
      label: rotuloFalado,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: cores.lineDefault),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo.toUpperCase(),
              style: AppText.overline.copyWith(color: cores.textSecondary),
            ),
            const SizedBox(height: AppSpacing.x4),
            // scaleDown: com fonte grande o valor encolhe em vez de estourar.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icone != null) ...[
                    Icon(
                      icone,
                      size: AppSizes.iconeSm,
                      color: cores.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x4),
                  ],
                  Text(valor, style: AppText.title),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              detalhe,
              style: AppText.caption.copyWith(color: cores.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Os registros do período em texto, do mais recente ao mais antigo: a
/// alternativa ao gráfico para quem usa leitor de tela.
class _ListaRegistros extends StatelessWidget {
  const _ListaRegistros({required this.evolucao});

  final EvolucaoMedida evolucao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final tipo = evolucao.tipo;
    final recentes = evolucao.pontos.reversed.toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingCard,
        vertical: AppSpacing.x4,
      ),
      child: Column(
        children: [
          for (var i = 0; i < recentes.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cores.lineDivider),
            Semantics(
              container: true,
              label:
                  '${dataCompleta(recentes[i].data)}: '
                  '${falarValor(recentes[i].valor, tipo)}',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dataCompleta(recentes[i].data),
                        style: AppText.body,
                      ),
                    ),
                    Text(
                      formatarComUnidade(recentes[i].valor, tipo),
                      style: AppText.title,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
