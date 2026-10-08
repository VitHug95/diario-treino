import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'catalogo_repository.dart';
import 'exercicio_resumo.dart';

/// Tela 8 do protótipo (ESCOLHER EXERCÍCIO): seletor que reaproveita a busca do
/// catálogo (PBI-10) e devolve o exercício escolhido via `Navigator.pop`.
class SelecionarExercicioScreen extends ConsumerStatefulWidget {
  const SelecionarExercicioScreen({super.key});

  @override
  ConsumerState<SelecionarExercicioScreen> createState() =>
      _SelecionarExercicioScreenState();
}

class _SelecionarExercicioScreenState
    extends ConsumerState<SelecionarExercicioScreen> {
  final _buscaController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  void _aoDigitar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(catalogoFiltroProvider.notifier).definirBusca(valor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final filtro = ref.watch(catalogoFiltroProvider);
    final resultado = ref.watch(catalogoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher exercício'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x16, AppSpacing.x16, AppSpacing.x16, AppSpacing.x8),
            child: TextField(
              controller: _buscaController,
              onChanged: _aoDigitar,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Buscar por nome',
                prefixIcon: Icon(LucideIcons.search, size: AppSizes.iconeSm),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
            child: Row(
              children: [
                for (final m in ModalidadeFiltro.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.x8),
                    child: ChoiceChip(
                      label: Text(m.rotulo),
                      selected: m == filtro.modalidade,
                      showCheckmark: false,
                      onSelected: (_) =>
                          ref.read(catalogoFiltroProvider.notifier).definirModalidade(m),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          Expanded(
            child: resultado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(catalogoProvider),
                  child: const Text('Tentar de novo'),
                ),
              ),
              data: (itens) => itens.isEmpty
                  ? Center(
                      child: Text('Nenhum exercício encontrado.',
                          style: AppText.body.copyWith(color: cores.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      itemCount: itens.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.entreItens),
                      itemBuilder: (context, i) =>
                          _ItemSelecionavel(exercicio: itens[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSelecionavel extends StatelessWidget {
  const _ItemSelecionavel({required this.exercicio});

  final ExercicioResumo exercicio;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final e = exercicio;
    final subtitulo = [
      if (e.grupoMuscular != null && e.grupoMuscular!.isNotEmpty) e.grupoMuscular!,
      e.formaDeMedir,
    ].join(' · ');

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Devolve o id do exercício escolhido.
        onTap: () => Navigator.of(context).pop(e.id),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.nome, style: AppText.title),
                    const SizedBox(height: AppSpacing.x4),
                    Text(subtitulo,
                        style: AppText.caption.copyWith(color: cores.textSecondary)),
                  ],
                ),
              ),
              if (e.proprio) ...[
                Semantics(
                  label: 'Exercício criado por você',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
                    decoration: BoxDecoration(
                      color: cores.primaryTint,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('Meu',
                        style: AppText.caption.copyWith(
                            color: cores.primaryOnTint, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: AppSpacing.x8),
              ],
              Icon(LucideIcons.plus,
                  color: Theme.of(context).colorScheme.primary, size: AppSizes.iconeMd),
            ],
          ),
        ),
      ),
    );
  }
}
