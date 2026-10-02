import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'theme_tokens.dart';

/// Monta os temas claro e escuro a partir dos tokens. Material 3 ligado; cada
/// tema registra a [AppColors] correspondente como extensão.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get claro => _construir(Brightness.light, AppColors.claro);

  static ThemeData get escuro => _construir(Brightness.dark, AppColors.escuro);

  static ThemeData _construir(Brightness brilho, AppColors cores) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: ThemeTokens.seed,
      brightness: brilho,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: [cores],
    );
  }
}
