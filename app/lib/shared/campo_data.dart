import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';

/// Campo que mostra um dia (dd/mm/aaaa) e abre o seletor de data ao tocar
/// (PBI-97). É o campo das quatro telas com data: nascimento, dia da medição e
/// dia do treino (registro e resumo).
///
/// - **O campo inteiro é o alvo do toque** (borda, rótulo, texto e ícone), com
///   no mínimo 44 px de altura. O ícone é só decoração.
/// - **Na web com a árvore de semântica ligada**, o toque pode chegar pelo nó de
///   semântica e não pelo canvas. Por isso o nó leva o próprio `onTap`: sem ele o
///   nó existe, mas a ação "tocar" não tem para onde ir e o toque se perde.
/// - Vazio mostra `dd/mm/aaaa` em cor de dica, não uma instrução.
class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.texto,
    required this.aoTocar,
  });

  final String rotulo;

  /// O dia já formatado (dd/mm/aaaa). Nulo ou vazio = ainda sem data.
  final String? texto;

  /// Nulo deixa o campo só de leitura (ex.: o dia de uma medição já gravada).
  final VoidCallback? aoTocar;

  static const formato = 'dd/mm/aaaa';

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final vazio = texto == null || texto!.isEmpty;
    final valorFalado = vazio ? 'sem data' : texto!;

    return Semantics(
      container: true,
      button: aoTocar != null,
      label:
          aoTocar == null
              ? '$rotulo: $valorFalado'
              : '$rotulo: $valorFalado. Toque para ${vazio ? 'escolher' : 'trocar'}',
      onTap: aoTocar,
      excludeSemantics: true,
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          child: InputDecorator(
            decoration: InputDecoration(labelText: rotulo),
            child: Row(
              children: [
                Icon(
                  LucideIcons.calendar,
                  size: AppSizes.iconeSm,
                  color: cores.iconMuted,
                ),
                const SizedBox(width: AppSpacing.x8),
                // Expanded: com fonte grande o texto quebra em vez de estourar a linha.
                Expanded(
                  child: Text(
                    vazio ? formato : texto!,
                    style:
                        vazio
                            ? AppText.inputValue.copyWith(
                              color: cores.textSecondary,
                            )
                            : AppText.inputValue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
