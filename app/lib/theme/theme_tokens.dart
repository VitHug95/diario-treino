import 'package:flutter/material.dart';

/// Paleta base (tokens) dos temas claro (opção A) e escuro (opção B).
///
/// Centraliza as sementes de cor. Nenhum widget usa estes valores direto; eles
/// alimentam o [ColorScheme] e a [AppColors] em `app_theme.dart`. Ajustar aqui
/// reflete em todo o app.
abstract final class ThemeTokens {
  const ThemeTokens._();

  // Semente principal da marca. Material 3 deriva o esquema a partir dela.
  static const Color seed = Color(0xFF2E6CF6);

  // Cor própria do produto: destaque de pontos do gráfico com observação
  // (ADR-08 cita a cor de observação como caso de ThemeExtension).
  static const Color observacaoClaro = Color(0xFFB4690E);
  static const Color observacaoEscuro = Color(0xFFFFB95C);

  // Cor de sucesso/positivo para variações de evolução.
  static const Color evolucaoPositivaClaro = Color(0xFF1E7B46);
  static const Color evolucaoPositivaEscuro = Color(0xFF6FD69B);
}
