import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
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
              error: (e, _) => EstadoErro(
                mensagem: 'Não foi possível carregar os exercícios.',
                aoTentar: () => ref.refresh(catalogoProvider),
              ),
              data: (itens) => itens.isEmpty
                  ? EstadoVazio(
                      icone: LucideIcons.dumbbell,
                      titulo: 'Nenhum exercício encontrado',
                      texto: 'Que tal criar um exercício novo?',
                      acao: OutlinedButton.icon(
                        onPressed: () => context.push(Rotas.criarExercicio),
                        icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                        label: const Text('Criar exercício'),
                      ),
                    )
                  : _ListaExercicios(itens: itens),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtro por membro (PBI-31, revisado na PBI-54): um campo "Músculo" que abre
/// uma folha de baixo com "Todos" + os membros do `GET /membros` em lista
/// vertical — sem rolagem lateral de chips, que escondia Core/Cardio/Mobilidade.
/// Reaproveitado pelo catálogo e pelo seletor de exercício (mesma API).
/// `selecionado` nulo = "Todos".
class FiltroMembro extends ConsumerWidget {
  const FiltroMembro({
    super.key,
    required this.selecionado,
    required this.aoSelecionar,
    this.contagens,
  });

  final int? selecionado;
  final ValueChanged<int?> aoSelecionar;

  /// Quantos exercícios cada opção mostraria (chave nula = "Todos"), exibido
  /// na folha (PBI-49). Nulo = sem contagem, como no catálogo.
  final Map<int?, int>? contagens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Enquanto `GET /membros` carrega ou falha, trata como lista vazia: o campo
    // mostra só "Todos" (sem travar o filtro), como no comportamento antigo.
    final membros =
        ref.watch(membrosProvider).maybeWhen(data: (m) => m, orElse: () => const <Membro>[]);

    final cores = AppColors.of(context);
    final selecionadoMembro =
        membros.where((m) => m.id == selecionado).cast<Membro?>().firstOrNull;
    final ativo = selecionadoMembro != null;
    final valor = selecionadoMembro?.nome ?? 'Todos';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
      child: Semantics(
        button: true,
        label: 'Filtrar por músculo: $valor',
        child: Material(
          color: ativo ? cores.primaryTint : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.campoForm),
            onTap: () => _abrirFolha(context, membros),
            child: Container(
              height: AppSizes.botaoSecundario, // 48
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: ativo ? cores.primaryText : cores.lineDefault,
                ),
                borderRadius: BorderRadius.circular(AppRadius.campoForm),
              ),
              child: Row(
                children: [
                  Text('Músculo',
                      style: AppText.caption.copyWith(color: cores.textSecondary)),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(
                    child: Text(
                      valor,
                      style: AppText.title.copyWith(
                        color: ativo ? cores.primaryText : null,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.chevronDown,
                      size: AppSizes.iconeSm,
                      color: ativo ? cores.primaryText : cores.iconMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFolha(BuildContext context, List<Membro> membros) async {
    final escolhido = await showModalBottomSheet<_EscolhaMembro>(
      context: context,
      showDragHandle: true,
      builder: (_) => _FolhaFiltroMembro(
          membros: membros, selecionado: selecionado, contagens: contagens),
    );
    // null = fechou sem escolher (arrastou/toque fora): mantém o filtro atual.
    if (escolhido != null) aoSelecionar(escolhido.id);
  }
}

/// Resultado da folha. Embrulha o id (que pode ser nulo = "Todos") para
/// distinguir "escolheu Todos" de "fechou sem escolher" (null do showModal).
class _EscolhaMembro {
  const _EscolhaMembro(this.id);
  final int? id;
}

/// Folha de baixo com a lista de opções de filtro: "Todos" + os membros. Uma
/// opção por linha (54 px), a atual em destaque com check. Escolher fecha e
/// devolve a opção. Grupo de seleção única para a semântica.
class _FolhaFiltroMembro extends StatelessWidget {
  const _FolhaFiltroMembro({
    required this.membros,
    required this.selecionado,
    this.contagens,
  });

  final List<Membro> membros;
  final int? selecionado;
  final Map<int?, int>? contagens;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return SafeArea(
      child: Semantics(
        container: true,
        label: 'Filtrar por músculo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x16, AppSpacing.x4, AppSpacing.x16, AppSpacing.x8),
              child: Text('FILTRAR POR MÚSCULO',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _OpcaoFiltro(
                    nome: 'Todos',
                    selecionada: selecionado == null,
                    contagem: contagens?[null],
                    aoTocar: () => Navigator.pop(context, const _EscolhaMembro(null)),
                  ),
                  for (final m in membros)
                    _OpcaoFiltro(
                      nome: m.nome,
                      selecionada: m.id == selecionado,
                      contagem: contagens == null ? null : (contagens![m.id] ?? 0),
                      aoTocar: () => Navigator.pop(context, _EscolhaMembro(m.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma linha da folha de filtro (54 px). Selecionada: texto azul + check.
class _OpcaoFiltro extends StatelessWidget {
  const _OpcaoFiltro({
    required this.nome,
    required this.selecionada,
    required this.aoTocar,
    this.contagem,
  });

  final String nome;
  final bool selecionada;
  final VoidCallback aoTocar;
  final int? contagem;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selecionada,
      button: true,
      child: InkWell(
        onTap: aoTocar,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: AppText.title.copyWith(
                    color: selecionada ? cores.primaryText : null,
                    fontWeight: selecionada ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (contagem != null) ...[
                Text('$contagem',
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
                const SizedBox(width: AppSpacing.x12),
              ],
              // Espaço fixo do check, para a contagem não pular de lugar.
              SizedBox(
                width: AppSizes.iconeSm,
                child: selecionada
                    ? Icon(LucideIcons.check,
                        size: AppSizes.iconeSm, color: cores.primaryText)
                    : null,
              ),
            ],
          ),
        ),
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


