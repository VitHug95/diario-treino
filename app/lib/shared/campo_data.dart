import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Campo que mostra um dia (dd/MM/aaaa) e abre o seletor ao tocar. Mesma
/// aparência do "Dia em que treinou" do registro de treino; ali o widget é
/// privado de cada tela, aqui fica compartilhado para as telas novas.
class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.texto,
    required this.aoTocar,
  });

  final String rotulo;
  final String texto;

  /// Nulo deixa o campo só de leitura (ex.: o dia de uma medição já gravada).
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: aoTocar != null,
      label: aoTocar == null
          ? '$rotulo: $texto'
          : '$rotulo: $texto. Toque para trocar',
      excludeSemantics: true,
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        child: InputDecorator(
          decoration: InputDecoration(labelText: rotulo),
          child: Row(
            children: [
              Icon(LucideIcons.calendar,
                  size: AppSizes.iconeSm, color: cores.iconMuted),
              const SizedBox(width: AppSpacing.x8),
              Text(texto, style: AppText.inputValue),
            ],
          ),
        ),
      ),
    );
  }
}
