import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'bloco_ao_vivo.dart';
import 'descanso_controller.dart';
import 'sessao_edicao.dart';
import 'stepper_metrica.dart';
import 'treino_ao_vivo_controller.dart';
import 'widgets_ao_vivo.dart';

/// Abre o grupo [posicao] da tela 14 (PBI-102): o exercício avulso na tela do
/// exercício, o bloco na tela do bloco. [substituir] troca a rota atual (setas
/// e "Concluir"); senão empilha (toque na lista).
void abrirGrupoAoVivo(
  BuildContext context,
  List<GrupoAoVivo> grupos,
  int posicao, {
  bool substituir = false,
}) {
  final grupo = grupos[posicao];
  final (rota, extra) = switch (grupo) {
    GrupoAvulso(:final indice) => (Rotas.exercicioAoVivo, indice as Object),
    GrupoBloco(:final blocoId) => (Rotas.blocoAoVivo, blocoId as Object),
  };
  if (substituir) {
    context.pushReplacement(rota, extra: extra);
  } else {
    context.push(rota, extra: extra);
  }
}

/// Tela do bloco conjugado no treino ao vivo (PBI-102): "Rodada 2 de 4" no
/// topo, os exercícios que participam da rodada com os campos da série
/// (pré-preenchidos e editáveis), o check de cada série e o botão grande
/// "Rodada feita", que marca todas de uma vez. O descanso do bloco dispara uma
/// vez, quando a última série da rodada fica marcada.
class BlocoAoVivoScreen extends ConsumerStatefulWidget {
  const BlocoAoVivoScreen({super.key, required this.blocoId});

  final String blocoId;

  @override
  ConsumerState<BlocoAoVivoScreen> createState() => _BlocoAoVivoScreenState();
}

class _BlocoAoVivoScreenState extends ConsumerState<BlocoAoVivoScreen> {
  /// Rodada aberta à mão pelas setas. Nulo = a rodada atual (a primeira que
  /// ainda não fechou), calculada pelas marcações.
  int? _rodadaVista;

  TreinoAoVivoController get _controller =>
      ref.read(treinoAoVivoControllerProvider.notifier);

  int? get _descanso =>
      ref.read(treinoAoVivoControllerProvider)?.descansoDosBlocos[widget.blocoId];

  /// Fechou a rodada agora: dispara o descanso do bloco (nada se for nulo ou
  /// 0) e volta para a rodada atual, que já é a próxima.
  void _aoFechar() {
    ref.read(descansoControllerProvider.notifier).iniciar(descansoQueDispara(_descanso));
    setState(() => _rodadaVista = null);
  }

  void _rodadaFeita(List<ExercicioEdicao> membros, int rodada) {
    final antes = rodadaFechada(membros, rodada);
    _controller.marcarRodada(membros, rodada);
    if (!antes) _aoFechar();
  }

  void _alternar(List<ExercicioEdicao> membros, int rodada, ExercicioEdicao membro,
      SerieEdicao serie) {
    final antes = rodadaFechada(membros, rodada);
    _controller.definirSerieFeita(membro, serie, !serie.feita);
    final depois = rodadaFechada(membros, rodada);
    if (!antes && depois) {
      _aoFechar();
    } else if (antes && !depois) {
      // Desfez uma rodada fechada: o descanso dela, se estiver correndo, para.
      ref.read(descansoControllerProvider.notifier).encerrar();
      setState(() => _rodadaVista = rodada);
    }
  }

  void _concluir(List<ExercicioEdicao> membros, List<GrupoAoVivo> grupos, int posicao) {
    _controller.concluirBloco(membros);
    if (posicao >= grupos.length - 1) {
      context.pushReplacement(Rotas.resumoTreino);
    } else {
      abrirGrupoAoVivo(context, grupos, posicao + 1, substituir: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(treinoAoVivoControllerProvider);
    final grupos = estado == null ? const <GrupoAoVivo>[] : gruposDoTreino(estado.exercicios);
    final posicao = grupoDoBloco(grupos, widget.blocoId);
    if (estado == null || posicao < 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bloco')),
        body: const Center(child: Text('Bloco não encontrado.')),
      );
    }

    final membros = [for (final i in grupos[posicao].indices) estado.exercicios[i]];
    final total = rodadasDoBloco(membros);
    final rodada = (_rodadaVista ?? rodadaAtual(membros)).clamp(1, total < 1 ? 1 : total);
    final daRodada = seriesDaRodada(membros, rodada);
    final fechada = rodadaFechada(membros, rodada);
    final ultimoGrupo = posicao == grupos.length - 1;
    final descanso = descansoQueDispara(estado.descansoDosBlocos[widget.blocoId]);

    return Scaffold(
      appBar: AppBar(title: const Text('Bloco conjugado')),
      body: SafeArea(
        child: Column(
          children: [
            _CabecalhoBloco(
              posicao: posicao,
              total: grupos.length,
              inicio: estado.inicio,
              rodada: rodada,
              rodadas: total,
              feitas: rodadasFeitas(membros),
              descanso: descanso,
              rotuloFalado: rotuloFaladoRodada(membros, rodada),
              aoAnteriorGrupo: posicao > 0
                  ? () => abrirGrupoAoVivo(context, grupos, posicao - 1, substituir: true)
                  : null,
              aoProximoGrupo: !ultimoGrupo
                  ? () => abrirGrupoAoVivo(context, grupos, posicao + 1, substituir: true)
                  : null,
              aoRodadaAnterior:
                  rodada > 1 ? () => setState(() => _rodadaVista = rodada - 1) : null,
              aoProximaRodada:
                  rodada < total ? () => setState(() => _rodadaVista = rodada + 1) : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.margemTela),
                children: [
                  for (final (membro, serie) in daRodada) ...[
                    _CardSerieDoBloco(
                      key: ValueKey(serie.id),
                      membro: membro,
                      serie: serie,
                      rodada: rodada,
                      aoAlternar: () => _alternar(membros, rodada, membro, serie),
                    ),
                    const SizedBox(height: AppSpacing.entreItens),
                  ],
                  const SizedBox(height: AppSpacing.x8),
                  SizedBox(
                    height: AppSizes.botaoPrincipal,
                    child: Semantics(
                      container: true,
                      button: true,
                      label: fechada
                          ? 'Rodada $rodada feita'
                          : 'Rodada feita, marca ${daRodada.length == 1 ? 'a série' : 'as ${daRodada.length} séries'} da rodada $rodada',
                      excludeSemantics: true,
                      child: FilledButton.icon(
                        onPressed: fechada ? null : () => _rodadaFeita(membros, rodada),
                        icon: const Icon(LucideIcons.checkCheck, size: AppSizes.iconeMd),
                        label: Text('RODADA FEITA', style: AppText.button),
                      ),
                    ),
                  ),
                  if (fechada) ...[
                    const SizedBox(height: AppSpacing.x6),
                    Text(
                      rodada < total
                          ? 'Rodada $rodada feita. Toque no check de uma série para desfazer.'
                          : 'Todas as rodadas feitas.',
                      textAlign: TextAlign.center,
                      style: AppText.caption
                          .copyWith(color: AppColors.of(context).textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x24),
                  _ConcluirBloco(
                    membros: membros,
                    ultimo: ultimoGrupo,
                    aoConcluir: () => _concluir(membros, grupos, posicao),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                ],
              ),
            ),
            // Descanso do bloco: fixo no rodapé (TV-5).
            const BarraDescansoFixa(),
          ],
        ),
      ),
    );
  }
}

/// Topo da tela do bloco: posição no treino com as setas, cronômetro, a rodada
/// ("Rodada 2 de 4") com as setas de rodada, o descanso e a barra de rodadas.
class _CabecalhoBloco extends StatelessWidget {
  const _CabecalhoBloco({
    required this.posicao,
    required this.total,
    required this.inicio,
    required this.rodada,
    required this.rodadas,
    required this.feitas,
    required this.descanso,
    required this.rotuloFalado,
    required this.aoAnteriorGrupo,
    required this.aoProximoGrupo,
    required this.aoRodadaAnterior,
    required this.aoProximaRodada,
  });

  final int posicao;
  final int total;
  final DateTime inicio;
  final int rodada;
  final int rodadas;
  final int feitas;
  final int? descanso;
  final String rotuloFalado;
  final VoidCallback? aoAnteriorGrupo;
  final VoidCallback? aoProximoGrupo;
  final VoidCallback? aoRodadaAnterior;
  final VoidCallback? aoProximaRodada;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cores.lineDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BotaoRedondo(
                  icone: LucideIcons.chevronLeft,
                  rotulo: 'Exercício anterior',
                  aoTocar: aoAnteriorGrupo),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text('Exercício ${posicao + 1} de $total',
                    style: AppText.overline.copyWith(color: cores.textSecondary)),
              ),
              CronometroVivo(inicio: inicio, estilo: AppText.numeralS),
              const SizedBox(width: AppSpacing.x8),
              _BotaoRedondo(
                  icone: LucideIcons.chevronRight,
                  rotulo: 'Próximo exercício',
                  aoTocar: aoProximoGrupo),
            ],
          ),
          const SizedBox(height: AppSpacing.x12),
          Row(
            children: [
              _BotaoRedondo(
                  icone: LucideIcons.chevronLeft,
                  rotulo: 'Rodada anterior',
                  aoTocar: aoRodadaAnterior),
              Expanded(
                child: Semantics(
                  header: true,
                  label: rotuloFalado,
                  excludeSemantics: true,
                  child: Text('Rodada $rodada de $rodadas',
                      textAlign: TextAlign.center, style: AppText.displayS),
                ),
              ),
              _BotaoRedondo(
                  icone: LucideIcons.chevronRight,
                  rotulo: 'Próxima rodada',
                  aoTocar: aoProximaRodada),
            ],
          ),
          const SizedBox(height: AppSpacing.x6),
          Text(
            descanso == null
                ? 'Sem descanso entre as rodadas'
                : 'Descanso de $descanso s depois de cada rodada',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: cores.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x8),
          BarraSeries(total: rodadas, feitas: feitas),
        ],
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  const _BotaoRedondo({required this.icone, required this.rotulo, required this.aoTocar});

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label: rotulo,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: aoTocar,
        child: Container(
          width: AppSizes.touchMin,
          height: AppSizes.touchMin,
          decoration: BoxDecoration(
            color: cores.bgInput,
            shape: BoxShape.circle,
            border: Border.all(color: cores.lineDefault),
          ),
          child: Icon(icone,
              size: AppSizes.iconeSm,
              color: aoTocar == null ? cores.iconMuted : cores.textStrong),
        ),
      ),
    );
  }
}

/// A série de um membro na rodada: nome, check individual (44 px) e os campos
/// de intensidade e volume com os steppers, como na tela do exercício.
class _CardSerieDoBloco extends StatelessWidget {
  const _CardSerieDoBloco({
    super.key,
    required this.membro,
    required this.serie,
    required this.rodada,
    required this.aoAlternar,
  });

  final ExercicioEdicao membro;
  final SerieEdicao serie;
  final int rodada;
  final VoidCallback aoAlternar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
      decoration: BoxDecoration(
        color: serie.feita ? cores.primaryTint : esquema.surface,
        border: Border.all(color: serie.feita ? cores.primaryTint : cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(membro.nome, style: AppText.titleS)),
              Semantics(
                container: true,
                button: true,
                checked: serie.feita,
                label: serie.feita
                    ? '${membro.nome}, série $rodada feita. Tocar para desmarcar.'
                    : '${membro.nome}, série $rodada pendente. Tocar para marcar.',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: aoAlternar,
                  child: SizedBox(
                    width: AppSizes.touchMin,
                    height: AppSizes.touchMin,
                    child: Center(
                      child: Container(
                        width: AppSizes.iconeMd,
                        height: AppSizes.iconeMd,
                        decoration: BoxDecoration(
                          color: serie.feita ? esquema.primary : null,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: serie.feita ? esquema.primary : cores.lineDashed,
                              width: AppSizes.bordaDestaque),
                        ),
                        child: serie.feita
                            ? Icon(LucideIcons.check,
                                size: AppSpacing.x14, color: esquema.onPrimary)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x8),
          if (!serie.intensidadePorPesoCorporal) ...[
            Text(serie.intensidadeMetricaNome,
                style: AppText.label.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x6),
            StepperMetrica(
              codigo: serie.intensidadeMetricaCodigo,
              controlador: serie.intensidade,
              rotulo: '${serie.intensidadeMetricaNome} de ${membro.nome}',
            ),
            const SizedBox(height: AppSpacing.x8),
          ],
          Text(serie.volumeMetricaNome,
              style: AppText.label.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x6),
          StepperMetrica(
            codigo: serie.volumeMetricaCodigo,
            controlador: serie.volume,
            rotulo: '${serie.volumeMetricaNome} de ${membro.nome}',
          ),
        ],
      ),
    );
  }
}

/// "Concluir bloco" (o "Concluir exercício" da PBI-65 para o bloco): o que não
/// foi marcado fica de fora ao salvar.
class _ConcluirBloco extends StatelessWidget {
  const _ConcluirBloco({required this.membros, required this.ultimo, required this.aoConcluir});

  final List<ExercicioEdicao> membros;
  final bool ultimo;
  final VoidCallback aoConcluir;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final pendentes =
        membros.fold<int>(0, (n, m) => n + m.series.where((s) => !s.feita).length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendentes > 0) ...[
          Text(
            pendentes == 1
                ? '1 série sem marcar fica de fora.'
                : '$pendentes séries sem marcar ficam de fora.',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: cores.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x6),
        ],
        SizedBox(
          height: AppSizes.botaoSecundario,
          child: OutlinedButton.icon(
            onPressed: aoConcluir,
            iconAlignment: IconAlignment.end,
            icon: const Icon(LucideIcons.chevronRight, size: AppSizes.iconeSm),
            label: Text(ultimo ? 'Concluir e ir ao resumo' : 'Concluir bloco'),
          ),
        ),
      ],
    );
  }
}
