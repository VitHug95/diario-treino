import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Ação "adicionar" do design system: transparente, borda tracejada
/// `lineDashed` de 1,5 px, altura 44, raio 10, texto `body-s` 600 com "+".
/// Usada em "Adicionar exercício à ficha" (PBI-52) e "Nova ficha" (PBI-46).
class BotaoTracejado extends StatelessWidget {
  const BotaoTracejado({super.key, required this.rotulo, required this.aoTocar});

  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: true,
      label: rotulo,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.touchMin,
        child: CustomPaint(
          painter: _BordaTracejada(cor: cores.lineDashed, raio: AppRadius.campoSerie),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: aoTocar,
              borderRadius: BorderRadius.circular(AppRadius.campoSerie),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.plus,
                      size: AppSizes.iconeSm, color: cores.textStrong),
                  const SizedBox(width: AppSpacing.x8),
                  // Flexible: em 360 px com fonte grande, corta em vez de
                  // estourar a linha.
                  Flexible(
                    child: Text(rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyS.copyWith(
                            fontWeight: FontWeight.w600, color: cores.textStrong)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinta uma borda arredondada tracejada.
class _BordaTracejada extends CustomPainter {
  _BordaTracejada({required this.cor, required this.raio});

  final Color cor;
  final double raio;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(raio));
    final caminho = Path()..addRRect(rrect);
    final tracejado = Path();
    const traco = 6.0;
    const vao = 4.0;
    for (final metrica in caminho.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metrica.length) {
        final fim = (distancia + traco).clamp(0.0, metrica.length);
        tracejado.addPath(metrica.extractPath(distancia, fim), Offset.zero);
        distancia += traco + vao;
      }
    }
    canvas.drawPath(
      tracejado,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BordaTracejada old) => old.cor != cor || old.raio != raio;
}
