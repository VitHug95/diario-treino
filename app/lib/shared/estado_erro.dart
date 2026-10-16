import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Estado de erro de carregamento, com ícone, mensagem e botão "Tentar de novo"
/// (PBI-51). Um único componente no lugar das cópias que cada tela tinha
/// (`_Erro`, `_ErroCarregar`, `_ErroMetricas`), para corrigir num lugar só.
///
/// [aoTentar] roda ao tocar em "Tentar de novo" — tipicamente um
/// `ref.refresh(...)` da própria leitura da tela (PBI-70). Para callbacks
/// assíncronos, passe `() => algo()`.
class EstadoErro extends StatelessWidget {
  const EstadoErro({super.key, required this.mensagem, required this.aoTentar});

  /// Texto principal (ex.: "Não foi possível carregar as fichas.").
  final String mensagem;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
            const SizedBox(height: AppSpacing.x12),
            Text(mensagem, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x16),
            FilledButton(
              onPressed: aoTentar,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
