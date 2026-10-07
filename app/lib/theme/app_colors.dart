import 'package:flutter/material.dart';

import 'theme_tokens.dart';

/// Cores do produto que o [ColorScheme] padrão do Material não cobre.
/// Acessível via `Theme.of(context).extension<AppColors>()!`. Mantém a regra de
/// "nenhuma cor direto no widget": as telas leem destes campos.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgInput,
    required this.bgHeader,
    required this.bgHeaderInput,
    required this.bgTrack,
    required this.lineDefault,
    required this.lineDashed,
    required this.lineDivider,
    required this.lineHeader,
    required this.textSecondary,
    required this.textStrong,
    required this.textOnHeader,
    required this.textOnHeaderMuted,
    required this.textOnHeaderLabel,
    required this.primaryText,
    required this.primaryHover,
    required this.primaryTint,
    required this.primaryOnTint,
    required this.chartLine,
    required this.linkOnHeader,
    required this.obs,
    required this.obsTint,
    required this.obsLine,
    required this.obsTitle,
    required this.obsBody,
    required this.danger,
    required this.dangerFill,
    required this.iconMuted,
  });

  final Color bgInput;
  final Color bgHeader;
  final Color bgHeaderInput;
  final Color bgTrack;
  final Color lineDefault;
  final Color lineDashed;
  final Color lineDivider;
  final Color lineHeader;
  final Color textSecondary;
  final Color textStrong;
  final Color textOnHeader;
  final Color textOnHeaderMuted;
  final Color textOnHeaderLabel;
  final Color primaryText;
  final Color primaryHover;
  final Color primaryTint;
  final Color primaryOnTint;
  final Color chartLine;
  final Color linkOnHeader;
  final Color obs;
  final Color obsTint;
  final Color obsLine;
  final Color obsTitle;
  final Color obsBody;
  final Color danger;
  final Color dangerFill;
  final Color iconMuted;

  static const AppColors claro = AppColors(
    bgInput: CoresClaro.bgInput,
    bgHeader: CoresClaro.bgHeader,
    bgHeaderInput: CoresClaro.bgHeaderInput,
    bgTrack: CoresClaro.bgTrack,
    lineDefault: CoresClaro.lineDefault,
    lineDashed: CoresClaro.lineDashed,
    lineDivider: CoresClaro.lineDivider,
    lineHeader: CoresClaro.lineHeader,
    textSecondary: CoresClaro.textSecondary,
    textStrong: CoresClaro.textStrong,
    textOnHeader: CoresClaro.textOnHeader,
    textOnHeaderMuted: CoresClaro.textOnHeaderMuted,
    textOnHeaderLabel: CoresClaro.textOnHeaderLabel,
    primaryText: CoresClaro.primaryText,
    primaryHover: CoresClaro.primaryHover,
    primaryTint: CoresClaro.primaryTint,
    primaryOnTint: CoresClaro.primaryOnTint,
    chartLine: CoresClaro.chartLine,
    linkOnHeader: CoresClaro.linkOnHeader,
    obs: CoresClaro.obs,
    obsTint: CoresClaro.obsTint,
    obsLine: CoresClaro.obsLine,
    obsTitle: CoresClaro.obsTitle,
    obsBody: CoresClaro.obsBody,
    danger: CoresClaro.danger,
    dangerFill: CoresClaro.dangerFill,
    iconMuted: CoresClaro.iconMuted,
  );

  static const AppColors escuro = AppColors(
    bgInput: CoresEscuro.bgInput,
    bgHeader: CoresEscuro.bgHeader,
    bgHeaderInput: CoresEscuro.bgHeaderInput,
    bgTrack: CoresEscuro.bgTrack,
    lineDefault: CoresEscuro.lineDefault,
    lineDashed: CoresEscuro.lineDashed,
    lineDivider: CoresEscuro.lineDivider,
    lineHeader: CoresEscuro.lineHeader,
    textSecondary: CoresEscuro.textSecondary,
    textStrong: CoresEscuro.textStrong,
    textOnHeader: CoresEscuro.textOnHeader,
    textOnHeaderMuted: CoresEscuro.textOnHeaderMuted,
    textOnHeaderLabel: CoresEscuro.textOnHeaderLabel,
    primaryText: CoresEscuro.primaryText,
    primaryHover: CoresEscuro.primaryHover,
    primaryTint: CoresEscuro.primaryTint,
    primaryOnTint: CoresEscuro.primaryOnTint,
    chartLine: CoresEscuro.chartLine,
    linkOnHeader: CoresEscuro.linkOnHeader,
    obs: CoresEscuro.obs,
    obsTint: CoresEscuro.obsTint,
    obsLine: CoresEscuro.obsLine,
    obsTitle: CoresEscuro.obsTitle,
    obsBody: CoresEscuro.obsBody,
    danger: CoresEscuro.danger,
    dangerFill: CoresEscuro.dangerFill,
    iconMuted: CoresEscuro.iconMuted,
  );

  /// Atalho: `AppColors.of(context)`.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgInput: Color.lerp(bgInput, other.bgInput, t)!,
      bgHeader: Color.lerp(bgHeader, other.bgHeader, t)!,
      bgHeaderInput: Color.lerp(bgHeaderInput, other.bgHeaderInput, t)!,
      bgTrack: Color.lerp(bgTrack, other.bgTrack, t)!,
      lineDefault: Color.lerp(lineDefault, other.lineDefault, t)!,
      lineDashed: Color.lerp(lineDashed, other.lineDashed, t)!,
      lineDivider: Color.lerp(lineDivider, other.lineDivider, t)!,
      lineHeader: Color.lerp(lineHeader, other.lineHeader, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      textOnHeader: Color.lerp(textOnHeader, other.textOnHeader, t)!,
      textOnHeaderMuted: Color.lerp(textOnHeaderMuted, other.textOnHeaderMuted, t)!,
      textOnHeaderLabel: Color.lerp(textOnHeaderLabel, other.textOnHeaderLabel, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      primaryOnTint: Color.lerp(primaryOnTint, other.primaryOnTint, t)!,
      chartLine: Color.lerp(chartLine, other.chartLine, t)!,
      linkOnHeader: Color.lerp(linkOnHeader, other.linkOnHeader, t)!,
      obs: Color.lerp(obs, other.obs, t)!,
      obsTint: Color.lerp(obsTint, other.obsTint, t)!,
      obsLine: Color.lerp(obsLine, other.obsLine, t)!,
      obsTitle: Color.lerp(obsTitle, other.obsTitle, t)!,
      obsBody: Color.lerp(obsBody, other.obsBody, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerFill: Color.lerp(dangerFill, other.dangerFill, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
    );
  }
}
