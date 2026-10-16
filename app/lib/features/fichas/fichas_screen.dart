import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../shared/acoes_cabecalho.dart';
import '../../shared/botao_tracejado.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/exercicio_resumo.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import '../inicio/inicio_logica.dart';
import '../sessao/sessao_repository.dart';
import 'dialogo_ficha.dart';
import 'editar_alvos_screen.dart';
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

  /// Plano de origem. Nulo = plano em uso (Início e Primeiro acesso abrem
  /// assim; sem plano, o estado vazio "CRIAR FICHA" monta o primeiro).
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

  /// Mudou ficha: atualiza este plano, a lista (contagens), o detalhe e a
  /// Início.
  void _invalidarPlanos() {
    ref.invalidate(_plano);
    ref.invalidate(planoAtivoProvider);
    ref.invalidate(planosProvider);
    ref.invalidate(planoDetalheProvider);
  }

  Future<void> _recarregar() async {
    _invalidarPlanos();
    await ref.read(_plano.future);
  }

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

  /// Primeira ficha, pelo estado vazio "CRIAR FICHA" (plano em uso, ainda sem
  /// fichas). Fica nesta tela para já adicionar exercícios.
  Future<void> _criarPrimeiraFicha(PlanoAtivo? plano) async {
    final dados = await dialogoFicha(context);
    if (dados == null) return;

    final repo = ref.read(fichasRepositoryProvider);
    try {
      // Sem plano ainda: garante um antes de adicionar a primeira ficha.
      final planoId = plano?.id ?? await repo.garantirPlano();
      await repo.adicionarFicha(
          planoId: planoId, nome: dados.nome, descricao: dados.descricao);
      await _recarregar();
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
    final temSessoes = await ref.read(fichaTemSessoesProvider(ficha.id).future);
    if (!mounted) return;
    final confirmar = await confirmarPerigo(
      context,
      titulo: 'Excluir ficha?',
      texto: textoExcluirFicha(ficha.nome, temSessoes: temSessoes),
      rotuloConfirmar: 'Excluir ficha',
    );
    if (!confirmar) return;

    try {
      await ref.read(fichasRepositoryProvider).excluirFicha(ficha.id);
      if (!mounted) return;
      // Confirmar volta ao plano (PBI-58). Marca a saída antes de recarregar,
      // para o plano sem a ficha não mostrar "Essa ficha não existe mais".
      _saindo = true;
      _invalidarPlanos();
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
          aoTentar: () => _recarregar(),
        ),
      ),
      data: (plano) {
        final fichas = plano?.treinos ?? const <TreinoResumo>[];
        final id = widget.fichaInicialId;

        // Sem fichas e sem ficha pedida: o único caminho é criar a primeira
        // (PBI-52; caminho do Primeiro acesso e do Robot).
        if (fichas.isEmpty && id == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Fichas')),
            body: EstadoVazio(
              icone: LucideIcons.clipboardList,
              titulo: 'Nenhuma ficha ainda',
              texto: 'Crie o Treino A para começar a montar sua rotina.',
              acao: FilledButton(
                onPressed: () => _criarPrimeiraFicha(plano),
                child: const Text('CRIAR FICHA'),
              ),
            ),
          );
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

  Future<void> _recarregar(WidgetRef ref) async {
    ref.invalidate(fichaDetalheProvider(treinoId));
    await ref.read(fichaDetalheProvider(treinoId).future);
  }

  /// Seletor com vários exercícios (PBI-49): adiciona na ordem escolhida. Se
  /// algum falhar, os outros ficam e o aviso diz quais não entraram.
  Future<void> _adicionar(BuildContext context, WidgetRef ref, String nomeFicha) async {
    final escolhidos = await Navigator.of(context).push<List<ExercicioResumo>>(
      MaterialPageRoute(builder: (_) => SelecionarExercicioScreen(destino: nomeFicha)),
    );
    if (escolhidos == null || escolhidos.isEmpty) return;

    final repo = ref.read(fichasRepositoryProvider);
    final falharam = <String>[];
    for (final e in escolhidos) {
      try {
        await repo.adicionarExercicio(treinoId: treinoId, exercicioId: e.id);
      } on FichasException {
        falharam.add(e.nome);
      }
    }
    await _recarregar(ref);
    if (falharam.isNotEmpty && context.mounted) {
      _erro(context, 'Não foi possível adicionar: ${falharam.join(', ')}. Tente de novo.');
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
                      // Sem a alça automática do web/desktop: era o "=" extra
                      // ao lado da lixeira (PBI-62). A alça é a do cartão. As
                      // ações "Mover para cima/baixo" vêm da própria lista
                      // (textos em core/localizacao/material_pt.dart).
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.all(AppSpacing.x16),
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
                aoTocar: () => _adicionar(context, ref, ficha.nome),
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

/// A ficha já tem sessões registradas? Decide o texto da confirmação de
/// excluir (PBI-58): com sessões, ela só sai do plano; sem, é apagada. Nulo
/// quando não deu para saber (sem rede): a tela usa o texto genérico.
final fichaTemSessoesProvider =
    FutureProvider.autoDispose.family<bool?, String>((ref, fichaId) async {
  try {
    final sessoes = await ref.read(sessaoRepositoryProvider).listarSessoes();
    return sessoes.any((s) => s.treinoId == fichaId);
  } catch (_) {
    return null;
  }
});

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
