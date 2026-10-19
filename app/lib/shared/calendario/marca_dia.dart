import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_tokens.dart';

/// Marca visual de um dia na faixa semanal (Início) e na grade do mês
/// (calendário, PBI-82). Quatro estados que NÃO dependem só da cor:
/// - treinou: círculo cheio com check;
/// - hoje (sem treino): anel azul;
/// - passado sem treino: círculo de borda fina;
/// - futuro: círculo tracejado.
///
/// Recebe os três estados soltos (e não um modelo de dia) para servir tanto à
/// semana quanto ao mês sem acoplar a um tipo específico.
class MarcaDia extends StatelessWidget {
  const MarcaDia({
    super.key,
    required this.treinou,
    required this.ehHoje,
    required this.futuro,
    this.tamanho = 28.0,
  });

  final bool treinou;
  final bool ehHoje;
  final bool futuro;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final esquema = Theme.of(context).colorScheme;

    if (treinou) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(color: esquema.primary, shape: BoxShape.circle),
        child: Icon(LucideIcons.check, size: AppSizes.iconeSm, color: esquema.onPrimary),
      );
    }
    if (futuro) {
      return CustomPaint(
        size: Size.square(tamanho),
        painter: CirculoTracejado(cor: cores.lineDashed),
      );
    }
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Hoje: anel azul mais grosso. Passado sem treino: círculo vazio.
        border: ehHoje
            ? Border.all(color: cores.primaryText, width: 2)
            : Border.all(color: cores.lineDashed, width: 1.5),
      ),
    );
  }
}

/// Círculo tracejado do dia futuro.
class CirculoTracejado extends CustomPainter {
  CirculoTracejado({required this.cor});

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    const tracos = 12;
    const preenchido = 0.55; // fração de cada passo que é traço
    final raio = size.width / 2 - 0.75;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: raio);
    final pincel = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const passo = 2 * math.pi / tracos;
    for (var i = 0; i < tracos; i++) {
      canvas.drawArc(rect, i * passo, passo * preenchido, false, pincel);
    }
  }

  @override
  bool shouldRepaint(CirculoTracejado old) => old.cor != cor;
}
