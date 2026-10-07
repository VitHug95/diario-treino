import 'package:flutter/widgets.dart';

/// Paleta bruta dos dois temas (opção A clara, opção B escura), direto do guia
/// de design. Estes valores NÃO são usados pelos widgets — alimentam o
/// `ColorScheme` e a `AppColors` em `app_theme.dart`.
abstract final class CoresClaro {
  static const bgPage = Color(0xFFF3F2EE);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgInput = Color(0xFFF8F7F4);
  static const bgHeader = Color(0xFF15171C);
  static const bgHeaderInput = Color(0xFF1F2228);
  static const bgTrack = Color(0xFFE6E4DD);
  static const lineDefault = Color(0xFFDEDCD5);
  static const lineDashed = Color(0xFFB5B2A8);
  static const lineDivider = Color(0xFFECEAE4);
  static const lineHeader = Color(0xFF3A3E47);
  static const textPrimary = Color(0xFF15171C);
  static const textSecondary = Color(0xFF5B5F68);
  static const textStrong = Color(0xFF3B3E45);
  static const textOnHeader = Color(0xFFF3F2EE);
  static const textOnHeaderMuted = Color(0xFFB9BCC4);
  static const textOnHeaderLabel = Color(0xFFD7D9DE);
  static const primary = Color(0xFF2552D9);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFF2552D9);
  static const primaryHover = Color(0xFF1A3FAF);
  static const primaryTint = Color(0xFFE7ECFB);
  static const primaryOnTint = Color(0xFF1E3FA8);
  static const chartLine = Color(0xFF2552D9);
  static const linkOnHeader = Color(0xFF8FA9FF);
  static const obs = Color(0xFFC2410C);
  static const obsTint = Color(0xFFFBEDE6);
  static const obsLine = Color(0xFFF0C9B5);
  static const obsTitle = Color(0xFF8A2E08);
  static const obsBody = Color(0xFF3B1A0C);
  static const danger = Color(0xFFB42318);
  static const dangerFill = Color(0xFFB42318);
  static const iconMuted = Color(0xFF9A9DA4);
}

abstract final class CoresEscuro {
  static const bgPage = Color(0xFF0E0F12);
  static const bgSurface = Color(0xFF1A1C21);
  static const bgInput = Color(0xFF23262C);
  static const bgHeader = Color(0xFF141B33);
  static const bgHeaderInput = Color(0xFF1E2642);
  static const bgTrack = Color(0xFF23262C);
  static const lineDefault = Color(0xFF2C2F36);
  static const lineDashed = Color(0xFF4A4E57);
  static const lineDivider = Color(0xFF2A2D34);
  static const lineHeader = Color(0xFF2C3350);
  static const textPrimary = Color(0xFFF2F2EF);
  static const textSecondary = Color(0xFFA4A8B1);
  static const textStrong = Color(0xFFC9CCD2);
  static const textOnHeader = Color(0xFFF2F2EF);
  static const textOnHeaderMuted = Color(0xFFA4A8B1);
  static const textOnHeaderLabel = Color(0xFFC9CCD2);
  static const primary = Color(0xFF2F5BEA);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryText = Color(0xFF8FA9FF);
  static const primaryHover = Color(0xFFB4C5FF);
  static const primaryTint = Color(0xFF1E2A52);
  static const primaryOnTint = Color(0xFFB4C5FF);
  static const chartLine = Color(0xFF7B9BFF);
  static const linkOnHeader = Color(0xFF8FA9FF);
  static const obs = Color(0xFFFF8A4C);
  static const obsTint = Color(0xFF33201A);
  static const obsLine = Color(0xFF5A3220);
  static const obsTitle = Color(0xFFFFB48A);
  static const obsBody = Color(0xFFFFD9C4);
  static const danger = Color(0xFFFF7A6E);
  static const dangerFill = Color(0xFFC8372B);
  static const iconMuted = Color(0xFF6E727B);
}

/// Raios de canto (guia: Raios).
abstract final class AppRadius {
  static const avisos = 8.0;
  static const campoSerie = 10.0;
  static const campoForm = 12.0;
  static const botaoPrincipal = 14.0;
  static const card = 16.0;
  static const destaque = 18.0;
  static const pill = 999.0;
}

/// Escala de espaçamento (guia: Espaçamento).
abstract final class AppSpacing {
  static const x4 = 4.0;
  static const x6 = 6.0;
  static const x8 = 8.0;
  static const x10 = 10.0;
  static const x12 = 12.0;
  static const x14 = 14.0;
  static const x16 = 16.0;
  static const x20 = 20.0;
  static const x24 = 24.0;
  static const x28 = 28.0;

  static const margemTela = x16;
  static const margemCabecalho = x20;
  static const margemLogin = x28;
  static const paddingCard = x16;
  static const paddingCardCompacto = x14;
  static const entreCards = x12;
  static const entreItens = x8;
}

/// Tamanhos de componentes (guia: Tamanhos).
abstract final class AppSizes {
  static const touchMin = 44.0;
  static const campoSerie = 44.0;
  static const campoHeader = 46.0;
  static const campoForm = 50.0;
  static const botaoSecundario = 48.0;
  static const botaoPrincipal = 56.0;
  static const navInferior = 78.0;
  static const iconeMd = 24.0;
  static const iconeSm = 20.0;
}
