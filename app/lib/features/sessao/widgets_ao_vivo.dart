import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/relogio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';

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
