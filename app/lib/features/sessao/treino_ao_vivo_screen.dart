import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../shared/botao_tracejado.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/progresso/grafico_exercicio.dart';
import '../../shared/tags/seletor_tag_serie.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/exercicio_resumo.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import '../progresso/progresso_repository.dart';
import 'descanso_controller.dart';
import 'sessao_edicao.dart';
import 'sessao_models.dart';
import 'sessao_repository.dart';
import 'stepper_metrica.dart';
import 'treino_ao_vivo_controller.dart';
import 'widgets_ao_vivo.dart';

/// Tela 14 do protótipo: treino ao vivo (TV-3). Cabeçalho com cronômetro vivo e
/// contador de séries, um card por exercício (barra de progresso + status) e os
/// botões de finalizar e sair. Tocar num card abre a tela do exercício (TV-4).
class TreinoAoVivoScreen extends ConsumerWidget {
  const TreinoAoVivoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(treinoAoVivoControllerProvider);

    if (estado == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Treino')),
        body: const Center(child: Text('Nenhum treino em andamento.')),
      );
    }

    // PBI-63: sai só por Finalizar ou Descartar. O voltar do sistema não sai,
    // só lembra o caminho. O treino segue salvo no aparelho e a Início mostra
    // "Continuar treino".
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
              content: Text('Para sair, finalize ou descarte o treino.')));
      },
      child: Scaffold(
        // Sem seta de voltar (PBI-63): a saída fica na barra fixa.
        bottomNavigationBar: _BarraSaida(
          aoFinalizar: () => _finalizar(context),
          aoDescartar: () => _descartar(context, ref),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cabecalho(
              nome: estado.treinoNome,
              inicio: estado.inicio,
              feitas: estado.seriesFeitas,
              total: estado.totalSeries,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.margemTela),
                children: [
                  for (var i = 0; i < estado.exercicios.length; i++) ...[
                    _CardExercicioVivo(
                      exercicio: estado.exercicios[i],
                      aoTocar: () => context.push(Rotas.exercicioAoVivo, extra: i),
                    ),
                    const SizedBox(height: AppSpacing.entreCards),
                  ],
                  BotaoTracejado(
                    rotulo: 'Adicionar exercício fora da ficha',
                    aoTocar: () => _adicionarForaDaFicha(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  Text(
                    'Tudo fica salvo no aparelho. Para sair do treino, '
                    'finalize ou descarte pelos botões abaixo.',
                    style: AppText.caption
                        .copyWith(color: AppColors.of(context).textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Finalizar (PBI-63, rodada 2): nunca salva e nunca abre diálogo. Vai direto
  /// ao Resumo (TV-6), que é o único passo de salvar e onde mora o aviso de
  /// treino vazio. Se o atleta descartar por lá, o Resumo devolve `true` e esta
  /// tela também sai, de volta ao plano.
  Future<void> _finalizar(BuildContext context) async {
    final descartou = await context.push<bool>(Rotas.resumoTreino);
    if (descartou == true && context.mounted) _sair(context);
  }

  /// Descartar pela barra: confirma, apaga o rascunho e volta para a tela de
  /// onde o treino começou (o plano, pelo play da PBI-61). Nenhuma sessão é
  /// gravada.
  Future<void> _descartar(BuildContext context, WidgetRef ref) async {
    final confirmar = await confirmarDescarte(context, rotuloCancelar: 'Voltar ao treino');
    if (!confirmar || !context.mounted) return;

    ref.read(treinoAoVivoControllerProvider.notifier).encerrar();
    ref.read(descansoControllerProvider.notifier).encerrar();
    _sair(context);
  }

  /// Sai da tela do treino. Navigator.pop ignora o PopScope (que só barra o
  /// voltar do sistema).
  static void _sair(BuildContext context) {
    final navegador = Navigator.of(context);
    if (navegador.canPop()) {
      navegador.pop();
    } else {
      context.go(Rotas.planoDetalhe);
    }
  }

  Future<void> _adicionarForaDaFicha(BuildContext context, WidgetRef ref) async {
    final nomeTreino = ref.read(treinoAoVivoControllerProvider)?.treinoNome;
    final escolhidos = await Navigator.of(context).push<List<ExercicioResumo>>(
      MaterialPageRoute(
        builder: (_) => SelecionarExercicioScreen(destino: nomeTreino),
      ),
    );
    if (escolhidos == null || escolhidos.isEmpty) return;

    // Só usa `ref` (não `context`) depois do await, então não há risco de
    // BuildContext atravessando gap assíncrono. Cada um entra com série em
    // branco (PBI-17), na ordem escolhida (PBI-49).
    final porCodigo = await ref.read(metricasPorCodigoProvider.future);
    final controller = ref.read(treinoAoVivoControllerProvider.notifier);
    for (final e in escolhidos) {
      controller.adicionarExercicio(ExercicioEdicao.foraDaFichaDoCatalogo(e, porCodigo));
    }
  }
}

/// Barra fixa da tela 24 (PBI-63): "FINALIZAR TREINO" (primário, check) e
/// "Descartar treino" (contorno vermelho, lixeira), 48 px cada. O rótulo do
/// primário segue em caixa alta (estilo `button`), o mesmo que o Robot usa.
class _BarraSaida extends StatelessWidget {
  const _BarraSaida({required this.aoFinalizar, required this.aoDescartar});

  final VoidCallback aoFinalizar;
  final VoidCallback aoDescartar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    // Largura mínima zero: o tema dá largura infinita ao botão, o que quebra
    // dentro de uma Row.
    const tamanho = Size(0, AppSizes.botaoSecundario);

    // Empilhados (tela 24): o primário em cima, o descartar embaixo.
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: cores.lineDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: aoFinalizar,
                style: FilledButton.styleFrom(minimumSize: tamanho),
                icon: const Icon(LucideIcons.check, size: AppSizes.iconeSm),
                label: const Text('FINALIZAR TREINO'),
              ),
              const SizedBox(height: AppSpacing.entreItens),
              OutlinedButton.icon(
                onPressed: aoDescartar,
                style: OutlinedButton.styleFrom(
                  minimumSize: tamanho,
                  foregroundColor: cores.danger,
                  side: BorderSide(color: cores.danger),
                ),
                icon: const Icon(LucideIcons.trash2, size: AppSizes.iconeSm),
                label: const Text('Descartar treino'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho escuro da tela 24 (rodada 2): "TREINO EM ANDAMENTO", o nome da
/// ficha, o cronômetro, "Começou às hh:mm" e as séries feitas. Sem seta.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.nome,
    required this.inicio,
    required this.feitas,
    required this.total,
  });

  final String nome;
  final DateTime inicio;
  final int feitas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final h = inicio.hour.toString().padLeft(2, '0');
    final m = inicio.minute.toString().padLeft(2, '0');
    return Container(
      color: cores.bgHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.margemCabecalho, AppSpacing.x16,
              AppSpacing.margemCabecalho, AppSpacing.x20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TREINO EM ANDAMENTO',
                  style: AppText.overline.copyWith(color: cores.textOnHeaderMuted)),
              const SizedBox(height: AppSpacing.x4),
              Semantics(
                header: true,
                child: Text(nome.toUpperCase(),
                    style: AppText.displayM.copyWith(color: cores.textOnHeader)),
              ),
              const SizedBox(height: AppSpacing.x12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CronometroVivo(
                          inicio: inicio,
                          estilo: AppText.displayL.copyWith(color: cores.textOnHeader),
                        ),
                        Text('Começou às $h:$m',
                            style: AppText.caption.copyWith(color: cores.textOnHeaderMuted)),
                      ],
                    ),
                  ),
                  Semantics(
                    label: '$feitas de $total séries feitas',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$feitas/$total',
                            style: AppText.numeralS.copyWith(color: cores.textOnHeader)),
                        Text('séries feitas',
                            style: AppText.caption.copyWith(color: cores.textOnHeaderMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de um exercício no treino em andamento: nome, barra de progresso por
/// série e status. Toca para abrir a tela do exercício (TV-4).
class _CardExercicioVivo extends StatelessWidget {
  const _CardExercicioVivo({required this.exercicio, required this.aoTocar});

  final ExercicioEdicao exercicio;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final total = exercicio.series.length;
    final feitas = exercicio.series.where((s) => s.feita).length;
    final status = _status(total, feitas);

    return Semantics(
      button: true,
      label: '${exercicio.nome}, $status',
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: aoTocar,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.paddingCard),
            decoration: BoxDecoration(
              border: Border.all(color: cores.lineDefault),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(exercicio.nome,
                          style: AppText.title, overflow: TextOverflow.ellipsis),
                    ),
                    Icon(LucideIcons.chevronRight,
                        size: AppSizes.iconeSm, color: cores.iconMuted),
                  ],
                ),
                const SizedBox(height: AppSpacing.x8),
                BarraSeries(total: total, feitas: feitas),
                const SizedBox(height: AppSpacing.x8),
                Text(status,
                    style: AppText.caption.copyWith(color: cores.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _status(int total, int feitas) {
    if (total == 0) return 'sem séries';
    if (feitas == 0) return '0/$total · ainda não começou';
    if (feitas == total) return 'Concluído';
    return '$feitas/$total séries concluídas';
  }
}

/// Tela do exercício no treino ao vivo (TV-4), série por série. Recebe o índice
/// do exercício na lista do treino ao vivo. Cabeçalho com posição ("Exercício N
/// de M"), nome, alvo e cronômetro pequeno; navegação anterior/próximo; e três
/// abas: Séries (completar série, tag, stepper), Histórico (3 últimas sessões) e
/// Evolução (gráfico do exercício).
class ExercicioAoVivoScreen extends ConsumerWidget {
  const ExercicioAoVivoScreen({super.key, required this.indice});

  final int indice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(treinoAoVivoControllerProvider);

    if (estado == null || indice < 0 || indice >= estado.exercicios.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercício')),
        body: const Center(child: Text('Exercício não encontrado.')),
      );
    }

    final exercicio = estado.exercicios[indice];
    final total = estado.exercicios.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercicio.nome, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Séries'),
              Tab(text: 'Histórico'),
              Tab(text: 'Evolução'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _CabecalhoExercicio(
                posicao: indice,
                total: total,
                exercicio: exercicio,
                inicio: estado.inicio,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AbaSeries(indice: indice, exercicio: exercicio),
                    _AbaHistorico(exercicioId: exercicio.exercicioId),
                    _AbaEvolucao(exercicioId: exercicio.exercicioId),
                  ],
                ),
              ),
              // Descanso entre séries (TV-5): fixo no rodapé, nas três abas.
              const BarraDescansoFixa(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho da tela do exercício: posição ("Exercício 2 de 5"), alvo (origem do
/// preenchimento), cronômetro pequeno e os botões anterior/próximo com os
/// pontos de posição.
class _CabecalhoExercicio extends StatelessWidget {
  const _CabecalhoExercicio({
    required this.posicao,
    required this.total,
    required this.exercicio,
    required this.inicio,
  });

  final int posicao;
  final int total;
  final ExercicioEdicao exercicio;
  final DateTime inicio;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temAnterior = posicao > 0;
    final temProximo = posicao < total - 1;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cores.lineDivider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Exercício ${posicao + 1} de $total',
                    style: AppText.overline
                        .copyWith(color: cores.textSecondary)),
              ),
              CronometroVivo(inicio: inicio, estilo: AppText.numeralS),
            ],
          ),
          if (exercicio.origemPreenchimento != null) ...[
            const SizedBox(height: AppSpacing.x6),
            Text(exercicio.origemPreenchimento!,
                style: AppText.caption.copyWith(color: cores.primaryText)),
          ],
          const SizedBox(height: AppSpacing.x12),
          Row(
            children: [
              _BotaoNavega(
                icone: LucideIcons.chevronLeft,
                rotulo: 'Exercício anterior',
                aoTocar: temAnterior
                    ? () => context.pushReplacement(Rotas.exercicioAoVivo,
                        extra: posicao - 1)
                    : null,
                cores: cores,
              ),
              Expanded(child: _PontosPosicao(total: total, atual: posicao)),
              _BotaoNavega(
                icone: LucideIcons.chevronRight,
                rotulo: 'Próximo exercício',
                aoTocar: temProximo
                    ? () => context.pushReplacement(Rotas.exercicioAoVivo,
                        extra: posicao + 1)
                    : null,
                cores: cores,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botão redondo de navegação entre exercícios.
class _BotaoNavega extends StatelessWidget {
  const _BotaoNavega({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    required this.cores,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: aoTocar != null,
      label: rotulo,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: aoTocar,
        child: Container(
          width: AppSizes.touchMin,
          height: AppSizes.touchMin,
          decoration: BoxDecoration(
            color: cores.bgInput,
            shape: BoxShape.circle,
            border: Border.all(color: cores.lineDefault),
          ),
          child: Icon(icone,
              size: AppSizes.iconeSm,
              color: aoTocar == null ? cores.iconMuted : cores.textStrong),
        ),
      ),
    );
  }
}

/// Pontos indicando a posição atual entre os exercícios.
class _PontosPosicao extends StatelessWidget {
  const _PontosPosicao({required this.total, required this.atual});

  final int total;
  final int atual;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.x6),
          Container(
            width: AppSpacing.x8,
            height: AppSpacing.x8,
            decoration: BoxDecoration(
              color: i == atual ? cores.primaryText : cores.bgTrack,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// Aba "Séries" (TV-3): lista as séries do exercício com check por série. A
/// série ativa (primeira não feita, ou a que o atleta tocou) fica aberta para
/// editar carga/reps com os steppers e a tag; "Completar série" marca e abre a
/// próxima. Séries feitas aparecem recolhidas e reabrem ao tocar.
class _AbaSeries extends ConsumerStatefulWidget {
  const _AbaSeries({required this.indice, required this.exercicio});

  final int indice;
  final ExercicioEdicao exercicio;

  @override
  ConsumerState<_AbaSeries> createState() => _AbaSeriesState();
}

class _AbaSeriesState extends ConsumerState<_AbaSeries> {
  /// Série aberta por toque (sobrepõe a "primeira não feita"). Nulo = usa a
  /// regra automática.
  int? _abertaManual;

  ExercicioEdicao get _ex => widget.exercicio;

  /// Índice da série ativa: a tocada à mão, senão a primeira não feita.
  int get _ativa {
    if (_abertaManual != null && _abertaManual! < _ex.series.length) {
      return _abertaManual!;
    }
    final i = _ex.series.indexWhere((s) => !s.feita);
    return i == -1 ? _ex.series.length - 1 : i;
  }

  void _completar(int i) {
    final controller = ref.read(treinoAoVivoControllerProvider.notifier);
    controller.definirSerieFeita(_ex, _ex.series[i], true);
    // Dispara o descanso (TV-5) só quando a série tem tempo informado; ficha
    // sem descanso deixa o campo vazio e nada começa (decisão do PO).
    final segundos = int.tryParse(_ex.series[i].descansoTexto.trim());
    ref.read(descansoControllerProvider.notifier).iniciar(segundos);
    // Abre automaticamente a próxima não feita (TV-3).
    setState(() => _abertaManual = null);
  }

  void _reabrir(int i) {
    final controller = ref.read(treinoAoVivoControllerProvider.notifier);
    controller.definirSerieFeita(_ex, _ex.series[i], false);
    // Desfez a conclusão: encerra o descanso que porventura estava rolando.
    ref.read(descansoControllerProvider.notifier).encerrar();
    setState(() => _abertaManual = i);
  }

  void _trocarTag(SerieEdicao serie, String marcador) {
    ref
        .read(treinoAoVivoControllerProvider.notifier)
        .mudar((_) => serie.marcador = marcador);
  }

  void _adicionarSerie() {
    ref.read(treinoAoVivoControllerProvider.notifier).mudar((_) {
      _ex.adicionarSerie();
    });
    setState(() => _abertaManual = _ex.series.length - 1);
  }

  void _removerSerie(int i) {
    ref.read(treinoAoVivoControllerProvider.notifier).mudar((_) {
      _ex.removerSerie(i);
    });
    setState(() => _abertaManual = null);
  }

  @override
  Widget build(BuildContext context) {
    // Observa o controller para rebuildar quando a versão muda (série feita,
    // tag trocada, série adicionada/removida).
    ref.watch(treinoAoVivoControllerProvider);
    final ativa = _ativa;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        for (var i = 0; i < _ex.series.length; i++) ...[
          _CardSerie(
            indice: i,
            serie: _ex.series[i],
            aberta: i == ativa,
            aoCompletar: () => _completar(i),
            aoReabrir: () => _reabrir(i),
            aoTrocarTag: (m) => _trocarTag(_ex.series[i], m),
            aoRemover:
                _ex.series.length > 1 ? () => _removerSerie(i) : null,
            aoAbrir: () => setState(() => _abertaManual = i),
          ),
          const SizedBox(height: AppSpacing.entreItens),
        ],
        const SizedBox(height: AppSpacing.x8),
        _BotaoAdicionarSerie(aoTocar: _adicionarSerie),
      ],
    );
  }
}

/// Card de uma série na aba Séries. Fechado (feita ou inativa) mostra só o
/// resumo e o check; aberto mostra os steppers, a tag e "Completar série".
class _CardSerie extends StatelessWidget {
  const _CardSerie({
    required this.indice,
    required this.serie,
    required this.aberta,
    required this.aoCompletar,
    required this.aoReabrir,
    required this.aoTrocarTag,
    required this.aoRemover,
    required this.aoAbrir,
  });

  final int indice;
  final SerieEdicao serie;
  final bool aberta;
  final VoidCallback aoCompletar;
  final VoidCallback aoReabrir;
  final ValueChanged<String> aoTrocarTag;
  final VoidCallback? aoRemover;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final rodada = indice + 1;

    final borda = serie.feita
        ? cores.primaryTint
        : (aberta ? Theme.of(context).colorScheme.primary : cores.lineDefault);

    return Container(
      decoration: BoxDecoration(
        color: serie.feita
            ? cores.primaryTint
            : Theme.of(context).colorScheme.surface,
        border: Border.all(color: borda, width: aberta && !serie.feita ? 2 : 1),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CheckSerie(
                feita: serie.feita,
                rodada: rodada,
                aoTocar: serie.feita ? aoReabrir : null,
              ),
              const SizedBox(width: AppSpacing.x10),
              Expanded(
                child: Semantics(
                  button: !aberta,
                  label: 'Série $rodada',
                  child: InkWell(
                    onTap: aberta ? null : aoAbrir,
                    child: Row(
                      children: [
                        Text('Série $rodada', style: AppText.titleS),
                        const SizedBox(width: AppSpacing.x8),
                        ChipTagSerie(
                          marcador: serie.marcador,
                          rodada: rodada,
                          aoTocar: aberta ? aoTrocarTag : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!aberta)
                Text(_resumoSerie(serie),
                    style:
                        AppText.caption.copyWith(color: cores.textSecondary)),
            ],
          ),
          if (aberta) ...[
            const SizedBox(height: AppSpacing.x12),
            _CamposSerie(serie: serie),
            const SizedBox(height: AppSpacing.x12),
            Row(
              children: [
                if (aoRemover != null)
                  Expanded(
                    child: SizedBox(
                      height: AppSizes.botaoSecundario,
                      child: OutlinedButton(
                        onPressed: aoRemover,
                        child: const Text('Remover'),
                      ),
                    ),
                  ),
                if (aoRemover != null) const SizedBox(width: AppSpacing.x8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: AppSizes.botaoSecundario,
                    child: FilledButton(
                      onPressed: serie.feita ? aoReabrir : aoCompletar,
                      child: Text(
                          serie.feita ? 'Reabrir série' : 'Completar série'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Resumo curto da série feita/fechada, ex.: "30 kg × 10".
  String _resumoSerie(SerieEdicao s) {
    final vol = s.volume.text.trim();
    if (vol.isEmpty) return 'a fazer';
    if (s.intensidadePorPesoCorporal) return vol;
    final i = s.intensidade.text.trim();
    return i.isEmpty ? vol : '$i × $vol';
  }
}

/// Checkbox redondo da série, com rótulo de acessibilidade.
class _CheckSerie extends StatelessWidget {
  const _CheckSerie(
      {required this.feita, required this.rodada, required this.aoTocar});

  final bool feita;
  final int rodada;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final cor = feita ? Theme.of(context).colorScheme.primary : cores.lineDashed;
    return Semantics(
      button: true,
      checked: feita,
      label: feita
          ? 'Série $rodada concluída. Tocar para reabrir.'
          : 'Série $rodada pendente',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: aoTocar,
        child: Container(
          width: AppSizes.iconeMd,
          height: AppSizes.iconeMd,
          decoration: BoxDecoration(
            color: feita ? cor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: cor, width: 2),
          ),
          child: feita
              ? Icon(LucideIcons.check,
                  size: 14, color: Theme.of(context).colorScheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}

/// Steppers de intensidade e volume de uma série. Peso corporal não tem valor
/// de intensidade a digitar (MER 3.11): mostra só o rótulo.
class _CamposSerie extends StatelessWidget {
  const _CamposSerie({required this.serie});

  final SerieEdicao serie;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (serie.intensidadePorPesoCorporal)
          Text(serie.intensidadeMetricaNome,
              style: AppText.caption.copyWith(color: cores.textSecondary))
        else ...[
          Text(serie.intensidadeMetricaNome,
              style: AppText.label.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x6),
          StepperMetrica(
            codigo: serie.intensidadeMetricaCodigo,
            controlador: serie.intensidade,
            rotulo: serie.intensidadeMetricaNome,
          ),
          const SizedBox(height: AppSpacing.x12),
        ],
        Text(serie.volumeMetricaNome,
            style: AppText.label.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x6),
        StepperMetrica(
          codigo: serie.volumeMetricaCodigo,
          controlador: serie.volume,
          rotulo: serie.volumeMetricaNome,
        ),
      ],
    );
  }
}

/// Botão "Adicionar série" (borda tracejada, padrão do design).
class _BotaoAdicionarSerie extends StatelessWidget {
  const _BotaoAdicionarSerie({required this.aoTocar});

  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: true,
      label: 'Adicionar série',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
        onTap: aoTocar,
        child: Container(
          height: AppSizes.touchMin,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            border: Border.all(color: cores.lineDashed),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus,
                  size: AppSizes.iconeSm, color: cores.textSecondary),
              const SizedBox(width: AppSpacing.x6),
              Text('Adicionar série',
                  style: AppText.bodyS.copyWith(
                      color: cores.textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aba "Histórico" (TV-4): as 3 últimas sessões do atleta com este exercício,
/// com a observação do dia em laranja. Estado vazio quando nunca fez.
class _AbaHistorico extends ConsumerWidget {
  const _AbaHistorico({required this.exercicioId});

  final String exercicioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historico = ref.watch(historicoExercicioProvider(exercicioId));

    return historico.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          child: MensagemGrafico(
            icone: LucideIcons.cloudOff,
            texto: 'Não foi possível carregar o histórico.',
            aoTentar: () => ref.invalidate(historicoExercicioProvider),
          ),
        ),
      ),
      data: (h) {
        if (h.vazio) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.margemTela),
              child: MensagemGrafico(
                icone: LucideIcons.history,
                texto: 'Primeira vez com este exercício.\n'
                    'O histórico aparece depois do primeiro treino.',
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          itemCount: h.sessoes.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.entreCards),
          itemBuilder: (_, i) => _CardSessaoHistorico(sessao: h.sessoes[i]),
        );
      },
    );
  }
}

/// Card de uma sessão no histórico: data, séries feitas e observação (laranja).
class _CardSessaoHistorico extends StatelessWidget {
  const _CardSessaoHistorico({required this.sessao});

  final SessaoHistorico sessao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temObs = sessao.observacao != null &&
        sessao.observacao!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_dataLonga(sessao.data),
              style: AppText.titleS.copyWith(color: cores.textStrong)),
          const SizedBox(height: AppSpacing.x8),
          for (final s in sessao.series)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x4),
              child: Text(_linhaSerie(s),
                  style: AppText.body.copyWith(color: cores.textSecondary)),
            ),
          if (temObs) ...[
            const SizedBox(height: AppSpacing.x8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cores.obsTint,
                border: Border.all(color: cores.obsLine),
                borderRadius: BorderRadius.circular(AppRadius.avisos),
              ),
              padding: const EdgeInsets.all(AppSpacing.x10),
              child: Text(sessao.observacao!,
                  style: AppText.bodyS.copyWith(color: cores.obsBody)),
            ),
          ],
        ],
      ),
    );
  }

  /// "Série 1: 30 kg × 10" (ou só volume no peso corporal).
  String _linhaSerie(SerieDetalhe s) {
    final vol = SerieEdicao.fmt(s.volume);
    final volTxt =
        '$vol ${s.volumeMetricaCodigo == 'REPETICOES' ? '' : s.volumeMetricaNome}'
            .trim();
    if (s.intensidadePorPesoCorporal) {
      return 'Série ${s.rodada}: $volTxt';
    }
    final i = SerieEdicao.fmt(s.intensidade);
    final intTxt = i.isEmpty ? '' : '$i ${s.intensidadeMetricaNome} × ';
    return 'Série ${s.rodada}: $intTxt$volTxt';
  }

  static String _dataLonga(DateTime d) {
    const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    final dia = dias[d.weekday - 1];
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dia, $dd/$mm/${d.year}';
  }
}

/// Aba "Evolução" (TV-4): o gráfico do exercício (reusado da aba Progresso),
/// com os estados de carregando/erro/vazio dentro da [CaixaGrafico].
class _AbaEvolucao extends ConsumerWidget {
  const _AbaEvolucao({required this.exercicioId});

  final String exercicioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progresso = ref.watch(progressoPorExercicioProvider(exercicioId));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        progresso.when(
          loading: () => const CaixaGrafico(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => CaixaGrafico(
            child: MensagemGrafico(
              icone: LucideIcons.cloudOff,
              texto: 'Não foi possível carregar a evolução.',
              aoTentar: () => ref.invalidate(progressoPorExercicioProvider),
            ),
          ),
          data: (p) {
            if (p == null || p.pontos.isEmpty) {
              return const CaixaGrafico(
                child: MensagemGrafico(
                  icone: LucideIcons.lineChart,
                  texto: 'Sem dados suficientes para o gráfico ainda.',
                ),
              );
            }
            return CaixaGrafico(child: GraficoExercicio(progresso: p));
          },
        ),
      ],
    );
  }
}
