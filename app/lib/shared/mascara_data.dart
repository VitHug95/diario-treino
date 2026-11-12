import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Máscara dd/mm/aaaa enquanto se digita (PBI-97). Ninguém precisa digitar a
/// barra: `26051995` vira `26/05/1995`.
///
/// - Só dígitos entram. A barra digitada ou colada é descartada, então digitar
///   `/` onde ela já está (ou antes da hora) não muda nada.
/// - Ao completar o dia (2 dígitos) e o mês (4), a barra seguinte entra sozinha;
///   com o ano completo (8 dígitos) para: o que passar disso é cortado.
/// - Colar `26/05/1995` ou `26051995` dá o mesmo resultado.
/// - Apagar passa pela barra sem travar: apagar a barra leva junto o dígito
///   anterior (`26/` vira `2`); apagar um dígito não recoloca a barra de volta.
class MascaraDataFormatter extends TextInputFormatter {
  const MascaraDataFormatter();

  static const _maxDigitos = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final apagando = novo.text.length < antigo.text.length;
    var digitos = _soDigitos(novo.text);

    // Posição do cursor em número de dígitos à esquerda dele.
    final cursor = novo.selection.baseOffset.clamp(0, novo.text.length);
    var digitosAntesDoCursor =
        _soDigitos(novo.text.substring(0, cursor)).length;

    // Só a barra foi apagada: UM caractere a menos e os mesmos dígitos. Leva o dígito
    // anterior junto, senão a máscara recolocaria a barra e o usuário não sairia dali.
    // (Trocar o texto todo por outro de mesmos dígitos, como colar por cima, tem
    // mais de um caractere de diferença e não é isto.)
    final soABarra = apagando &&
        antigo.text.length - novo.text.length == 1 &&
        digitos == _soDigitos(antigo.text);
    if (soABarra && digitosAntesDoCursor > 0) {
      final i = digitosAntesDoCursor - 1;
      digitos = digitos.substring(0, i) + digitos.substring(i + 1);
      digitosAntesDoCursor = i;
    }

    if (digitos.length > _maxDigitos) {
      digitos = digitos.substring(0, _maxDigitos);
    }
    digitosAntesDoCursor = math.min(digitosAntesDoCursor, digitos.length);

    // A barra automática é de quem DIGITA (um caractere por vez). Colar vários
    // de uma vez (`2605`) não ganha a barra de sobra no fim: fica `26/05`.
    final digitando = !apagando && novo.text.length - antigo.text.length <= 1;
    final texto = _formatar(digitos, comBarraFinal: digitando);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(
        offset: _posicao(texto, digitosAntesDoCursor, digitos.length),
      ),
    );
  }

  static String _soDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// `comBarraFinal`: ao digitar, completar o dia ou o mês já traz a barra.
  /// Ao apagar não, para o usuário poder recuar sem a máscara reabrir a barra.
  static String _formatar(String d, {required bool comBarraFinal}) {
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(d[i]);
    }
    if (comBarraFinal && (d.length == 2 || d.length == 4)) b.write('/');
    return b.toString();
  }

  /// Índice no texto formatado logo depois do [k]-ésimo dígito. Com o cursor no
  /// fim (digitando), vai para o fim, depois da barra automática.
  static int _posicao(String texto, int k, int totalDigitos) {
    if (k >= totalDigitos) return texto.length;
    if (k <= 0) return 0;
    var vistos = 0;
    for (var i = 0; i < texto.length; i++) {
      if (texto[i] != '/') vistos++;
      if (vistos == k) {
        // Se a barra vem logo depois, o cursor fica depois dela.
        return (i + 1 < texto.length && texto[i + 1] == '/') ? i + 2 : i + 1;
      }
    }
    return texto.length;
  }
}
