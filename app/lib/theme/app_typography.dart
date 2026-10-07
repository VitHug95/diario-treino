import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Estilos de texto nomeados do guia de design. Barlow Condensed para títulos,
/// números e botão; Barlow para o resto.
///
/// As cores NÃO são definidas aqui — vêm do tema (ex.: `.copyWith(color: ...)`),
/// para o mesmo estilo servir sobre fundo claro, escuro e cabeçalho.
abstract final class AppText {
  static TextStyle _cond(double size, double height, FontWeight weight,
          {double spacing = 0}) =>
      GoogleFonts.barlowCondensed(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: spacing,
      );

  static TextStyle _sans(double size, double height, FontWeight weight,
          {double spacing = 0}) =>
      GoogleFonts.barlow(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: spacing,
      );

  // Barlow Condensed
  static TextStyle get displayXl => _cond(52, 49.4, FontWeight.w700, spacing: 0.5);
  static TextStyle get displayL => _cond(38, 38, FontWeight.w700, spacing: 0.3);
  static TextStyle get displayM => _cond(34, 34, FontWeight.w700);
  static TextStyle get displayS => _cond(30, 30, FontWeight.w700);
  static TextStyle get numeral => _cond(26, 26, FontWeight.w700);
  static TextStyle get numeralS => _cond(22, 22, FontWeight.w700);
  static TextStyle get button => _cond(20, 20, FontWeight.w700, spacing: 1);

  // Barlow
  static TextStyle get title => _sans(18, 23.4, FontWeight.w600);
  static TextStyle get titleS => _sans(17, 22.1, FontWeight.w600);
  static TextStyle get inputValue => _sans(17, 20.4, FontWeight.w400);
  static TextStyle get body => _sans(16, 22.4, FontWeight.w400);
  static TextStyle get bodyS => _sans(15, 21, FontWeight.w400);
  static TextStyle get label => _sans(14, 18.2, FontWeight.w600);
  static TextStyle get caption => _sans(13, 17.55, FontWeight.w400);
  static TextStyle get overline => _sans(13, 15.6, FontWeight.w600, spacing: 1.2);
  static TextStyle get tableHead => _sans(12, 14.4, FontWeight.w600, spacing: 0.6);

  /// Mapeia os estilos nomeados para os slots do Material [TextTheme], para que
  /// widgets padrão (AppBar, ListTile, botões) herdem a tipografia certa.
  static TextTheme textThemeBase(Color corPrincipal, Color corSecundaria) {
    TextStyle p(TextStyle s) => s.copyWith(color: corPrincipal);
    TextStyle sec(TextStyle s) => s.copyWith(color: corSecundaria);
    return TextTheme(
      displayLarge: p(displayXl),
      displayMedium: p(displayL),
      displaySmall: p(displayM),
      headlineMedium: p(displayS),
      headlineSmall: p(numeral),
      titleLarge: p(title),
      titleMedium: p(titleS),
      titleSmall: p(label),
      bodyLarge: p(body),
      bodyMedium: p(body),
      bodySmall: sec(caption),
      labelLarge: p(button),
      labelMedium: sec(overline),
      labelSmall: sec(tableHead),
    );
  }
}
