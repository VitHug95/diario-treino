import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/theme_tokens.dart';

/// Lápis e lixeira no topo de uma tela (PBI-58): renomear e excluir sem texto
/// solto no rodapé. Dois botões de 44 × 44 px com o fundo de campo.
///
/// [sobreCabecalhoEscuro] usa as cores do cabeçalho escuro (`bgHeader`); falso,
/// as do fundo da página. Os rótulos viram a dica e o nome do botão para a
/// semântica e o Robot ("Renomear plano", "Excluir ficha"...).
class AcoesRenomearExcluir extends StatelessWidget {
  const AcoesRenomearExcluir({
    super.key,
    required this.rotuloRenomear,
    required this.rotuloExcluir,
    required this.aoRenomear,
    required this.aoExcluir,
    this.sobreCabecalhoEscuro = true,
  });

  final String rotuloRenomear;
  final String rotuloExcluir;
  final VoidCallback aoRenomear;
  final VoidCallback aoExcluir;
  final bool sobreCabecalhoEscuro;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final fundo = sobreCabecalhoEscuro ? cores.bgHeaderInput : cores.bgInput;
    final corLapis = sobreCabecalhoEscuro ? cores.textOnHeader : cores.textStrong;
    final corLixeira = sobreCabecalhoEscuro ? cores.dangerOnHeader : cores.danger;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotaoQuadrado(
          icone: LucideIcons.pencil,
          cor: corLapis,
          fundo: fundo,
          rotulo: rotuloRenomear,
          aoTocar: aoRenomear,
        ),
        const SizedBox(width: AppSpacing.x8),
        _BotaoQuadrado(
          icone: LucideIcons.trash2,
          cor: corLixeira,
          fundo: fundo,
          rotulo: rotuloExcluir,
          aoTocar: aoExcluir,
        ),
      ],
    );
  }
}

class _BotaoQuadrado extends StatelessWidget {
  const _BotaoQuadrado({
    required this.icone,
    required this.cor,
    required this.fundo,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final Color cor;
  final Color fundo;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.touchMin,
      height: AppSizes.touchMin,
      child: IconButton(
        onPressed: aoTocar,
        tooltip: rotulo,
        icon: Icon(icone, size: AppSizes.iconeSm, color: cor),
        style: IconButton.styleFrom(
          backgroundColor: fundo,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
          ),
        ),
      ),
    );
  }
}
