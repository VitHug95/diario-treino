import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Cores próprias do produto que não cabem no [ColorScheme] do Material 3.
///
/// Acessível via `Theme.of(context).extension<AppColors>()`. Mantém a regra de
/// "nenhuma cor direto no widget": as telas leem destes campos, não de literais.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.observacao,
    required this.evolucaoPositiva,
  });

  /// Destaque de pontos do gráfico que têm observação (PBI-21).
  final Color observacao;

  /// Variação positiva de evolução no resumo do período (PBI-20).
  final Color evolucaoPositiva;

  static const AppColors claro = AppColors(
    observacao: ThemeTokens.observacaoClaro,
    evolucaoPositiva: ThemeTokens.evolucaoPositivaClaro,
  );

  static const AppColors escuro = AppColors(
    observacao: ThemeTokens.observacaoEscuro,
    evolucaoPositiva: ThemeTokens.evolucaoPositivaEscuro,
  );

  @override
  AppColors copyWith({Color? observacao, Color? evolucaoPositiva}) {
    return AppColors(
      observacao: observacao ?? this.observacao,
      evolucaoPositiva: evolucaoPositiva ?? this.evolucaoPositiva,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      observacao: Color.lerp(observacao, other.observacao, t)!,
      evolucaoPositiva: Color.lerp(evolucaoPositiva, other.evolucaoPositiva, t)!,
    );
  }
}
