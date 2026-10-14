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
import 'membro.dart';

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
  void initState() {
    super.initState();
    // Começa sempre do zero: o filtro é um provider global e o campo de busca
    // abre vazio, então o estado antigo não pode "fantasmar" a lista.
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
          FiltroMembro(
            selecionado: filtro.membroId,
            aoSelecionar: (id) =>
                ref.read(catalogoFiltroProvider.notifier).definirMembro(id),
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

/// Chips de filtro por membro (PBI-31): "Todos" + os 8 membros na ordem do
/// `GET /membros`, com rolagem horizontal. Reaproveitado pelo catálogo e pelo
/// seletor de exercício. `selecionado` nulo = "Todos".
class FiltroMembro extends ConsumerWidget {
  const FiltroMembro({
    super.key,
    required this.selecionado,
    required this.aoSelecionar,
  });

  final int? selecionado;
  final ValueChanged<int?> aoSelecionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membrosAsync = ref.watch(membrosProvider);

    return membrosAsync.when(
      // Enquanto carrega/erro, pelo menos o "Todos" para não deixar vazio.
      loading: () => _Chips(membros: const [], selecionado: null, aoSelecionar: aoSelecionar),
      error: (_, __) =>
          _Chips(membros: const [], selecionado: null, aoSelecionar: aoSelecionar),
      data: (membros) =>
          _Chips(membros: membros, selecionado: selecionado, aoSelecionar: aoSelecionar),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.membros,
    required this.selecionado,
    required this.aoSelecionar,
  });

  final List<Membro> membros;
  final int? selecionado;
  final ValueChanged<int?> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: selecionado == null,
              showCheckmark: false,
              onSelected: (_) => aoSelecionar(null),
            ),
          ),
          for (final m in membros)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.x8),
              child: ChoiceChip(
                label: Text(m.nome),
                selected: m.id == selecionado,
                showCheckmark: false,
                onSelected: (_) => aoSelecionar(m.id),
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
      if (e.classificacao.isNotEmpty) e.classificacao,
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
