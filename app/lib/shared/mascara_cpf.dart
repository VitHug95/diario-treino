import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Máscara `000.000.000-00` enquanto se digita (PBI-106), no padrão da máscara
/// de data (PBI-97): digitar só números já preenche os pontos e o traço.
///
/// - Só dígitos entram, no máximo 11; pontos e traço digitados ou colados são
///   descartados e recolocados no lugar certo.
/// - O separador aparece antes do dígito seguinte (`529.9`), nunca sozinho no fim,
///   então apagar do fim apaga sempre um dígito.
/// - Apagar um separador no meio leva junto o dígito anterior, para não travar.
class MascaraCpfFormatter extends TextInputFormatter {
  const MascaraCpfFormatter();

  static const _maxDigitos = 11;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue antigo, TextEditingValue novo) {
    final apagando = novo.text.length < antigo.text.length;
    var digitos = _soDigitos(novo.text);
    final cursor = novo.selection.baseOffset.clamp(0, novo.text.length);
    var digitosAntesDoCursor = _soDigitos(novo.text.substring(0, cursor)).length;

    final soOSeparador = apagando &&
        antigo.text.length - novo.text.length == 1 &&
        digitos == _soDigitos(antigo.text);
    if (soOSeparador && digitosAntesDoCursor > 0) {
      final i = digitosAntesDoCursor - 1;
      digitos = digitos.substring(0, i) + digitos.substring(i + 1);
      digitosAntesDoCursor = i;
    }

    if (digitos.length > _maxDigitos) digitos = digitos.substring(0, _maxDigitos);
    digitosAntesDoCursor = math.min(digitosAntesDoCursor, digitos.length);

    final texto = formatar(digitos);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: _posicao(texto, digitosAntesDoCursor)),
    );
  }

  static String _soDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// `52998224725` → `529.982.247-25` (parcial também: `5299` → `529.9`).
  static String formatar(String digitos) {
    final b = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i == 3 || i == 6) b.write('.');
      if (i == 9) b.write('-');
      b.write(digitos[i]);
    }
    return b.toString();
  }

  /// Índice no texto formatado logo depois do [k]-ésimo dígito.
  static int _posicao(String texto, int k) {
    if (k <= 0) return 0;
    var vistos = 0;
    for (var i = 0; i < texto.length; i++) {
      if (texto[i] != '.' && texto[i] != '-') vistos++;
      if (vistos == k) return i + 1;
    }
    return texto.length;
  }
}
