import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'catalogo_repository.dart';
import 'catalogo_screen.dart';
import 'criar_exercicio_screen.dart';
import 'exercicio_resumo.dart';

/// Tela 8 do protótipo (ESCOLHER EXERCÍCIO): seletor que reaproveita a busca do
/// catálogo (PBI-10) e devolve o exercício escolhido via `Navigator.pop`.
///
/// Por padrão devolve só o id (`String`), como o PBI-13 precisa. Com
/// [retornarCompleto] devolve o [ExercicioResumo] inteiro (PBI-17, para montar
/// a série com as métricas do exercício).
class SelecionarExercicioScreen extends ConsumerStatefulWidget {
  const SelecionarExercicioScreen({super.key, this.retornarCompleto = false});

  final bool retornarCompleto;

  @override
  ConsumerState<SelecionarExercicioScreen> createState() =>
      _SelecionarExercicioScreenState();
}

class _SelecionarExercicioScreenState
    extends ConsumerState<SelecionarExercicioScreen> {
  final _buscaController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // O filtro é um provider global (compartilhado com o catálogo), então pode
    // ter sobrado a busca de uma seleção anterior. Zera ao abrir, para o
    // seletor sempre começar mostrando todos — como o campo vazio sugere.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(catalogoFiltroProvider.notifier).limpar();
    });
  }

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

  /// Abre a tela de criar exercício. Ao voltar com o id criado, resolve o
  /// [ExercicioResumo] e fecha o seletor devolvendo-o já selecionado — no
  /// mesmo formato que a seleção normal (id ou objeto completo).
  Future<void> _criarExercicio() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CriarExercicioScreen()),
    );
    if (id == null || id.isEmpty || !mounted) return;

    if (!widget.retornarCompleto) {
      // Fichas (PBI-13) só precisam do id.
      Navigator.of(context).pop(id);
      return;
    }

    // Registro (PBI-17) precisa do objeto completo: busca o recém-criado.
    final exercicio = await ref.read(catalogoRepositoryProvider).buscarPorId(id);
    if (!mounted) return;
    if (exercicio != null) {
      Navigator.of(context).pop(exercicio);
    } else {
      // Não achou (caso raro): mantém o seletor aberto com a lista atualizada.
      ref.invalidate(catalogoProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercício criado. Toque para selecionar.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          FiltroMembro(
            selecionado: filtro.membroId,
            aoSelecionar: (id) =>
                ref.read(catalogoFiltroProvider.notifier).definirMembro(id),
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
                  ? _EstadoVazio(
                      busca: filtro.busca,
                      aoCriar: _criarExercicio,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      itemCount: itens.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.entreItens),
                      itemBuilder: (context, i) => _ItemSelecionavel(
                        exercicio: itens[i],
                        retornarCompleto: widget.retornarCompleto,
                      ),
                    ),
            ),
          ),
          // Atalho sempre visível para criar um exercício fora do catálogo.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x16, AppSpacing.x8, AppSpacing.x16, AppSpacing.x16),
              child: OutlinedButton.icon(
                onPressed: _criarExercicio,
                icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                label: const Text('Criar exercício novo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vazio da busca: sugere criar o exercício que não foi encontrado,
/// aproveitando o texto digitado para dar contexto ("Criar '{busca}'").
class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({required this.busca, required this.aoCriar});

  final String busca;
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final buscaLimpa = busca.trim();
    final rotulo =
        buscaLimpa.isEmpty ? 'Criar exercício novo' : 'Criar "$buscaLimpa"';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.dumbbell, size: 48, color: cores.iconMuted),
            const SizedBox(height: AppSpacing.x12),
            Text('Nenhum exercício encontrado',
                style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x8),
            Text('Não achou o que procura? Crie um exercício novo.',
                style: AppText.body.copyWith(color: cores.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x16),
            FilledButton.icon(
              onPressed: aoCriar,
              icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
              label: Text(rotulo),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemSelecionavel extends StatelessWidget {
  const _ItemSelecionavel({
    required this.exercicio,
    required this.retornarCompleto,
  });

  final ExercicioResumo exercicio;
  final bool retornarCompleto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final e = exercicio;
    final subtitulo = [
      if (e.classificacao.isNotEmpty) e.classificacao,
      e.formaDeMedir,
    ].join(' · ');

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        // Devolve o id (PBI-13) ou o exercício completo (PBI-17).
        onTap: () => Navigator.of(context).pop(retornarCompleto ? e : e.id),
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
