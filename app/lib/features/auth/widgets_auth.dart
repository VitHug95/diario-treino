import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';

/// Rótulo de campo sobre o cabeçalho escuro das telas de autenticação.
class RotuloCampoHeader extends StatelessWidget {
  const RotuloCampoHeader(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Text(texto, style: AppText.label.copyWith(color: cores.textOnHeaderLabel));
  }
}

/// Campo de texto sobre o cabeçalho escuro (login/cadastro).
class CampoHeader extends StatelessWidget {
  const CampoHeader({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofill,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<String>? autofill;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofill,
      textCapitalization: textCapitalization,
      style: AppText.body.copyWith(color: cores.textOnHeader),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: cores.textOnHeaderMuted),
        filled: true,
        fillColor: cores.bgHeaderInput,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          borderSide: BorderSide(color: cores.lineHeader),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          borderSide: BorderSide(color: cores.linkOnHeader, width: 2),
        ),
      ),
    );
  }
}
