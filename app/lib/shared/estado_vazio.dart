import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Estado vazio: ícone, título, texto de apoio e uma ação opcional (PBI-51).
/// Um único componente no lugar das cópias de cada tela (`_EstadoVazio`,
/// `_Vazio`).
///
/// [acao] é o botão pronto (FilledButton, OutlinedButton...), para cada tela
/// manter o estilo/rótulo que já tinha — passe `null` quando não há ação
/// (ex.: lista de progresso vazia).
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: cores.iconMuted),
            const SizedBox(height: AppSpacing.x12),
            Text(titulo, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x8),
            Text(
              texto,
              style: AppText.body.copyWith(color: cores.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (acao != null) ...[
              const SizedBox(height: AppSpacing.x16),
              acao!,
            ],
          ],
        ),
      ),
    );
  }
}
