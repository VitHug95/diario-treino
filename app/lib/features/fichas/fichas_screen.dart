import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/flags.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/botao_tracejado.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import '../sessao/iniciar_treino_ao_vivo.dart';
import 'dialogo_ficha.dart';
import 'editar_alvos_screen.dart';
import 'fichas_repository.dart';
import 'plano_models.dart';

/// Tela 5 do protótipo (FICHAS): abas por ficha, nome editável, nova ficha e
/// arquivar. A lista de exercícios de cada ficha chega no PBI-13.
///
/// [fichaInicialId] (PBI-50): id da ficha a abrir selecionada. Vem do cartão da
/// tela Início via `/fichas?ficha=<id>` — abrir a ficha nunca inicia o treino.
/// Id inexistente ou nulo cai na primeira ficha.
class FichasScreen extends ConsumerStatefulWidget {
  const FichasScreen({super.key, this.fichaInicialId, this.planoId});

  final String? fichaInicialId;

  /// Plano aberto a partir da lista de planos (PBI-45). Nulo = plano em uso,
  /// como antes (Início e Primeiro acesso continuam abrindo assim).
  final String? planoId;

  @override
  ConsumerState<FichasScreen> createState() => _FichasScreenState();
}

class _FichasScreenState extends ConsumerState<FichasScreen> {
  int _selecionada = 0;

  /// Garante que a resolução do [fichaInicialId] para o índice aconteça uma vez
  /// só, quando o plano terminar de carregar (e não a cada rebuild).
  bool _fichaInicialResolvida = false;

  /// Resolve o índice da ficha pedida pelo parâmetro de rota. Id inexistente
  /// (ficha removida, link antigo) cai na primeira ficha, sem erro.
  void _resolverFichaInicial(List<TreinoResumo> fichas) {
    if (_fichaInicialResolvida) return;
    _fichaInicialResolvida = true;
    final id = widget.fichaInicialId;
    if (id == null || fichas.isEmpty) return;
    final i = fichas.indexWhere((f) => f.id == id);
    if (i > 0) _selecionada = i;
  }

  /// Fonte das fichas: o plano escolhido na lista ou, sem id, o plano em uso.
  FutureProvider<PlanoAtivo?> get _plano => widget.planoId == null
      ? planoAtivoProvider
      : planoPorIdProvider(widget.planoId!);

  Future<void> _recarregar() async {
    // Mudou ficha: atualiza este plano, a lista (contagens) e a Início.
    ref.invalidate(_plano);
    ref.invalidate(planoAtivoProvider);
    ref.invalidate(planosProvider);
    ref.invalidate(planoDetalheProvider);
    await ref.read(_plano.future);
  }

  Future<void> _novaFicha(PlanoAtivo? plano) async {
    final dados = await dialogoFicha(context);
    if (dados == null) return;

    final repo = ref.read(fichasRepositoryProvider);
    try {
      // Sem plano ainda: garante um antes de adicionar a primeira ficha.
      final planoId = plano?.id ?? await repo.garantirPlano();
      await repo.adicionarFicha(
          planoId: planoId, nome: dados.nome, descricao: dados.descricao);
      await _recarregar();
      // Seleciona a última (a recém-criada).
      final atual = ref.read(_plano).value;
      if (atual != null && atual.treinos.isNotEmpty) {
        setState(() => _selecionada = atual.treinos.length - 1);
      }
    } on FichasException catch (e) {
      _erro(e.mensagem);
    }
  }

  Future<void> _renomear(TreinoResumo ficha) async {
    final dados = await dialogoFicha(context, inicial: ficha);
    if (dados == null) return;
    try {
      await ref.read(fichasRepositoryProvider).editarFicha(
          treinoId: ficha.id, nome: dados.nome, descricao: dados.descricao);
      await _recarregar();
    } on FichasException catch (e) {
      _erro(e.mensagem);
    }
  }

  Future<void> _excluir(TreinoResumo ficha) async {
    final confirmar = await confirmarPerigo(
      context,
      titulo: 'Excluir ficha?',
      texto: 'A ficha "${ficha.nome}" sai da lista. '
          'Os treinos já registrados com esta ficha continuam no seu histórico.',
      rotuloConfirmar: 'Excluir ficha',
    );
    if (!confirmar) return;

    try {
      await ref.read(fichasRepositoryProvider).excluirFicha(ficha.id);
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
    final planoAsync = ref.watch(_plano);

    // "Nova ficha" na AppBar só quando já existe ao menos uma ficha. Sem
    // fichas, o único caminho é o botão "CRIAR FICHA" do estado vazio (PBI-52).
    final temFichas = (planoAsync.value?.treinos ?? const []).isNotEmpty;

    // Aberta pela lista de planos, o título é o nome do plano (PBI-45).
    final titulo = widget.planoId == null
        ? 'Fichas'
        : (planoAsync.value?.nome ?? 'Plano');

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          if (temFichas) ...[
            TextButton.icon(
              onPressed: () => _novaFicha(planoAsync.value),
              icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
              label: const Text('Nova ficha'),
            ),
            const SizedBox(width: AppSpacing.x8),
          ],
        ],
      ),
      body: planoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => EstadoErro(
          mensagem: 'Não foi possível carregar as fichas.',
          aoTentar: () => _recarregar(),
        ),
        data: (plano) {
          final fichas = plano?.treinos ?? const <TreinoResumo>[];
          if (fichas.isEmpty) {
            return EstadoVazio(
              icone: LucideIcons.clipboardList,
              titulo: 'Nenhuma ficha ainda',
              texto: 'Crie o Treino A para começar a montar sua rotina.',
              acao: FilledButton(
                onPressed: () => _novaFicha(plano),
                child: const Text('CRIAR FICHA'),
              ),
            );
          }
          _resolverFichaInicial(fichas);
          final indice = _selecionada.clamp(0, fichas.length - 1);
          return _ConteudoFichas(
            fichas: fichas,
            selecionada: indice,
            aoSelecionar: (i) => setState(() => _selecionada = i),
            aoRenomear: () => _renomear(fichas[indice]),
            aoExcluir: () => _excluir(fichas[indice]),
          );
        },
      ),
    );
  }
}

/// Conteúdo quando há fichas: abas segmentadas + detalhe da ficha selecionada.
class _ConteudoFichas extends ConsumerWidget {
  const _ConteudoFichas({
    required this.fichas,
    required this.selecionada,
    required this.aoSelecionar,
    required this.aoRenomear,
    required this.aoExcluir,
  });

  final List<TreinoResumo> fichas;
  final int selecionada;
  final ValueChanged<int> aoSelecionar;
  final VoidCallback aoRenomear;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final ficha = fichas[selecionada];

    // Habilita iniciar/registrar só quando a ficha tem exercícios (PBI-52).
    // Enquanto o detalhe carrega ou falha, trata como "sem exercícios" para não
    // deixar iniciar um treino vazio.
    final detalhe = ref.watch(fichaDetalheProvider(ficha.id));
    final temExercicios = detalhe.maybeWhen(
      data: (d) => d.exercicios.isNotEmpty,
      orElse: () => false,
    );

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
              Semantics(
                label: 'Mais ações da ficha',
                button: true,
                child: IconButton(
                  onPressed: () => _abrirAcoesFicha(
                    context,
                    aoRenomear: aoRenomear,
                    aoExcluir: aoExcluir,
                  ),
                  icon: const Icon(LucideIcons.moreHorizontal, size: AppSizes.iconeMd),
                  tooltip: 'Mais ações da ficha',
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.touchMin,
                    minHeight: AppSizes.touchMin,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: AppSizes.botaoPrincipal,
                child: FilledButton.icon(
                  // Sem exercícios: desabilitado (não dá para iniciar vazio).
                  onPressed: !temExercicios
                      ? null
                      : () {
                          // Flag TV-3: inicia o treino ao vivo (tela 14) série
                          // por série; desligada, mantém o registro de uma vez.
                          if (treinoAoVivoHabilitado) {
                            iniciarTreinoAoVivoDaFicha(
                              context,
                              ref,
                              treinoId: ficha.id,
                              treinoNome: ficha.nome,
                            );
                          } else {
                            context.push(
                              Rotas.registrarSessao,
                              extra: RegistrarSessaoArgs(
                                  treinoId: ficha.id, treinoNome: ficha.nome),
                            );
                          }
                        },
                  icon: const Icon(LucideIcons.play, size: AppSizes.iconeSm),
                  label: const Text('INICIAR TREINO AGORA'),
                ),
              ),
              const SizedBox(height: AppSpacing.entreItens),
              // Ação secundária sem borda: registrar um treino já feito.
              TextButton.icon(
                onPressed: !temExercicios
                    ? null
                    : () => context.push(
                          Rotas.registrarSessao,
                          extra: RegistrarSessaoArgs(
                              treinoId: ficha.id,
                              treinoNome: ficha.nome,
                              registroPosterior: true),
                        ),
                icon: const Icon(LucideIcons.clipboardCheck, size: AppSizes.iconeSm),
                label: const Text('Registrar treino já feito'),
              ),
              // Ficha vazia: explica por que os botões estão desabilitados.
              if (!temExercicios) ...[
                const SizedBox(height: AppSpacing.x4),
                Text('Adicione exercícios para iniciar.',
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x16),
        Expanded(child: _ListaExerciciosFicha(treinoId: ficha.id)),
      ],
    );
  }

  String _rotuloAba(TreinoResumo f) => f.nome.length <= 12 ? f.nome : f.nome.substring(0, 12);
}

/// Exercícios da ficha: reordenar arrastando, remover e adicionar do catálogo.
class _ListaExerciciosFicha extends ConsumerWidget {
  const _ListaExerciciosFicha({required this.treinoId});

  final String treinoId;

  Future<void> _recarregar(WidgetRef ref) async {
    ref.invalidate(fichaDetalheProvider(treinoId));
    await ref.read(fichaDetalheProvider(treinoId).future);
  }

  Future<void> _adicionar(BuildContext context, WidgetRef ref) async {
    final exercicioId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SelecionarExercicioScreen()),
    );
    if (exercicioId == null) return;
    try {
      await ref.read(fichasRepositoryProvider).adicionarExercicio(
          treinoId: treinoId, exercicioId: exercicioId);
      await _recarregar(ref);
    } on FichasException catch (e) {
      if (context.mounted) _erro(context, e.mensagem);
    }
  }

  Future<void> _remover(
      BuildContext context, WidgetRef ref, TreinoExercicioResumo te) async {
    try {
      await ref.read(fichasRepositoryProvider).removerExercicio(
          treinoId: treinoId, treinoExercicioId: te.id);
      await _recarregar(ref);
    } on FichasException catch (e) {
      if (context.mounted) _erro(context, e.mensagem);
    }
  }

  Future<void> _editarAlvos(
      BuildContext context, WidgetRef ref, TreinoExercicioResumo te) async {
    final resultado = await Navigator.of(context).push<ResultadoAlvos>(
      MaterialPageRoute(
        builder: (_) => EditarAlvosScreen(treinoId: treinoId, exercicio: te),
      ),
    );
    // Salvou ou removeu: recarrega a ficha para refletir os alvos atualizados.
    if (resultado != null) await _recarregar(ref);
  }

  Future<void> _reordenar(
      WidgetRef ref, List<TreinoExercicioResumo> itens, int de, int para) async {
    final lista = [...itens];
    if (para > de) para -= 1;
    final movido = lista.removeAt(de);
    lista.insert(para, movido);
    try {
      await ref.read(fichasRepositoryProvider).reordenarExercicios(
          treinoId: treinoId, treinoExercicioIds: lista.map((e) => e.id).toList());
      await _recarregar(ref);
    } on FichasException {
      await _recarregar(ref); // recarrega para refletir o estado real
    }
  }

  void _erro(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final detalhe = ref.watch(fichaDetalheProvider(treinoId));

    return detalhe.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: FilledButton(
          onPressed: () => ref.invalidate(fichaDetalheProvider(treinoId)),
          child: const Text('Tentar de novo'),
        ),
      ),
      data: (ficha) {
        final itens = ficha.exercicios;
        return Column(
          children: [
            Expanded(
              child: itens.isEmpty
                  ? _SemExercicios(cores: cores)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16),
                      itemCount: itens.length,
                      onReorder: (de, para) => _reordenar(ref, itens, de, para),
                      itemBuilder: (context, i) {
                        final te = itens[i];
                        return _CardExercicioFicha(
                          key: ValueKey(te.id),
                          exercicio: te,
                          indice: i,
                          aoEditar: () => _editarAlvos(context, ref, te),
                          aoRemover: () => _remover(context, ref, te),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: BotaoTracejado(
                rotulo: 'Adicionar exercício à ficha',
                aoTocar: () => _adicionar(context, ref),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardExercicioFicha extends StatelessWidget {
  const _CardExercicioFicha({
    super.key,
    required this.exercicio,
    required this.indice,
    required this.aoEditar,
    required this.aoRemover,
  });

  final TreinoExercicioResumo exercicio;
  final int indice;
  final VoidCallback aoEditar;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final subtitulo = [
      if (exercicio.grupoMuscular != null && exercicio.grupoMuscular!.isNotEmpty)
        exercicio.grupoMuscular!,
      exercicio.modalidade,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: aoEditar,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: cores.lineDefault),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            padding: const EdgeInsets.all(AppSpacing.paddingCard),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: indice,
                  child: Semantics(
                    label: 'Arrastar para reordenar',
                    child: Icon(LucideIcons.gripVertical,
                        color: cores.iconMuted, size: AppSizes.iconeSm),
                  ),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercicio.nome, style: AppText.title),
                      const SizedBox(height: AppSpacing.x4),
                      Text(subtitulo,
                          style: AppText.caption.copyWith(color: cores.textSecondary)),
                      const SizedBox(height: AppSpacing.x6),
                      _ResumoAlvo(exercicio: exercicio, cores: cores),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: aoRemover,
                  icon: Icon(LucideIcons.trash2,
                      size: AppSizes.iconeSm, color: cores.danger),
                  tooltip: 'Remover da ficha',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha-resumo dos alvos no card. Sem alvo definido, convida a configurar.
class _ResumoAlvo extends StatelessWidget {
  const _ResumoAlvo({required this.exercicio, required this.cores});

  final TreinoExercicioResumo exercicio;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    final alvo = exercicio.alvo;
    if (alvo == null) {
      return Row(
        children: [
          Icon(LucideIcons.sliders, size: AppSizes.iconeSm, color: cores.primaryText),
          const SizedBox(width: AppSpacing.x6),
          Flexible(
            child: Text('Definir séries e alvos',
                style: AppText.caption.copyWith(color: cores.primaryText)),
          ),
        ],
      );
    }

    final partes = <String>['${exercicio.rodadas} ${exercicio.rodadas == 1 ? 'série' : 'séries'}'];
    if (alvo.volumeAlvo != null) {
      partes.add('${_num(alvo.volumeAlvo!)} ${alvo.volumeMetricaNome.toLowerCase()}');
    }
    if (alvo.intensidadeAlvo != null) {
      partes.add('${_num(alvo.intensidadeAlvo!)} ${alvo.intensidadeMetricaNome.toLowerCase()}');
    }
    var texto = partes.join(' · ');
    if (exercicio.descansoSeg != null) {
      texto = '$texto · ${exercicio.descansoSeg} s';
    }

    return Text(texto,
        style: AppText.caption.copyWith(color: cores.textStrong));
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
}

class _SemExercicios extends StatelessWidget {
  const _SemExercicios({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.listChecks, size: 40, color: cores.iconMuted),
            const SizedBox(height: AppSpacing.x12),
            Text('Ficha sem exercícios',
                style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x8),
            Text('Adicione exercícios do catálogo abaixo.',
                style: AppText.body.copyWith(color: cores.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// _EstadoVazio e _ErroCarregar extraídos para shared/ (PBI-51).

/// Folha de baixo com as ações da ficha: renomear e excluir (PBI-52). Cada
/// linha tem 54 px de altura, para alvo de toque confortável.
Future<void> _abrirAcoesFicha(
  BuildContext context, {
  required VoidCallback aoRenomear,
  required VoidCallback aoExcluir,
}) async {
  final cores = AppColors.of(context);
  final acao = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 54,
            child: ListTile(
              leading: const Icon(LucideIcons.pencil, size: AppSizes.iconeSm),
              title: Text('Renomear ficha', style: AppText.body),
              onTap: () => Navigator.pop(ctx, 'renomear'),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListTile(
              leading: Icon(LucideIcons.trash2,
                  size: AppSizes.iconeSm, color: cores.danger),
              title: Text('Excluir ficha',
                  style: AppText.body.copyWith(color: cores.danger)),
              onTap: () => Navigator.pop(ctx, 'excluir'),
            ),
          ),
        ],
      ),
    ),
  );

  if (acao == 'renomear') {
    aoRenomear();
  } else if (acao == 'excluir') {
    aoExcluir();
  }
}

// Botão tracejado e diálogo de ficha extraídos para shared/botao_tracejado.dart
// e fichas/dialogo_ficha.dart (PBI-46), para o detalhe do plano reaproveitar.
