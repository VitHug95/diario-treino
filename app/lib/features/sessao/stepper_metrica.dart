import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/metrica.dart';

/// Passo de incremento/decremento por código de métrica (TV-3). O valor fica
/// num [TextEditingController] compartilhado com o resto do registro; o stepper
/// só soma/subtrai e reescreve o texto, então o que o usuário digita à mão
/// continua valendo.
abstract final class PassosMetrica {
  /// Passo de ajuste de cada métrica. Nulo = sem stepper (ex.: PESO_CORPORAL,
  /// que não tem valor de intensidade a digitar).
  static double? passo(String codigo) => switch (codigo) {
        MetricaCodigos.cargaKg => 2.5,
        MetricaCodigos.repeticoes => 1,
        MetricaCodigos.tempoSeg => 5,
        MetricaCodigos.zona => 1,
        MetricaCodigos.distanciaM => 100,
        _ => null,
      };

  /// Faixa [min, max] para métricas limitadas. ZONA é de 1 a 5 (MER 3.4).
  static (double, double)? faixa(String codigo) => switch (codigo) {
        MetricaCodigos.zona => (1, 5),
        _ => (0, double.infinity),
      };

  /// Casas decimais ao reescrever: só CARGA_KG admite fração (2,5).
  static bool get fracao => true;
}

/// Campo numérico de uma métrica com botões − e + (TV-3, treino ao vivo).
///
/// - Toca no número = editar à mão (o campo é um [TextField] comum).
/// - − / + ajustam pelo passo da métrica e respeitam a faixa (ZONA 1–5, nunca
///   negativo).
/// - Métrica sem passo (PESO_CORPORAL) não deve usar este widget: a tela
///   mostra só o rótulo.
///
/// Cores, tamanhos e tipografia vêm só de tokens (regra de ouro do design).
class StepperMetrica extends StatelessWidget {
  const StepperMetrica({
    super.key,
    required this.codigo,
    required this.controlador,
    required this.rotulo,
    this.unidade,
    this.habilitado = true,
  });

  /// Código da métrica (ex.: 'CARGA_KG'), para escolher o passo e a faixa.
  final String codigo;

  /// Valor editável, compartilhado com o estado da série.
  final TextEditingController controlador;

  /// Rótulo de acessibilidade do campo (ex.: "Carga em kg").
  final String rotulo;

  /// Unidade curta para mostrar ao lado (ex.: "kg", "reps"). Opcional.
  final String? unidade;

  final bool habilitado;

  double get _passo => PassosMetrica.passo(codigo) ?? 1;

  (double, double) get _faixa =>
      PassosMetrica.faixa(codigo) ?? (0, double.infinity);

  void _ajustar(double delta) {
    final atual = _ler(controlador.text) ?? 0;
    final (min, max) = _faixa;
    final novo = (atual + delta).clamp(min, max);
    controlador.text = _formatar(novo);
    controlador.selection =
        TextSelection.collapsed(offset: controlador.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temStepper = PassosMetrica.passo(codigo) != null;

    final campo = Expanded(
      child: TextField(
        controller: controlador,
        enabled: habilitado,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        style: AppText.inputValue.copyWith(color: cores.textStrong),
        decoration: InputDecoration(
          isDense: true,
          hintText: '0',
          suffixText: unidade,
          suffixStyle: AppText.caption.copyWith(color: cores.textSecondary),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x8, vertical: AppSpacing.x10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            borderSide: BorderSide(color: cores.lineDefault),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            borderSide: BorderSide(color: cores.lineDefault),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 2),
          ),
        ),
      ),
    );

    if (!temStepper) {
      return Semantics(textField: true, label: rotulo, child: Row(children: [campo]));
    }

    return Semantics(
      label: rotulo,
      child: Row(
        children: [
          _BotaoPasso(
            icone: LucideIcons.minus,
            rotulo: 'Diminuir $rotulo',
            cores: cores,
            aoTocar: habilitado ? () => _ajustar(-_passo) : null,
          ),
          const SizedBox(width: AppSpacing.x6),
          campo,
          const SizedBox(width: AppSpacing.x6),
          _BotaoPasso(
            icone: LucideIcons.plus,
            rotulo: 'Aumentar $rotulo',
            cores: cores,
            aoTocar: habilitado ? () => _ajustar(_passo) : null,
          ),
        ],
      ),
    );
  }

  /// Lê o texto (vírgula ou ponto) como número, ou nulo se vazio/inválido.
  static double? _ler(String texto) {
    final limpo = texto.trim().replaceAll(',', '.');
    if (limpo.isEmpty) return null;
    return double.tryParse(limpo);
  }

  /// Formata o número de volta para texto: inteiro sem casas, fração com
  /// vírgula (padrão do app).
  static String _formatar(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }
}

/// Botão quadrado − / + do stepper, no tamanho de toque mínimo.
class _BotaoPasso extends StatelessWidget {
  const _BotaoPasso({
    required this.icone,
    required this.rotulo,
    required this.cores,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final AppColors cores;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: rotulo,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
        onTap: aoTocar,
        child: Container(
          width: AppSizes.campoSerie,
          height: AppSizes.campoSerie,
          decoration: BoxDecoration(
            color: cores.bgInput,
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            border: Border.all(color: cores.lineDefault),
          ),
          child: Icon(
            icone,
            size: AppSizes.iconeSm,
            color: aoTocar == null ? cores.iconMuted : cores.textStrong,
          ),
        ),
      ),
    );
  }
}
