import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'fichas_repository.dart';
import 'plano_models.dart';

/// Tela 5 do protótipo (FICHAS): abas por ficha, nome editável, nova ficha e
/// arquivar. A lista de exercícios de cada ficha chega no PBI-13.
class FichasScreen extends ConsumerStatefulWidget {
  const FichasScreen({super.key});

  @override
  ConsumerState<FichasScreen> createState() => _FichasScreenState();
}

class _FichasScreenState extends ConsumerState<FichasScreen> {
  int _selecionada = 0;

  Future<void> _recarregar() async {
    ref.invalidate(planoAtivoProvider);
    await ref.read(planoAtivoProvider.future);
  }

  Future<void> _novaFicha(PlanoAtivo? plano) async {
    final dados = await _dialogoFicha(context);
    if (dados == null) return;

    final repo = ref.read(fichasRepositoryProvider);
    try {
      // Sem plano ainda: garante um antes de adicionar a primeira ficha.
      final planoId = plano?.id ?? await repo.garantirPlano();
      await repo.adicionarFicha(
          planoId: planoId, nome: dados.nome, descricao: dados.descricao);
      await _recarregar();
      // Seleciona a última (a recém-criada).
      final atual = ref.read(planoAtivoProvider).value;
      if (atual != null && atual.treinos.isNotEmpty) {
        setState(() => _selecionada = atual.treinos.length - 1);
      }
    } on FichasException catch (e) {
      _erro(e.mensagem);
    }
  }

  Future<void> _renomear(TreinoResumo ficha) async {
    final dados = await _dialogoFicha(context, inicial: ficha);
    if (dados == null) return;
    try {
      await ref.read(fichasRepositoryProvider).editarFicha(
          treinoId: ficha.id, nome: dados.nome, descricao: dados.descricao);
      await _recarregar();
    } on FichasException catch (e) {
      _erro(e.mensagem);
    }
  }

  Future<void> _arquivar(TreinoResumo ficha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar ficha?'),
        content: Text(
            'A ficha "${ficha.nome}" sai da lista, mas o histórico de treinos dela continua.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(fichasRepositoryProvider).arquivarFicha(ficha.id);
      setState(() => _selecionada = 0);
      await _recarregar();
    } on FichasException catch (e) {
      _erro(e.mensagem);
    }
  }

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final planoAsync = ref.watch(planoAtivoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichas'),
        actions: [
          TextButton.icon(
            onPressed: () => _novaFicha(planoAsync.value),
            icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
            label: const Text('Nova ficha'),
          ),
          const SizedBox(width: AppSpacing.x8),
        ],
      ),
      body: planoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErroCarregar(aoTentar: _recarregar),
        data: (plano) {
          final fichas = plano?.treinos ?? const <TreinoResumo>[];
          if (fichas.isEmpty) {
            return _EstadoVazio(aoCriar: () => _novaFicha(plano));
          }
          final indice = _selecionada.clamp(0, fichas.length - 1);
          return _ConteudoFichas(
            fichas: fichas,
            selecionada: indice,
            aoSelecionar: (i) => setState(() => _selecionada = i),
            aoRenomear: () => _renomear(fichas[indice]),
            aoArquivar: () => _arquivar(fichas[indice]),
          );
        },
      ),
    );
  }
}

/// Conteúdo quando há fichas: abas segmentadas + detalhe da ficha selecionada.
class _ConteudoFichas extends StatelessWidget {
  const _ConteudoFichas({
    required this.fichas,
    required this.selecionada,
    required this.aoSelecionar,
    required this.aoRenomear,
    required this.aoArquivar,
  });

  final List<TreinoResumo> fichas;
  final int selecionada;
  final ValueChanged<int> aoSelecionar;
  final VoidCallback aoRenomear;
  final VoidCallback aoArquivar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final ficha = fichas[selecionada];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Abas por ficha (dinâmicas, N fichas).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Row(
            children: [
              for (var i = 0; i < fichas.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.x8),
                  child: ChoiceChip(
                    label: Text(_rotuloAba(fichas[i])),
                    selected: i == selecionada,
                    showCheckmark: false,
                    onSelected: (_) => aoSelecionar(i),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NOME DA FICHA',
                        style: AppText.overline.copyWith(color: cores.textSecondary)),
                    const SizedBox(height: AppSpacing.x4),
                    Text(ficha.nome, style: AppText.displayS),
                    if (ficha.descricao != null && ficha.descricao!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x4),
                      Text(ficha.descricao!,
                          style: AppText.body.copyWith(color: cores.textSecondary)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: aoRenomear,
                icon: const Icon(LucideIcons.pencil, size: AppSizes.iconeSm),
                tooltip: 'Renomear ficha',
              ),
              IconButton(
                onPressed: aoArquivar,
                icon: const Icon(LucideIcons.archive, size: AppSizes.iconeSm),
                tooltip: 'Arquivar ficha',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        // Lista de exercícios da ficha: chega no PBI-13.
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.listChecks, size: 40, color: cores.iconMuted),
                  const SizedBox(height: AppSpacing.x12),
                  Text('Os exercícios da ficha entram em breve.',
                      style: AppText.body.copyWith(color: cores.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _rotuloAba(TreinoResumo f) => f.nome.length <= 12 ? f.nome : f.nome.substring(0, 12);
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({required this.aoCriar});
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clipboardList, size: 48, color: cores.iconMuted),
            const SizedBox(height: AppSpacing.x12),
            Text('Nenhuma ficha ainda', style: AppText.title),
            const SizedBox(height: AppSpacing.x8),
            Text('Crie o Treino A para começar a montar sua rotina.',
                style: AppText.body.copyWith(color: cores.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x16),
            FilledButton(onPressed: aoCriar, child: const Text('CRIAR FICHA')),
          ],
        ),
      ),
    );
  }
}

class _ErroCarregar extends StatelessWidget {
  const _ErroCarregar({required this.aoTentar});
  final Future<void> Function() aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Não foi possível carregar as fichas.', style: AppText.title),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: () => aoTentar(), child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}

/// Resultado do diálogo de criar/editar ficha.
class _DadosFicha {
  const _DadosFicha(this.nome, this.descricao);
  final String nome;
  final String? descricao;
}

/// Diálogo com nome e descrição. [inicial] preenche para edição.
Future<_DadosFicha?> _dialogoFicha(BuildContext context, {TreinoResumo? inicial}) {
  final nome = TextEditingController(text: inicial?.nome ?? '');
  final descricao = TextEditingController(text: inicial?.descricao ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<_DadosFicha>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(inicial == null ? 'Nova ficha' : 'Renomear ficha'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: A'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: AppSpacing.x12),
            TextFormField(
              controller: descricao,
              decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)', hintText: 'Ex.: Peito e tríceps'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(ctx, _DadosFicha(nome.text.trim(), descricao.text.trim()));
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}
