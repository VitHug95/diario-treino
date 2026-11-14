import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../shared/acoes_cabecalho.dart';
import '../../shared/botao_tracejado.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/catalogo_repository.dart';
import '../catalogo/exercicio_resumo.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import '../inicio/inicio_logica.dart';
import '../sessao/sessao_repository.dart';
import 'bloco_conjugado.dart';
import 'dialogo_ficha.dart';
import 'editar_alvos_screen.dart';
import 'fichas_comandos.dart';
import 'fichas_repository.dart';
import 'plano_models.dart';

/// Tela 22 (PBI-57): edição de UMA ficha, a que foi aberta pelo detalhe do
/// plano. Sem as outras fichas, sem "Nova ficha" e sem botões de treinar:
/// criar ficha e treinar acontecem no plano (PBI-61).
///
/// [fichaInicialId]: id da ficha aberta (`?ficha=<id>`). Abrir a ficha nunca
/// inicia o treino (PBI-50). Id que não existe mais volta ao plano com o aviso
/// "Essa ficha não existe mais". Sem id, abre a primeira ficha do plano.
class FichasScreen extends ConsumerStatefulWidget {
  const FichasScreen({super.key, this.fichaInicialId, this.planoId});

  final String? fichaInicialId;

  /// Plano de origem. Nulo = plano em uso. Sem ficha para abrir, a tela volta
  /// ao plano (PBI-69): fichas só se criam no detalhe do plano.
  final String? planoId;

  @override
  ConsumerState<FichasScreen> createState() => _FichasScreenState();
}

class _FichasScreenState extends ConsumerState<FichasScreen> {
  /// Já saindo da tela (ficha excluída ou inexistente): não reage de novo
  /// quando o plano recarrega sem a ficha.
  bool _saindo = false;

  /// Fonte das fichas: o plano escolhido na lista ou, sem id, o plano em uso.
  FutureProvider<PlanoAtivo?> get _plano => widget.planoId == null
      ? planoAtivoProvider
      : planoPorIdProvider(widget.planoId!);

  /// Espera o plano recarregado. Quem grava ([fichasComandosProvider]) já
  /// avisou o plano, a lista, o detalhe e a Início (PBI-70).
  Future<void> _esperarPlano() => ref.read(_plano.future);

  /// Volta ao detalhe do plano de origem. Aberta direto (sem tela anterior),
  /// troca para o detalhe.
  void _voltarAoPlano() {
    // Navigator (e não o GoRouter) para funcionar também fora do roteador.
    final navegador = Navigator.of(context);
    if (navegador.canPop()) {
      navegador.pop();
    } else {
      final id = widget.planoId;
      context.go(id == null
          ? Rotas.planoDetalhe
          : '${Rotas.planoDetalhe}?id=${Uri.encodeQueryComponent(id)}');
    }
  }

  /// Ficha pedida não está no plano (excluída, link antigo): avisa e volta.
  void _fichaNaoExiste() {
    if (_saindo) return;
    _saindo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Essa ficha não existe mais')));
      _voltarAoPlano();
    });
  }

  /// Sem ficha para abrir (plano vazio, link sem `?ficha=`): volta ao plano,
  /// onde as fichas nascem (PBI-69). Não há mais estado vazio "Criar ficha"
  /// aqui, que era uma segunda tela vazia no caminho.
  void _semFichaParaAbrir() {
    if (_saindo) return;
    _saindo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _voltarAoPlano();
    });
  }

  Future<void> _renomear(TreinoResumo ficha) async {
    final dados = await dialogoFicha(context, inicial: ficha);
    if (dados == null) return;
    try {
      await ref.read(fichasComandosProvider).editarFicha(
          treinoId: ficha.id, nome: dados.nome, descricao: dados.descricao);
      await _esperarPlano();
    } on FichasException catch (e) {
      _erro(e.mensagem);
    }
  }

  Future<void> _excluir(TreinoResumo ficha) async {
    final temSessoes = await ref.read(fichaTemSessoesProvider(ficha.id).future);
    if (!mounted) return;
    final confirmar = await confirmarPerigo(
      context,
      titulo: 'Excluir ficha?',
      texto: textoExcluirFicha(ficha.nome, temSessoes: temSessoes),
      rotuloConfirmar: 'Excluir ficha',
    );
    if (!confirmar) return;

    // Confirmar volta ao plano (PBI-58). Marca a saída antes de gravar, porque
    // o comando já avisa o plano: sem a ficha, não pode mostrar "Essa ficha
    // não existe mais".
    _saindo = true;
    try {
      await ref.read(fichasComandosProvider).excluirFicha(ficha.id);
      if (!mounted) return;
      _voltarAoPlano();
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

    return planoAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: EstadoErro(
          mensagem: 'Não foi possível carregar a ficha.',
          aoTentar: () => ref.refresh(_plano),
        ),
      ),
      data: (plano) {
        final fichas = plano?.treinos ?? const <TreinoResumo>[];
        final id = widget.fichaInicialId;

        // Sem fichas e sem ficha pedida: nada a editar aqui (PBI-69).
        if (fichas.isEmpty && id == null) {
          _semFichaParaAbrir();
          return const Scaffold(body: SizedBox.shrink());
        }

        final ficha = id == null
            ? fichas.first
            : fichas.where((f) => f.id == id).firstOrNull;
        if (ficha == null || plano == null) {
          _fichaNaoExiste();
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CabecalhoFicha(
                plano: plano,
                ficha: ficha,
                aoVoltar: _voltarAoPlano,
                aoRenomear: () => _renomear(ficha),
                aoExcluir: () => _excluir(ficha),
              ),
              Expanded(child: _ListaExerciciosFicha(treinoId: ficha.id)),
            ],
          ),
        );
      },
    );
  }
}

/// Cabeçalho escuro da tela 22: seta para o plano, nome do plano, nome da
/// ficha (cabeçalho de semântica), resumo e lápis/lixeira (PBI-58).
class _CabecalhoFicha extends ConsumerWidget {
  const _CabecalhoFicha({
    required this.plano,
    required this.ficha,
    required this.aoVoltar,
    required this.aoRenomear,
    required this.aoExcluir,
  });

  final PlanoAtivo plano;
  final TreinoResumo ficha;
  final VoidCallback aoVoltar;
  final VoidCallback aoRenomear;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final qtd = ref.watch(fichaDetalheProvider(ficha.id)).maybeWhen(
          data: (d) => d.exercicios.length,
          orElse: () => null,
        );
    // "Último em" vem das sessões recentes, como no detalhe do plano.
    final ultima = ref.watch(sessoesRecentesProvider).maybeWhen(
          data: (s) => InicioLogica.ultimaVezPorFicha(s)[ficha.id],
          orElse: () => null,
        );
    final resumo = resumoFicha(qtdExercicios: qtd, ultimaVez: ultima);
    final descricao = ficha.descricao?.trim() ?? '';

    return Container(
      color: cores.bgHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x8, AppSpacing.x8, AppSpacing.margemCabecalho, AppSpacing.x20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: aoVoltar,
                    icon: Icon(LucideIcons.arrowLeft,
                        size: AppSizes.iconeMd, color: cores.textOnHeader),
                    tooltip: 'Voltar para ${plano.nome}',
                    constraints: const BoxConstraints(
                      minWidth: AppSizes.touchMin,
                      minHeight: AppSizes.touchMin,
                    ),
                  ),
                  const Spacer(),
                  AcoesRenomearExcluir(
                    rotuloRenomear: 'Renomear ficha',
                    rotuloExcluir: 'Excluir ficha',
                    aoRenomear: aoRenomear,
                    aoExcluir: aoExcluir,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.x12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plano.nome.toUpperCase(),
                        style: AppText.overline.copyWith(color: cores.textOnHeaderMuted)),
                    const SizedBox(height: AppSpacing.x4),
                    Semantics(
                      header: true,
                      child: Text(ficha.nome.toUpperCase(),
                          style: AppText.displayM.copyWith(color: cores.textOnHeader)),
                    ),
                    if (descricao.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x4),
                      Text(descricao,
                          style: AppText.body.copyWith(color: cores.textOnHeaderLabel)),
                    ],
                    const SizedBox(height: AppSpacing.x4),
                    Text(resumo,
                        style: AppText.caption.copyWith(color: cores.textOnHeaderMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "N exercícios · último em dd/mm" ou "· nunca feito". Sem a contagem
/// (carregando), só a parte da data.
String resumoFicha({required int? qtdExercicios, required DateTime? ultimaVez}) {
  final partes = <String>[
    if (qtdExercicios != null)
      '$qtdExercicios ${qtdExercicios == 1 ? 'exercício' : 'exercícios'}',
    ultimaVez == null
        ? 'nunca feito'
        : 'último em ${ultimaVez.day.toString().padLeft(2, '0')}/'
            '${ultimaVez.month.toString().padLeft(2, '0')}',
  ];
  return partes.join(' · ');
}

/// Exercícios da ficha: reordenar arrastando, remover e adicionar do catálogo.
class _ListaExerciciosFicha extends ConsumerWidget {
  const _ListaExerciciosFicha({required this.treinoId});

  final String treinoId;

  /// Espera a ficha recarregada. Quem grava ([fichasComandosProvider]) já
  /// avisou a ficha, o plano e o rascunho do registro (PBI-70).
  Future<void> _esperarFicha(WidgetRef ref) =>
      ref.read(fichaDetalheProvider(treinoId).future);

  /// Seletor com vários exercícios (PBI-49): adiciona na ordem escolhida. Se
  /// algum falhar, os outros ficam e o aviso diz quais não entraram.
  Future<void> _adicionar(
    BuildContext context,
    WidgetRef ref,
    String nomeFicha,
    Set<String> idsNaFicha,
  ) async {
    final escolhidos = await Navigator.of(context).push<List<ExercicioResumo>>(
      MaterialPageRoute(
        builder: (_) => SelecionarExercicioScreen(
          destino: nomeFicha,
          // PBI-74: não deixa escolher quem já está na ficha.
          idsIndisponiveis: idsNaFicha,
          rotuloIndisponivel: 'Já está na ficha',
        ),
      ),
    );
    if (escolhidos == null || escolhidos.isEmpty) return;

    final idsFalharam = await ref.read(fichasComandosProvider).adicionarExercicios(
        treinoId: treinoId, exercicioIds: escolhidos.map((e) => e.id).toList());
    await _esperarFicha(ref);
    final falharam = [
      for (final e in escolhidos)
        if (idsFalharam.contains(e.id)) e.nome,
    ];
    if (falharam.isNotEmpty && context.mounted) {
      _erro(context, 'Não foi possível adicionar: ${falharam.join(', ')}. Tente de novo.');
    }
  }

  Future<void> _remover(
      BuildContext context, WidgetRef ref, TreinoExercicioResumo te) async {
    try {
      await ref.read(fichasComandosProvider).removerExercicio(
          treinoId: treinoId, treinoExercicioId: te.id);
      await _esperarFicha(ref);
    } on FichasException catch (e) {
      if (context.mounted) _erro(context, e.mensagem);
    }
  }

  /// A tela de alvos grava pelo comando, que já atualiza a ficha.
  ///
  /// PBI-78: abre SEMPRE com o dado mais atual da ficha (lido do provider pelo
  /// id), nunca com um objeto capturado antes. Assim, mesmo um toque que chega
  /// enquanto a ficha ainda está recarregando após uma gravação não abre um
  /// editor "em branco" com o estado antigo. Enquanto o detalhe recarrega
  /// (AsyncLoading) ou se o exercício já não existe, o toque é ignorado.
  Future<void> _editarAlvos(
      BuildContext context, WidgetRef ref, TreinoExercicioResumo te) async {
    final detalhe = ref.read(fichaDetalheProvider(treinoId));
    // Ficha recarregando: ignora o toque (evita abrir com dado defasado).
    if (detalhe.isLoading) return;

    final atual = detalhe.value?.exercicios
        .where((e) => e.id == te.id)
        .firstOrNull;
    // Exercício saiu da ficha nesse meio-tempo: nada a editar.
    if (atual == null) return;

    await Navigator.of(context).push<ResultadoAlvos>(
      MaterialPageRoute(
        builder: (_) => EditarAlvosScreen(treinoId: treinoId, exercicio: atual),
      ),
    );
  }

  /// Reordena por item (PBI-101): o bloco se move inteiro, então a lista
  /// enviada nunca separa os membros.
  Future<void> _reordenar(
      WidgetRef ref, List<ItemFicha> itens, int de, int para) async {
    final lista = [...itens];
    if (para > de) para -= 1;
    final movido = lista.removeAt(de);
    lista.insert(para, movido);
    try {
      await ref.read(fichasComandosProvider).reordenarExercicios(
          treinoId: treinoId, treinoExercicioIds: _idsNaOrdem(lista));
    } on FichasException {
      // O comando recarrega mesmo com erro: a lista volta ao estado real.
    }
    await _esperarFicha(ref);
  }

  static List<String> _idsNaOrdem(List<ItemFicha> itens) => [
        for (final item in itens)
          ...switch (item) {
            ItemAvulso(:final exercicio) => [exercicio.id],
            ItemBloco(:final membros) => membros.map((m) => m.id),
          },
      ];

  /// "Juntar com…" no exercício avulso: há outro avulso, ou um bloco com vaga?
  static bool podeJuntar(List<ItemFicha> itens, TreinoExercicioResumo origem) =>
      itens.any((item) => switch (item) {
            ItemAvulso(:final exercicio) => exercicio.id != origem.id,
            ItemBloco(:final membros) => membros.length < BlocoFicha.maximoMembros,
          });

  /// "Adicionar exercício" no bloco: tem vaga e há algum avulso para entrar?
  static bool podeAdicionar(List<ItemFicha> itens, ItemBloco bloco) =>
      bloco.membros.length < BlocoFicha.maximoMembros && itens.any((i) => i is ItemAvulso);

  /// "Juntar {exercício} com…": escolhe os outros (bloco novo, que a API junta
  /// na posição do primeiro, na ordem da ficha) ou um bloco existente.
  Future<void> _juntarCom(BuildContext context, WidgetRef ref, List<ItemFicha> itens,
      TreinoExercicioResumo origem) async {
    final escolha = await escolherJuntar(context, origem: origem, itens: itens);
    if (escolha == null || !context.mounted) return;
    await _comBloco(context, ref, (c) async {
      switch (escolha) {
        case JuntarEmBlocoNovo(:final treinoExercicioIds, :final descansoSeg):
          await c.criarBloco(
              treinoId: treinoId,
              treinoExercicioIds: treinoExercicioIds,
              descansoSeg: descansoSeg);
        case EntrarNoBloco(:final bloco):
          await c.definirMembrosBloco(
              treinoId: treinoId,
              blocoId: bloco.id,
              treinoExercicioIds: [...bloco.treinoExercicioIds, origem.id]);
        case AdicionarAoBloco():
          return;
      }
    });
  }

  /// "Adicionar exercício" no cabeçalho do bloco: os escolhidos entram no fim.
  Future<void> _adicionarAoBloco(
      BuildContext context, WidgetRef ref, List<ItemFicha> itens, ItemBloco item) async {
    final escolha = await escolherAdicionarAoBloco(context, bloco: item, itens: itens);
    if (escolha is! AdicionarAoBloco || escolha.treinoExercicioIds.isEmpty) return;
    if (!context.mounted) return;
    await _definirMembros(context, ref, item.bloco,
        [...item.membros.map((m) => m.id), ...escolha.treinoExercicioIds]);
  }

  Future<void> _mudarDescansoBloco(
      BuildContext context, WidgetRef ref, BlocoFicha bloco) async {
    final escolha = await pedirDescansoBloco(context,
        rotuloConfirmar: 'Salvar', inicial: bloco.descansoSeg);
    if (escolha == null || !context.mounted) return;
    await _comBloco(context, ref, (c) => c.definirDescansoBloco(
        treinoId: treinoId, blocoId: bloco.id, descansoSeg: escolha.segundos));
  }

  Future<void> _desfazerBloco(
      BuildContext context, WidgetRef ref, BlocoFicha bloco) async {
    if (!await confirmarDesfazerBloco(context)) return;
    if (!context.mounted) return;
    await _comBloco(
        context, ref, (c) => c.desfazerBloco(treinoId: treinoId, blocoId: bloco.id));
  }

  /// Membros novos, na ordem dada (mover dentro do bloco ou tirar dele). Com
  /// menos de 2, o servidor desfaz o bloco.
  Future<void> _definirMembros(
      BuildContext context, WidgetRef ref, BlocoFicha bloco, List<String> ids) =>
      _comBloco(context, ref, (c) => c.definirMembrosBloco(
          treinoId: treinoId, blocoId: bloco.id, treinoExercicioIds: ids));

  Future<void> _comBloco(BuildContext context, WidgetRef ref,
      Future<void> Function(FichasComandos c) acao) async {
    try {
      await acao(ref.read(fichasComandosProvider));
      await _esperarFicha(ref);
    } on FichasException catch (e) {
      if (context.mounted) _erro(context, e.mensagem);
    }
  }

  Future<void> _acaoDoMembro(BuildContext context, WidgetRef ref, ItemBloco item,
      int posicao, _AcaoMembro acao) async {
    final ids = item.membros.map((m) => m.id).toList();
    switch (acao) {
      case _AcaoMembro.subir when posicao > 0:
        ids.insert(posicao - 1, ids.removeAt(posicao));
        await _definirMembros(context, ref, item.bloco, ids);
      case _AcaoMembro.descer when posicao < ids.length - 1:
        ids.insert(posicao + 1, ids.removeAt(posicao));
        await _definirMembros(context, ref, item.bloco, ids);
      case _AcaoMembro.tirar:
        ids.removeAt(posicao);
        await _definirMembros(context, ref, item.bloco, ids);
      case _AcaoMembro.remover:
        await _remover(context, ref, item.membros[posicao]);
      default:
        return;
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
          onPressed: () => ref.refresh(fichaDetalheProvider(treinoId)),
          child: const Text('Tentar de novo'),
        ),
      ),
      data: (ficha) {
        // Um item por exercício avulso e um por bloco conjugado (PBI-101).
        final itens = ficha.itens;
        return Column(
          children: [
            Expanded(
              child: itens.isEmpty
                  ? _SemExercicios(cores: cores)
                  : ReorderableListView.builder(
                      // Sem a alça automática do web/desktop: era o "=" extra
                      // ao lado da lixeira (PBI-62). A alça é a do cartão. As
                      // ações "Mover para cima/baixo" vêm da própria lista
                      // (textos em core/localizacao/material_pt.dart).
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      itemCount: itens.length,
                      onReorder: (de, para) => _reordenar(ref, itens, de, para),
                      itemBuilder: (context, i) {
                        return switch (itens[i]) {
                          ItemAvulso(exercicio: final te) => _CardExercicioFicha(
                              key: ValueKey(te.id),
                              exercicio: te,
                              indice: i,
                              aoEditar: () => _editarAlvos(context, ref, te),
                              aoRemover: () => _remover(context, ref, te),
                              aoJuntar: podeJuntar(itens, te)
                                  ? () => _juntarCom(context, ref, itens, te)
                                  : null,
                            ),
                          final ItemBloco item => _CardBlocoFicha(
                              key: ValueKey('bloco-${item.bloco.id}'),
                              item: item,
                              indice: i,
                              aoEditar: (te) => _editarAlvos(context, ref, te),
                              aoAcaoMembro: (posicao, acao) =>
                                  _acaoDoMembro(context, ref, item, posicao, acao),
                              aoMudarDescanso: () =>
                                  _mudarDescansoBloco(context, ref, item.bloco),
                              aoDesfazer: () => _desfazerBloco(context, ref, item.bloco),
                              aoAdicionar: podeAdicionar(itens, item)
                                  ? () => _adicionarAoBloco(context, ref, itens, item)
                                  : null,
                            ),
                        };
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: BotaoTracejado(
                rotulo: 'Adicionar exercício à ficha',
                aoTocar: () => _adicionar(context, ref, ficha.nome,
                    {for (final te in ficha.exercicios) te.exercicioId}),
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
    this.aoJuntar,
  });

  final TreinoExercicioResumo exercicio;
  final int indice;
  final VoidCallback aoEditar;
  final VoidCallback aoRemover;

  /// "Juntar com…" (PBI-101). Nulo = não há com quem juntar.
  final VoidCallback? aoJuntar;

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
            // Pouco padding à esquerda: a alça de 36 px já dá o respiro.
            padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.paddingCardCompacto,
                AppSpacing.paddingCardCompacto, AppSpacing.paddingCardCompacto),
            child: Row(
              children: [
                // Alça de mover: 36 × 44, grip de seis pontos (PBI-62).
                ReorderableDragStartListener(
                  index: indice,
                  child: Semantics(
                    label: 'Arrastar para reordenar ${exercicio.nome}',
                    child: SizedBox(
                      width: 36,
                      height: AppSizes.touchMin,
                      child: Icon(LucideIcons.gripVertical,
                          color: cores.iconMuted, size: AppSizes.iconeSm),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x8),
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
                const SizedBox(width: AppSpacing.x8),
                if (aoJuntar != null) ...[
                  _BotaoJuntar(nome: exercicio.nome, aoTocar: aoJuntar!),
                  const SizedBox(width: AppSpacing.x4),
                ],
                // Remover: 44 × 44, fundo vermelho suave, só a lixeira.
                SizedBox(
                  width: AppSizes.touchMin,
                  height: AppSizes.touchMin,
                  child: IconButton(
                    onPressed: aoRemover,
                    tooltip: 'Remover ${exercicio.nome} da ficha',
                    icon: Icon(LucideIcons.trash2,
                        size: AppSizes.iconeSm, color: cores.danger),
                    style: IconButton.styleFrom(
                      backgroundColor: cores.dangerSoft,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
                      ),
                    ),
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

/// "Juntar com…" (PBI-101): ícone de elo, 44 × 44. Abre a escolha de com quais
/// exercícios (ou em qual bloco) juntar.
class _BotaoJuntar extends StatelessWidget {
  const _BotaoJuntar({required this.nome, required this.aoTocar});

  final String nome;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return SizedBox(
      width: AppSizes.touchMin,
      height: AppSizes.touchMin,
      child: IconButton(
        onPressed: aoTocar,
        tooltip: 'Juntar $nome com outro exercício',
        icon: Icon(LucideIcons.link, size: AppSizes.iconeSm, color: cores.primaryText),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: cores.lineDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
          ),
        ),
      ),
    );
  }
}

/// Ações de um exercício dentro do bloco (menu de cada linha).
enum _AcaoMembro { subir, descer, tirar, remover }

/// Cartão do bloco conjugado (PBI-101): barra lateral, cabeçalho "Conjugado ·
/// 4 rodadas · descanso 30 s" com a alça (move o bloco inteiro), "Descanso" e
/// "Desfazer bloco", e os exercícios empilhados com o resumo dos alvos (sem o
/// descanso, que é do bloco).
class _CardBlocoFicha extends StatelessWidget {
  const _CardBlocoFicha({
    super.key,
    required this.item,
    required this.indice,
    required this.aoEditar,
    required this.aoAcaoMembro,
    required this.aoMudarDescanso,
    required this.aoDesfazer,
    this.aoAdicionar,
  });

  final ItemBloco item;
  final int indice;
  final void Function(TreinoExercicioResumo) aoEditar;
  final void Function(int posicao, _AcaoMembro acao) aoAcaoMembro;
  final VoidCallback aoMudarDescanso;
  final VoidCallback aoDesfazer;

  /// "Adicionar exercício" ao bloco. Nulo = bloco cheio ou sem avulso livre.
  final VoidCallback? aoAdicionar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final bloco = item.bloco;
    final membros = item.membros;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      child: Semantics(
        container: true,
        label: rotuloFaladoBloco(bloco, membros.length),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra lateral: marca o que é feito junto.
                Container(width: AppSpacing.x6, color: cores.primaryText),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.x4, AppSpacing.x8,
                        AppSpacing.x8, AppSpacing.x8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ReorderableDragStartListener(
                              index: indice,
                              child: Semantics(
                                label: 'Arrastar para reordenar o bloco',
                                child: SizedBox(
                                  width: 36,
                                  height: AppSizes.touchMin,
                                  child: Icon(LucideIcons.gripVertical,
                                      color: cores.iconMuted, size: AppSizes.iconeSm),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x4),
                            Expanded(
                              child: ExcludeSemantics(
                                child: Text(textoCabecalhoBloco(bloco),
                                    style: AppText.label.copyWith(color: cores.primaryText)),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: AppSpacing.x8,
                          children: [
                            if (aoAdicionar != null)
                              _AcaoCabecalhoBloco(
                                icone: LucideIcons.plus,
                                rotulo: 'Adicionar exercício',
                                aoTocar: aoAdicionar!,
                              ),
                            _AcaoCabecalhoBloco(
                              icone: LucideIcons.timer,
                              rotulo: 'Descanso',
                              aoTocar: aoMudarDescanso,
                            ),
                            _AcaoCabecalhoBloco(
                              icone: LucideIcons.unlink,
                              rotulo: 'Desfazer bloco',
                              aoTocar: aoDesfazer,
                            ),
                          ],
                        ),
                        for (var p = 0; p < membros.length; p++) ...[
                          Divider(height: AppSpacing.x8, color: cores.lineDivider),
                          _LinhaMembroBloco(
                            exercicio: membros[p],
                            primeiro: p == 0,
                            ultimo: p == membros.length - 1,
                            aoEditar: () => aoEditar(membros[p]),
                            aoAcao: (acao) => aoAcaoMembro(p, acao),
                          ),
                        ],
                      ],
                    ),
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

class _AcaoCabecalhoBloco extends StatelessWidget {
  const _AcaoCabecalhoBloco({required this.icone, required this.rotulo, required this.aoTocar});

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return TextButton.icon(
      onPressed: aoTocar,
      icon: Icon(icone, size: AppSizes.iconeSm, color: cores.textStrong),
      label: Text(rotulo, style: AppText.label.copyWith(color: cores.textStrong)),
      style: TextButton.styleFrom(
        minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
      ),
    );
  }
}

/// Um exercício dentro do bloco: toque edita os alvos; o menu move dentro do
/// bloco, tira do bloco ou remove da ficha.
class _LinhaMembroBloco extends StatelessWidget {
  const _LinhaMembroBloco({
    required this.exercicio,
    required this.primeiro,
    required this.ultimo,
    required this.aoEditar,
    required this.aoAcao,
  });

  final TreinoExercicioResumo exercicio;
  final bool primeiro;
  final bool ultimo;
  final VoidCallback aoEditar;
  final void Function(_AcaoMembro) aoAcao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: aoEditar,
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(exercicio.nome, style: AppText.titleS),
                    const SizedBox(height: AppSpacing.x4),
                    _ResumoAlvo(exercicio: exercicio, cores: cores, mostrarDescanso: false),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: AppSizes.touchMin,
          height: AppSizes.touchMin,
          child: PopupMenuButton<_AcaoMembro>(
            tooltip: 'Opções de ${exercicio.nome}',
            icon: Icon(LucideIcons.moreVertical, size: AppSizes.iconeSm, color: cores.iconMuted),
            padding: EdgeInsets.zero,
            onSelected: aoAcao,
            itemBuilder: (_) => [
              if (!primeiro)
                const PopupMenuItem(value: _AcaoMembro.subir, child: Text('Mover para cima')),
              if (!ultimo)
                const PopupMenuItem(value: _AcaoMembro.descer, child: Text('Mover para baixo')),
              const PopupMenuItem(value: _AcaoMembro.tirar, child: Text('Tirar do bloco')),
              PopupMenuItem(
                value: _AcaoMembro.remover,
                child: Text('Remover da ficha', style: AppText.body.copyWith(color: cores.danger)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Linha-resumo dos alvos no card. Sem alvo definido, convida a configurar.
///
/// Mostra a faixa de volume (TV-2) e a unidade de cada métrica, no mesmo padrão
/// do resumo do editor (PBI-79). A unidade vem do catálogo de métricas (por
/// código); enquanto ele não chegou, cai no nome da métrica.
class _ResumoAlvo extends ConsumerWidget {
  const _ResumoAlvo({
    required this.exercicio,
    required this.cores,
    this.mostrarDescanso = true,
  });

  final TreinoExercicioResumo exercicio;
  final AppColors cores;

  /// Falso dentro do bloco conjugado (PBI-101): o descanso é do bloco.
  final bool mostrarDescanso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Unidade por código (ex.: kg, rep, s). Sem o catálogo ainda, usa o nome.
    final metricas = ref.watch(metricasProvider).value;
    String unidadeDe(String codigo, String nomeFallback) {
      final u = metricas?.where((m) => m.codigo == codigo).firstOrNull?.unidade;
      // "-" (peso corporal) não é unidade exibível.
      if (u == null) return nomeFallback.toLowerCase();
      return u == '-' ? '' : u;
    }

    final partes = <String>['${exercicio.rodadas} ${exercicio.rodadas == 1 ? 'série' : 'séries'}'];

    // Volume: faixa "8 a 12 rep" (TV-2) ou alvo único "10 rep".
    if (alvo.volumeAlvo != null) {
      final unidadeVol = unidadeDe(alvo.volumeMetricaCodigo, alvo.volumeMetricaNome);
      final volume = formatarVolumeAlvo(alvo.volumeAlvo, alvo.volumeAlvoMax, unidadeVol);
      if (volume.isNotEmpty) partes.add(volume);
    }

    // Intensidade: "65 kg". Peso corporal (unidade vazia) não entra.
    if (alvo.intensidadeAlvo != null) {
      final unidadeInt = unidadeDe(alvo.intensidadeMetricaCodigo, alvo.intensidadeMetricaNome);
      final valor = _num(alvo.intensidadeAlvo!);
      partes.add(unidadeInt.isEmpty ? valor : '$valor $unidadeInt');
    }

    var texto = partes.join(' · ');
    if (mostrarDescanso && exercicio.descansoSeg != null) {
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
            // Só o título: a ação é o "Adicionar exercício à ficha" abaixo
            // (PBI-57, sem textos sobre iniciar treino).
            Text('Ficha sem exercícios',
                style: AppText.title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// _EstadoVazio e _ErroCarregar extraídos para shared/ (PBI-51).
// fichaTemSessoesProvider foi para sessao_repository.dart (PBI-70), junto das
// outras leituras de sessão que o mapa de invalidação atualiza.

/// Texto da confirmação de "Excluir ficha", conforme a ficha tenha sessões.
String textoExcluirFicha(String nome, {required bool? temSessoes}) {
  return switch (temSessoes) {
    true => 'Essa ficha já tem sessões registradas, então ela sai do plano '
        'mas o histórico e o gráfico continuam.',
    false => 'A ficha "$nome" e os exercícios dela serão apagados. '
        'Ela ainda não tem treinos registrados.',
    null => 'A ficha "$nome" sai da lista. '
        'Os treinos já registrados com esta ficha continuam no seu histórico.',
  };
}

// Botão tracejado e diálogo de ficha extraídos para shared/botao_tracejado.dart
// e fichas/dialogo_ficha.dart (PBI-46), para o detalhe do plano reaproveitar.
