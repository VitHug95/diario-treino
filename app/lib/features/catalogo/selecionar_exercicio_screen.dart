import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/botao_tracejado.dart';
import '../../shared/estado_vazio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'catalogo_repository.dart';
import 'catalogo_screen.dart';
import 'criar_exercicio_screen.dart';
import 'exercicio_resumo.dart';

/// Tela 21 (PBI-49): "Adicionar exercícios". Seleção múltipla: cada linha
/// alterna entre escolhido e não escolhido, e o rodapé "Adicionar N
/// exercícios" devolve a lista via `Navigator.pop`, **na ordem em que foram
/// tocados** (`List<ExercicioResumo>`). Voltar pela seta devolve nulo.
///
/// [destino] aparece acima do título (a ficha ou o treino que recebe os
/// exercícios).
class SelecionarExercicioScreen extends ConsumerStatefulWidget {
  const SelecionarExercicioScreen({super.key, this.destino});

  final String? destino;

  @override
  ConsumerState<SelecionarExercicioScreen> createState() =>
      _SelecionarExercicioScreenState();
}

class _SelecionarExercicioScreenState
    extends ConsumerState<SelecionarExercicioScreen> {
  final _buscaController = TextEditingController();
  Timer? _debounce;

  /// Escolhidos, na ordem tocada. Ficam mesmo quando o filtro os esconde.
  final _escolhidos = <ExercicioResumo>[];

  /// Filtro de membro local: a busca vem toda do servidor e o membro filtra
  /// aqui, para a folha mostrar a contagem de cada opção.
  int? _membroId;

  @override
  void initState() {
    super.initState();
    // O filtro do catálogo é um provider global: pode ter sobrado a busca de
    // uma seleção anterior. Zera ao abrir, para começar mostrando todos.
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
    setState(() {}); // mostra ou esconde o botão de limpar
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(catalogoFiltroProvider.notifier).definirBusca(valor);
    });
  }

  void _limparBusca() {
    _debounce?.cancel();
    _buscaController.clear();
    ref.read(catalogoFiltroProvider.notifier).definirBusca('');
    setState(() {});
  }

  bool _escolhido(ExercicioResumo e) => _escolhidos.any((x) => x.id == e.id);

  void _alternar(ExercicioResumo e) {
    setState(() {
      if (_escolhido(e)) {
        _escolhidos.removeWhere((x) => x.id == e.id);
      } else {
        _escolhidos.add(e);
      }
    });
  }

  /// Cria um exercício e volta ao seletor com ele já marcado (critério 5).
  Future<void> _criarExercicio() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CriarExercicioScreen()),
    );
    if (id == null || id.isEmpty || !mounted) return;

    ref.invalidate(catalogoProvider);
    final exercicio = await ref.read(catalogoRepositoryProvider).buscarPorId(id);
    if (!mounted) return;
    if (exercicio != null) {
      setState(() {
        if (!_escolhido(exercicio)) _escolhidos.add(exercicio);
      });
    } else {
      // Não achou (caso raro): a lista atualizada mostra o novo para tocar.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercício criado. Toque nele para escolher.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final filtro = ref.watch(catalogoFiltroProvider);
    final resultado = ref.watch(catalogoProvider);
    final busca = filtro.busca.trim();

    // Contagem por membro sobre a busca atual (chave nula = "Todos").
    final todos = resultado.value ?? const <ExercicioResumo>[];
    final contagens = <int?, int>{null: todos.length};
    for (final e in todos) {
      if (e.membroId != null) contagens[e.membroId] = (contagens[e.membroId] ?? 0) + 1;
    }

    final n = _escolhidos.length;

    return Scaffold(
      appBar: AppBar(
        // Seta de voltar (44 px) devolve nulo: nada é adicionado. Sem "Fechar".
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft, size: AppSizes.iconeMd),
          tooltip: 'Voltar sem adicionar',
          constraints: const BoxConstraints(
              minWidth: AppSizes.touchMin, minHeight: AppSizes.touchMin),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.destino != null && widget.destino!.trim().isNotEmpty)
              Text(widget.destino!.toUpperCase(),
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
            Semantics(header: true, child: const Text('Adicionar exercícios')),
          ],
        ),
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
              decoration: InputDecoration(
                hintText: 'Buscar por nome',
                prefixIcon: const Icon(LucideIcons.search, size: AppSizes.iconeSm),
                suffixIcon: _buscaController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _limparBusca,
                        icon: const Icon(LucideIcons.x, size: AppSizes.iconeSm),
                        tooltip: 'Limpar busca',
                        constraints: const BoxConstraints(
                            minWidth: AppSizes.touchMin, minHeight: AppSizes.touchMin),
                      ),
              ),
            ),
          ),
          FiltroMembro(
            selecionado: _membroId,
            contagens: resultado.hasValue ? contagens : null,
            aoSelecionar: (id) => setState(() => _membroId = id),
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
              data: (lista) {
                final itens = _membroId == null
                    ? lista
                    : lista.where((e) => e.membroId == _membroId).toList();
                if (itens.isEmpty) {
                  // Sem resultado: um único "Criar", com o texto buscado.
                  return EstadoVazio(
                    icone: LucideIcons.dumbbell,
                    titulo: 'Nenhum exercício encontrado',
                    texto: 'Não achou o que procura? Crie um exercício novo.',
                    acao: FilledButton.icon(
                      onPressed: _criarExercicio,
                      icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                      label: Text(busca.isEmpty ? 'Criar exercício novo' : 'Criar "$busca"'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  // Primeira linha: criar exercício novo (tracejada).
                  itemCount: itens.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.entreItens),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return BotaoTracejado(
                          rotulo: 'Criar exercício novo', aoTocar: _criarExercicio);
                    }
                    final e = itens[i - 1];
                    return _ItemSelecionavel(
                      exercicio: e,
                      escolhido: _escolhido(e),
                      aoTocar: () => _alternar(e),
                    );
                  },
                );
              },
            ),
          ),
          // Rodapé fixo: adiciona os escolhidos, na ordem tocada.
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: cores.lineDivider)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.x16),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSizes.botaoPrincipal,
                  child: FilledButton(
                    onPressed: n == 0
                        ? null
                        : () => Navigator.of(context).pop(List<ExercicioResumo>.of(_escolhidos)),
                    child: Text(n == 0
                        ? 'ESCOLHA OS EXERCÍCIOS'
                        : 'ADICIONAR $n ${n == 1 ? 'EXERCÍCIO' : 'EXERCÍCIOS'}'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha do seletor: quadrado do membro, nome, "músculo · forma de medir",
/// "Meu" e o círculo de 44 px ("+" vazado ou "✓" cheio). A linha toda é um
/// botão que alterna, anunciado como "Adicionar X" ou "Remover X".
class _ItemSelecionavel extends StatelessWidget {
  const _ItemSelecionavel({
    required this.exercicio,
    required this.escolhido,
    required this.aoTocar,
  });

  final ExercicioResumo exercicio;
  final bool escolhido;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final esquema = Theme.of(context).colorScheme;
    final e = exercicio;
    final musculo = e.musculoNome ?? e.membroNome;
    final subtitulo = [
      if (musculo != null && musculo.isNotEmpty) musculo,
      e.formaDeMedir,
    ].join(' · ');

    return Semantics(
      button: true,
      toggled: escolhido,
      label: '${escolhido ? 'Remover' : 'Adicionar'} ${e.nome}',
      excludeSemantics: true,
      child: Material(
        color: escolhido ? cores.primaryTint : esquema.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: aoTocar,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: escolhido ? cores.primaryText : cores.lineDefault),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
            child: Row(
              children: [
                _QuadradoMembro(nome: e.membroNome),
                const SizedBox(width: AppSpacing.x12),
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
                  const SizedBox(width: AppSpacing.x8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
                    decoration: BoxDecoration(
                      color: cores.bgInput,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('Meu',
                        style: AppText.caption
                            .copyWith(color: cores.textStrong, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(width: AppSpacing.x8),
                // Círculo de estado: "+" vazado ou "✓" cheio.
                Container(
                  width: AppSizes.touchMin,
                  height: AppSizes.touchMin,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: escolhido ? esquema.primary : null,
                    border: escolhido ? null : Border.all(color: cores.primaryText, width: 1.5),
                  ),
                  child: Icon(escolhido ? LucideIcons.check : LucideIcons.plus,
                      size: AppSizes.iconeSm,
                      color: escolhido ? esquema.onPrimary : cores.primaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quadrado com as iniciais do membro (ex.: "PE" para Peito). Sem membro, "—".
class _QuadradoMembro extends StatelessWidget {
  const _QuadradoMembro({required this.nome});

  final String? nome;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final limpo = nome?.trim() ?? '';
    final texto = limpo.isEmpty
        ? '—'
        : limpo.substring(0, limpo.length < 2 ? limpo.length : 2).toUpperCase();
    return Container(
      width: AppSizes.touchMin,
      height: AppSizes.touchMin,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cores.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
      ),
      child: Text(texto, style: AppText.numeralS.copyWith(color: cores.textStrong)),
    );
  }
}
