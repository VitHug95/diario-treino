import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Aviso curto de confirmação (PBI-75): uma pílula arredondada que aparece,
/// anuncia a mensagem e some sozinha em ~2 s. Não tem ação e não é a "barra
/// preta" padrão do Material — usa a cor de realce do tema (`primaryTint`),
/// nunca preto.
///
/// Use para confirmar algo que já aconteceu e não exige resposta
/// (ex.: "Ficha criada"). Quando o aviso precisa de ação (desfazer, ver) ou
/// comunica erro, use outro componente — ver `docs/DESIGN.md`.
///
/// Regras de comportamento:
/// - flutua acima da navegação inferior, sem cobrir o botão principal;
/// - dois avisos não empilham: limpa o anterior antes de mostrar;
/// - `liveRegion` para o leitor de tela anunciar sem roubar o foco.
void mostrarAviso(BuildContext context, String mensagem) {
  final cores = AppColors.of(context);
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Semantics(
        liveRegion: true,
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(color: cores.primaryOnTint),
        ),
      ),
      backgroundColor: cores.primaryTint,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      elevation: 0,
      shape: const StadiumBorder(),
      // Acima da navegação inferior; margem lateral generosa para a pílula não
      // ocupar a largura toda e parecer um "pop" pequeno.
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x24,
        AppSpacing.x8,
        AppSpacing.x24,
        AppSizes.navInferior + AppSpacing.x8,
      ),
    ));
}
