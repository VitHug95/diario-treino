import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/relogio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'descanso_controller.dart';

/// Cronômetro do treino em andamento (TV-3). O tempo é SEMPRE calculado por
/// `agora - inicio` (via [relogioProvider]); o `Timer.periodic` só dispara o
/// rebuild de 1 em 1 segundo — não acumula contagem. Assim o valor fica certo
/// mesmo que o navegador segure o timer com a aba em segundo plano.
class CronometroVivo extends ConsumerStatefulWidget {
  const CronometroVivo({super.key, required this.inicio, this.estilo});

  final DateTime inicio;
  final TextStyle? estilo;

  @override
  ConsumerState<CronometroVivo> createState() => _CronometroVivoState();
}

class _CronometroVivoState extends ConsumerState<CronometroVivo> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agora = ref.read(relogioProvider).agora();
    final decorrido = agora.difference(widget.inicio);
    final texto = formatarDuracao(decorrido);
    return Semantics(
      liveRegion: true,
      label: 'Tempo de treino: ${rotuloDuracao(decorrido)}',
      child: Text(texto, style: widget.estilo ?? AppText.displayM),
    );
  }
}

/// "MM:SS" (ou "H:MM:SS" acima de 1h), nunca negativo.
String formatarDuracao(Duration d) {
  final seg = d.isNegative ? 0 : d.inSeconds;
  final h = seg ~/ 3600;
  final m = (seg % 3600) ~/ 60;
  final s = seg % 60;
  String dois(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${dois(m)}:${dois(s)}' : '${dois(m)}:${dois(s)}';
}

/// Rótulo acessível, ex.: "38 minutos e 12 segundos".
String rotuloDuracao(Duration d) {
  final seg = d.isNegative ? 0 : d.inSeconds;
  final m = seg ~/ 60;
  final s = seg % 60;
  final parteMin = m == 1 ? '1 minuto' : '$m minutos';
  final parteSeg = s == 1 ? '1 segundo' : '$s segundos';
  return '$parteMin e $parteSeg';
}

/// Barra segmentada por série: uma célula por série, preenchida quando feita.
class BarraSeries extends StatelessWidget {
  const BarraSeries({super.key, required this.total, required this.feitas});

  final int total;
  final int feitas;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    if (total == 0) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < feitas ? cores.primaryText : cores.bgTrack,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Barra de descanso entre séries (TV-5). Aparece só quando há um descanso
/// ativo no [descansoControllerProvider]; some sozinha quando o tempo zera ou
/// o atleta pula. O tempo restante é calculado por `fim - agora` (via
/// [relogioProvider]); o `Timer.periodic` só dispara o rebuild de 1 em 1
/// segundo. Botões −15s / +15s ajustam e "Pular" encerra.
class BarraDescanso extends ConsumerStatefulWidget {
  const BarraDescanso({super.key});

  @override
  ConsumerState<BarraDescanso> createState() => _BarraDescansoState();
}

class _BarraDescansoState extends ConsumerState<BarraDescanso> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Rebuild para redesenhar o restante; se o tempo acabou, encerra.
      final estado = ref.read(descansoControllerProvider);
      final agora = ref.read(relogioProvider).agora();
      if (estado != null && estado.acabou(agora)) {
        ref.read(descansoControllerProvider.notifier).encerrar();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(descansoControllerProvider);
    if (estado == null) return const SizedBox.shrink();

    final cores = AppColors.of(context);
    final agora = ref.read(relogioProvider).agora();
    final restante = estado.restante(agora);
    final fracao = estado.total.inSeconds == 0
        ? 0.0
        : (restante.inSeconds / estado.total.inSeconds).clamp(0.0, 1.0);
    final notifier = ref.read(descansoControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cores.primaryTint),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.timer,
                  size: AppSizes.iconeSm, color: cores.primaryOnTint),
              const SizedBox(width: AppSpacing.x8),
              Text('Descanso',
                  style: AppText.label.copyWith(color: cores.primaryOnTint)),
              const Spacer(),
              Semantics(
                liveRegion: true,
                label: 'Descanso: ${rotuloDuracao(restante)} restantes',
                child: Text(formatarDuracao(restante),
                    style: AppText.numeralS.copyWith(color: cores.primaryOnTint)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: fracao,
              minHeight: 6,
              backgroundColor: cores.bgTrack,
              valueColor: AlwaysStoppedAnimation(cores.primaryText),
            ),
          ),
          const SizedBox(height: AppSpacing.x12),
          Row(
            children: [
              _BotaoDescanso(
                rotulo: 'Tirar 15 segundos do descanso',
                texto: '−15s',
                cores: cores,
                aoTocar: notifier.subtrair,
              ),
              const SizedBox(width: AppSpacing.x8),
              _BotaoDescanso(
                rotulo: 'Adicionar 15 segundos ao descanso',
                texto: '+15s',
                cores: cores,
                aoTocar: notifier.adicionar,
              ),
              const Spacer(),
              _BotaoDescanso(
                rotulo: 'Pular descanso',
                texto: 'Pular',
                cores: cores,
                destaque: true,
                aoTocar: notifier.encerrar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botãozinho da barra de descanso (−15s / +15s / Pular).
class _BotaoDescanso extends StatelessWidget {
  const _BotaoDescanso({
    required this.rotulo,
    required this.texto,
    required this.cores,
    required this.aoTocar,
    this.destaque = false,
  });

  final String rotulo;
  final String texto;
  final AppColors cores;
  final VoidCallback aoTocar;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cor = destaque ? cores.primaryText : cores.primaryOnTint;
    return Semantics(
      button: true,
      label: rotulo,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
        onTap: aoTocar,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
          decoration: BoxDecoration(
            color: destaque
                ? Theme.of(context).colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            border: Border.all(
                color: destaque ? cores.primaryText : cores.primaryOnTint),
          ),
          alignment: Alignment.center,
          child: Text(texto,
              style: AppText.label
                  .copyWith(color: cor, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
