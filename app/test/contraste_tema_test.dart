import 'dart:math' as math;

import 'package:diario_treino/theme/app_colors.dart';
import 'package:diario_treino/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PBI-24: trava o contraste mínimo dos pares texto/fundo nos dois temas.
/// Texto normal exige 4,5:1 (WCAG 1.4.3); ícones/UI, 3:1 (WCAG 1.4.11).
/// Lê as cores REAIS dos tokens (sem montar o ThemeData, que puxaria o
/// google_fonts e não carrega offline no teste). Qualquer mudança de token que
/// derrube o contraste quebra este teste.

double _lumCanal(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

// .r/.g/.b retornam o canal normalizado em 0..1 (Flutter 3.29+).
double _luminancia(Color c) =>
    0.2126 * _lumCanal(c.r) + 0.7152 * _lumCanal(c.g) + 0.0722 * _lumCanal(c.b);

double _contraste(Color a, Color b) {
  final la = _luminancia(a), lb = _luminancia(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

class _Par {
  _Par(this.rotulo, this.fg, this.bg, {this.alvo = 4.5});
  final String rotulo;
  final Color fg;
  final Color bg;
  final double alvo;
}

/// Pares reais de cada tema. [c] é a AppColors; [bgPage]/[surface]/[textPrimary]
/// vêm dos tokens que o ColorScheme usa (ver app_theme.dart).
List<_Par> _pares(AppColors c, Color bgPage, Color surface, Color textPrimary,
    Color primary, Color onPrimary) {
  return [
    // --- Texto: alvo 4,5:1 ---
    _Par('texto primário / página', textPrimary, bgPage),
    _Par('texto primário / card', textPrimary, surface),
    _Par('texto secundário / página', c.textSecondary, bgPage),
    _Par('texto secundário / card', c.textSecondary, surface),
    _Par('hint / input', c.textSecondary, c.bgInput),
    _Par('texto secundário / track', c.textSecondary, c.bgTrack),
    _Par('texto forte / card', c.textStrong, surface),
    _Par('label de campo / input', c.textStrong, c.bgInput),
    _Par('link·nav selecionado / card', c.primaryText, surface),
    _Par('link / página', c.primaryText, bgPage),
    _Par('botão principal', onPrimary, primary),
    _Par('aviso pré-preenchimento', c.primaryOnTint, c.primaryTint),
    _Par('título / cabeçalho', c.textOnHeader, c.bgHeader),
    _Par('texto muted / cabeçalho', c.textOnHeaderMuted, c.bgHeader),
    _Par('label / cabeçalho', c.textOnHeaderLabel, c.bgHeader),
    _Par('texto / input do cabeçalho', c.textOnHeader, c.bgHeaderInput),
    _Par('link / cabeçalho', c.linkOnHeader, c.bgHeader),
    _Par('título da observação', c.obsTitle, c.obsTint),
    _Par('corpo da observação', c.obsBody, c.obsTint),
    _Par('texto do botão de perigo', c.dangerOn, c.dangerFill),
    _Par('danger / card', c.danger, surface),
    _Par('lixeira / fundo suave', c.danger, c.dangerSoft),
    _Par('lixeira / cabeçalho', c.dangerOnHeader, c.bgHeader),
    _Par('chip selecionado (label / fundo)', surface, textPrimary),
    _Par('nav selecionado / indicador', c.primaryText, c.primaryTint),
    // --- Ícone/UI: alvo 3:1 ---
    _Par('ícone muted / card', c.iconMuted, surface, alvo: 3.0),
  ];
}

void main() {
  final temas = [
    (
      'claro',
      _pares(AppColors.claro, CoresClaro.bgPage, CoresClaro.bgSurface,
          CoresClaro.textPrimary, CoresClaro.primary, CoresClaro.onPrimary),
    ),
    (
      'escuro',
      _pares(AppColors.escuro, CoresEscuro.bgPage, CoresEscuro.bgSurface,
          CoresEscuro.textPrimary, CoresEscuro.primary, CoresEscuro.onPrimary),
    ),
  ];

  for (final (nome, pares) in temas) {
    group('Contraste — tema $nome (PBI-24)', () {
      for (final p in pares) {
        test('${p.rotulo} ≥ ${p.alvo}:1', () {
          final r = _contraste(p.fg, p.bg);
          expect(r, greaterThanOrEqualTo(p.alvo),
              reason: '${p.rotulo}: ${r.toStringAsFixed(2)}:1 (< ${p.alvo}:1)');
        });
      }
    });
  }
}
