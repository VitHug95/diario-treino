import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'theme_tokens.dart';

/// Monta os temas claro e escuro a partir dos tokens do guia de design.
/// Material 3, sem sombra (separação por borda), tipografia Barlow.
abstract final class AppTheme {
  static ThemeData get claro => _montar(
        brilho: Brightness.light,
        cores: AppColors.claro,
        bgPage: CoresClaro.bgPage,
        bgSurface: CoresClaro.bgSurface,
        primary: CoresClaro.primary,
        onPrimary: CoresClaro.onPrimary,
        textPrimary: CoresClaro.textPrimary,
        danger: CoresClaro.danger,
      );

  static ThemeData get escuro => _montar(
        brilho: Brightness.dark,
        cores: AppColors.escuro,
        bgPage: CoresEscuro.bgPage,
        bgSurface: CoresEscuro.bgSurface,
        primary: CoresEscuro.primary,
        onPrimary: CoresEscuro.onPrimary,
        textPrimary: CoresEscuro.textPrimary,
        danger: CoresEscuro.danger,
      );

  static ThemeData _montar({
    required Brightness brilho,
    required AppColors cores,
    required Color bgPage,
    required Color bgSurface,
    required Color primary,
    required Color onPrimary,
    required Color textPrimary,
    required Color danger,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brilho,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      surface: bgSurface,
      onSurface: textPrimary,
      error: danger,
    );

    final textTheme = AppText.textThemeBase(textPrimary, cores.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgPage,
      textTheme: textTheme,
      extensions: [cores],
      dividerColor: cores.lineDivider,

      appBarTheme: AppBarTheme(
        backgroundColor: bgPage,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.displayS.copyWith(color: textPrimary),
      ),

      // Card: surface + borda, sem sombra.
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cores.lineDefault),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: EdgeInsets.zero,
      ),

      // Botão principal: 56, raio 14, texto em caixa alta (button).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(AppSizes.botaoPrincipal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.botaoPrincipal),
          ),
          textStyle: AppText.button,
        ),
      ),

      // Botão secundário: surface + borda, raio 14.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: bgSurface,
          minimumSize: const Size.fromHeight(AppSizes.botaoSecundario),
          side: BorderSide(color: cores.lineDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.botaoPrincipal),
          ),
          textStyle: AppText.titleS,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cores.primaryText,
          textStyle: AppText.bodyS.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Campo de formulário: fill bgInput, borda lineDefault, raio 12.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cores.bgInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x14,
        ),
        hintStyle: AppText.body.copyWith(color: cores.textSecondary),
        labelStyle: AppText.label.copyWith(color: cores.textStrong),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          borderSide: BorderSide(color: cores.lineDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          borderSide: BorderSide(color: cores.lineDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),

      // Chip de filtro: pílula 44, selecionado = text-primary / surface.
      chipTheme: ChipThemeData(
        backgroundColor: bgSurface,
        selectedColor: textPrimary,
        side: BorderSide(color: cores.lineDefault),
        labelStyle: AppText.bodyS.copyWith(color: textPrimary),
        secondaryLabelStyle: AppText.bodyS.copyWith(color: bgSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgSurface,
        height: AppSizes.navInferior,
        indicatorColor: cores.primaryTint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? cores.primaryText
                : cores.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconeMd,
            color: states.contains(WidgetState.selected)
                ? cores.primaryText
                : cores.textSecondary,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(color: cores.lineDivider, thickness: 1),
    );
  }
}
