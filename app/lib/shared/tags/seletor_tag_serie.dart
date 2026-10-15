import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'tag_serie.dart';

/// Chip da tag de série (TV-1), reusado nas telas de ficha, registro e detalhe.
///
/// - Modo leitura (`aoTocar == null`): VALIDA não renderiza nada; outras tags
///   mostram o chip colorido.
/// - Modo edição (`aoTocar != null`): mostra o rótulo (ou "Válida" em tom
///   secundário) com um ▾, e abre o seletor ao tocar.
///
/// Cores e tamanhos vêm só de tokens (regra de ouro do design system). O chip
/// tem rótulo de acessibilidade "Tag da série N: Rótulo" quando [rodada] é dado.
class ChipTagSerie extends StatelessWidget {
  const ChipTagSerie({
    super.key,
    required this.marcador,
    this.aoTocar,
    this.rodada,
  });

  /// Código do marcador atual (ex.: 'AQUECIMENTO').
  final String marcador;

  /// Callback para abrir o seletor. Nulo = modo leitura.
  final ValueChanged<String>? aoTocar;

  /// Número da série (1-based), para o rótulo de acessibilidade.
  final int? rodada;

  bool get _edicao => aoTocar != null;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final info = TagsSerie.info(marcador);
    final ehValida = TagsSerie.ehValida(marcador);

    // Modo leitura e Válida: nada aparece (critério do PDF).
    if (!_edicao && ehValida) return const SizedBox.shrink();

    final (fundo, borda, texto) = _cores(cores, info, ehValida);
    final rotuloSemantica = rodada != null
        ? 'Tag da série $rodada: ${info.rotulo}'
        : 'Tag da série: ${info.rotulo}';

    final conteudo = Container(
      constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(info.rotulo, style: AppText.caption.copyWith(color: texto)),
          if (_edicao) ...[
            const SizedBox(width: AppSpacing.x4),
            Icon(LucideIcons.chevronDown, size: AppSizes.iconeSm, color: texto),
          ],
        ],
      ),
    );

    if (!_edicao) {
      return Semantics(label: rotuloSemantica, child: conteudo);
    }

    return Semantics(
      button: true,
      label: rotuloSemantica,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () async {
          final escolhido = await abrirSeletorTagSerie(context, marcador);
          if (escolhido != null) aoTocar!(escolhido);
        },
        child: conteudo,
      ),
    );
  }

  /// (fundo, borda, texto) conforme a tag: neutra ou primary suave; "Válida" em
  /// edição fica em tom secundário discreto.
  (Color, Color, Color) _cores(AppColors cores, TagSerieInfo info, bool ehValida) {
    if (ehValida) {
      // Só acontece no modo edição (leitura já saiu acima): tom secundário.
      return (cores.bgInput, cores.lineDefault, cores.textSecondary);
    }
    if (info.primary) {
      return (cores.primaryTint, cores.primaryTint, cores.primaryText);
    }
    return (cores.bgInput, cores.lineDefault, cores.textSecondary);
  }
}

/// Abre o seletor de tag (lista de baixo pra cima) e devolve o código escolhido,
/// ou nulo se o usuário fechou sem escolher. As 10 opções mostram rótulo e
/// descrição; a atual vem marcada.
Future<String?> abrirSeletorTagSerie(BuildContext context, String atual) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final cores = AppColors.of(ctx);
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Largura máxima no web (regra do MAS/design).
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x8, 0, AppSpacing.x8, AppSpacing.x16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x8, AppSpacing.x4, AppSpacing.x8, AppSpacing.x12),
                  child: Text('Tag da série', style: AppText.titleS),
                ),
                for (final info in TagsSerie.lista)
                  _OpcaoTag(
                    info: info,
                    selecionada: info.codigo == atual,
                    cores: cores,
                    aoTocar: () => Navigator.of(ctx).pop(info.codigo),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _OpcaoTag extends StatelessWidget {
  const _OpcaoTag({
    required this.info,
    required this.selecionada,
    required this.cores,
    required this.aoTocar,
  });

  final TagSerieInfo info;
  final bool selecionada;
  final AppColors cores;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selecionada,
      label: info.rotulo,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        onTap: aoTocar,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x12, vertical: AppSpacing.x10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.rotulo, style: AppText.body),
                    const SizedBox(height: AppSpacing.x4),
                    Text(info.descricao,
                        style: AppText.caption
                            .copyWith(color: cores.textSecondary)),
                  ],
                ),
              ),
              if (selecionada)
                Icon(LucideIcons.check,
                    size: AppSizes.iconeSm, color: cores.primaryText),
            ],
          ),
        ),
      ),
    );
  }
}
