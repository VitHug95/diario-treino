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

/// Saldo do descanso com sinal (PBI-90): "00:34" enquanto falta tempo e
/// "−00:05" depois que zerou (usa o sinal de menos tipográfico, como "−15s").
String formatarSaldo(Duration d) =>
    d.isNegative ? '−${formatarDuracao(-d)}' : formatarDuracao(d);

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
/// ativo no [descansoControllerProvider]. Ao zerar, NÃO some (PBI-90): segue
/// contando negativo ("−00:05") e avisa "Descanso acabou, volte ao treino" até
/// o atleta tocar em "Voltar ao treino" (ou completar a próxima série, que
/// começa outro descanso). O saldo é calculado por `fim - agora` (via
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
    // Só redesenha a cada segundo; zerar não encerra o descanso (PBI-90).
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
    final estado = ref.watch(descansoControllerProvider);
    if (estado == null) return const SizedBox.shrink();

    final cores = AppColors.of(context);
    final agora = ref.read(relogioProvider).agora();
    final saldo = estado.saldo(agora);
    final acabou = estado.acabou(agora);
    final restante = estado.restante(agora);
    // Acabou: a barra fica cheia (o tempo todo foi usado e passou).
    final fracao = acabou
        ? 1.0
        : estado.total.inSeconds == 0
            ? 0.0
            : (restante.inSeconds / estado.total.inSeconds).clamp(0.0, 1.0);
    final notifier = ref.read(descansoControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Acabou: borda mais forte chama a atenção sem trocar a paleta (o
        // vermelho do tema é só para exclusão).
        border: Border.all(
          color: acabou ? cores.primaryText : cores.primaryTint,
          width: acabou ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(acabou ? LucideIcons.bellRing : LucideIcons.timer,
                  size: AppSizes.iconeSm, color: cores.primaryOnTint),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: acabou
                    // Anunciado uma vez, quando muda para "acabou" (o tempo
                    // negativo que corre ao lado não é região viva, para não
                    // narrar cada segundo).
                    ? Semantics(
                        liveRegion: true,
                        label: 'Descanso acabou, volte ao treino',
                        excludeSemantics: true,
                        child: Text('Descanso acabou, volte ao treino',
                            style: AppText.label.copyWith(
                                color: cores.primaryOnTint,
                                fontWeight: FontWeight.w700)),
                      )
                    : Text('Descanso',
                        style: AppText.label
                            .copyWith(color: cores.primaryOnTint)),
              ),
              const SizedBox(width: AppSpacing.x8),
              Semantics(
                liveRegion: !acabou,
                label: acabou
                    ? 'Passou ${rotuloDuracao(-saldo)} do tempo de descanso'
                    : 'Descanso: ${rotuloDuracao(restante)} restantes',
                excludeSemantics: true,
                child: Text(formatarSaldo(saldo),
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
              // Depois de zerar, tirar 15s não faz sentido (só encerraria).
              if (!acabou) ...[
                _BotaoDescanso(
                  rotulo: 'Tirar 15 segundos do descanso',
                  texto: '−15s',
                  cores: cores,
                  aoTocar: notifier.subtrair,
                ),
                const SizedBox(width: AppSpacing.x8),
              ],
              _BotaoDescanso(
                rotulo: 'Adicionar 15 segundos ao descanso',
                texto: '+15s',
                cores: cores,
                aoTocar: notifier.adicionar,
              ),
              const Spacer(),
              _BotaoDescanso(
                rotulo: acabou ? 'Voltar ao treino' : 'Pular descanso',
                texto: acabou ? 'Voltar ao treino' : 'Pular',
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

/// Faixa FIXA no rodapé da tela do exercício com a barra de descanso (protótipo
/// 15): fica visível nas três abas e não rola junto com a lista de séries. Não
/// ocupa espaço quando não há descanso ativo.
class BarraDescansoFixa extends ConsumerWidget {
  const BarraDescansoFixa({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(descansoControllerProvider) == null) {
      return const SizedBox.shrink();
    }
    final cores = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: cores.lineDivider)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.x12),
        child: BarraDescanso(),
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
