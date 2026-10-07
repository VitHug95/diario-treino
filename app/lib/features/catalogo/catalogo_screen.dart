import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'catalogo_repository.dart';
import 'exercicio_resumo.dart';

/// Tela 8 do protótipo (ESCOLHER EXERCÍCIO): busca no catálogo (PBI-10).
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
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
    final filtro = ref.watch(catalogoFiltroProvider);
    final resultado = ref.watch(catalogoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercícios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Rotas.criarExercicio),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Novo'),
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
          _FiltroModalidade(
            selecionada: filtro.modalidade,
            aoSelecionar: (m) =>
                ref.read(catalogoFiltroProvider.notifier).definirModalidade(m),
          ),
          const SizedBox(height: AppSpacing.x8),
          Expanded(
            child: resultado.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  _Erro(aoTentarNovamente: () => ref.invalidate(catalogoProvider)),
              data: (itens) =>
                  itens.isEmpty ? const _EstadoVazio() : _ListaExercicios(itens: itens),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroModalidade extends StatelessWidget {
  const _FiltroModalidade({required this.selecionada, required this.aoSelecionar});

  final ModalidadeFiltro selecionada;
  final ValueChanged<ModalidadeFiltro> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
      child: Row(
        children: [
          for (final m in ModalidadeFiltro.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x8),
              child: ChoiceChip(
                label: Text(m.rotulo),
                selected: m == selecionada,
                showCheckmark: false,
                onSelected: (_) => aoSelecionar(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListaExercicios extends StatelessWidget {
  const _ListaExercicios({required this.itens});

  final List<ExercicioResumo> itens;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.x16),
      itemCount: itens.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.entreItens),
      itemBuilder: (context, i) => _CardExercicio(exercicio: itens[i]),
    );
  }
}

class _CardExercicio extends StatelessWidget {
  const _CardExercicio({required this.exercicio});

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
        onTap: () {
          // Seleção do exercício entra nas PBIs de ficha/sessão.
        },
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
                const _SeloMeu(),
                const SizedBox(width: AppSpacing.x8),
              ],
              Icon(LucideIcons.plus,
                  color: Theme.of(context).colorScheme.primary,
                  size: AppSizes.iconeMd),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeloMeu extends StatelessWidget {
  const _SeloMeu();

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
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
              color: cores.primaryOnTint,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
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
            Text('Que tal criar um exercício novo?',
                style: AppText.body.copyWith(color: cores.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x16),
            OutlinedButton.icon(
              onPressed: () => context.push(Rotas.criarExercicio),
              icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
              label: const Text('Criar exercício'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  const _Erro({required this.aoTentarNovamente});

  final VoidCallback aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
            const SizedBox(height: AppSpacing.x12),
            Text('Não foi possível carregar os exercícios.',
                style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x16),
            FilledButton(
              onPressed: aoTentarNovamente,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
