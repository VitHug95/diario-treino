import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/exercicio_resumo.dart';
import '../catalogo/selecionar_exercicio_screen.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';

/// Tela 3 do protótipo: registrar o treino de uma ficha, com as séries já
/// preenchidas pelo histórico ou pelos alvos (PBI-15) e edição das séries
/// durante o registro — adicionar, remover, recolher o resumo (PBI-16).
///
/// Em modo edição (PBI-18), [sessaoId] é informado: a tela abre com os dados da
/// sessão existente e salva via PUT em vez de criar.
class RegistrarSessaoScreen extends ConsumerWidget {
  const RegistrarSessaoScreen({
    super.key,
    required this.treinoId,
    required this.treinoNome,
    this.sessaoId,
  });

  final String treinoId;
  final String treinoNome;

  /// Nulo = registrar novo; preenchido = editar a sessão existente.
  final String? sessaoId;

  bool get _editando => sessaoId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titulo = _editando ? 'Editar treino' : 'Registrar $treinoNome';

    // Edição: carrega a sessão existente. Novo: carrega o rascunho da ficha.
    if (_editando) {
      final detalhe = ref.watch(sessaoDetalheProvider(sessaoId!));
      return Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: detalhe.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErroCarregar(
            aoTentar: () => ref.invalidate(sessaoDetalheProvider(sessaoId!)),
          ),
          data: (dados) => _Formulario(
            treinoId: dados.treinoId,
            sessaoId: sessaoId,
            data: dados.data,
            duracaoMin: dados.duracaoMin,
            observacao: dados.observacao,
            exercicios: dados.exercicios.map(ExercicioEdicao.doDetalhe).toList(),
          ),
        ),
      );
    }

    final rascunho = ref.watch(rascunhoSessaoProvider(treinoId));
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: rascunho.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErroCarregar(
          aoTentar: () => ref.invalidate(rascunhoSessaoProvider(treinoId)),
        ),
        data: (dados) => _Formulario(
          treinoId: treinoId,
          sessaoId: null,
          data: dados.data,
          duracaoMin: null,
          observacao: null,
          exercicios: dados.exercicios.map(ExercicioEdicao.doRascunho).toList(),
        ),
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({
    required this.treinoId,
    required this.sessaoId,
    required this.data,
    required this.duracaoMin,
    required this.observacao,
    required this.exercicios,
  });

  final String? treinoId;
  final String? sessaoId;
  final DateTime data;
  final int? duracaoMin;
  final String? observacao;
  final List<ExercicioEdicao> exercicios;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late DateTime _data;
  late final List<ExercicioEdicao> _exercicios;
  final _duracao = TextEditingController();
  final _observacao = TextEditingController();
  bool _salvando = false;

  bool get _editando => widget.sessaoId != null;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _exercicios = widget.exercicios;
    if (widget.duracaoMin != null) _duracao.text = widget.duracaoMin.toString();
    if (widget.observacao != null) _observacao.text = widget.observacao!;
  }

  @override
  void dispose() {
    _duracao.dispose();
    _observacao.dispose();
    for (final ex in _exercicios) {
      for (final s in ex.series) {
        s.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(hoje.year - 2),
      // Aceita até amanhã (igual à regra do servidor), não além.
      lastDate: DateTime(hoje.year, hoje.month, hoje.day).add(const Duration(days: 1)),
      helpText: 'Dia em que você treinou',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _adicionarForaDaFicha() async {
    final escolhido = await Navigator.of(context).push<ExercicioResumo>(
      MaterialPageRoute(
        builder: (_) => const SelecionarExercicioScreen(retornarCompleto: true),
      ),
    );
    if (escolhido == null || !mounted) return;

    // Resolve as métricas (código -> id/nome) para montar a série.
    final porCodigo = await ref.read(metricasPorCodigoProvider.future);
    if (!mounted) return;

    setState(() {
      _exercicios.add(
        ExercicioEdicao.foraDaFichaDoCatalogo(escolhido, porCodigo),
      );
    });
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final repo = ref.read(sessaoRepositoryProvider);
      final duracao = int.tryParse(_duracao.text.trim());
      final obs = _observacao.text.trim().isEmpty ? null : _observacao.text.trim();

      if (_editando) {
        await repo.editarSessao(
          sessaoId: widget.sessaoId!,
          treinoId: widget.treinoId,
          data: _data,
          duracaoMin: duracao,
          observacao: obs,
          exercicios: _exercicios,
        );
        if (!mounted) return;
        // Atualiza o detalhe e volta para a tela de visualização.
        ref.invalidate(sessaoDetalheProvider(widget.sessaoId!));
        Navigator.of(context).pop(true);
      } else {
        final sessaoId = await repo.criarSessao(
          treinoId: widget.treinoId,
          data: _data,
          duracaoMin: duracao,
          observacao: obs,
          exercicios: _exercicios,
        );
        if (mounted) await _confirmarRegistro(sessaoId);
      }
    } on SessaoException catch (e) {
      _erro(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _confirmarRegistro(String sessaoId) async {
    final acao = await showDialog<_AcaoPosRegistro>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Treino registrado'),
        content: const Text('Seu treino foi salvo. O que você quer fazer agora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoPosRegistro.inicio),
            child: const Text('Ir para o Início'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _AcaoPosRegistro.verTreino),
            child: const Text('Ver o treino'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _AcaoPosRegistro.progresso),
            child: const Text('Ver progresso'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (acao) {
      case _AcaoPosRegistro.verTreino:
        context.go(Rotas.inicio);
        context.push(Rotas.detalheSessao, extra: DetalheSessaoArgs(sessaoId: sessaoId));
      case _AcaoPosRegistro.progresso:
        context.go(Rotas.progresso);
      case _AcaoPosRegistro.inicio:
      case null:
        context.go(Rotas.inicio);
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
    final cores = AppColors.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              _CampoData(data: _data, aoTocar: _escolherData),
              const SizedBox(height: AppSpacing.x16),
              _CampoDuracao(controlador: _duracao),
              const SizedBox(height: AppSpacing.x24),
              Text('EXERCÍCIOS',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              if (_exercicios.isEmpty)
                _SemExercicios(cores: cores)
              else
                for (var i = 0; i < _exercicios.length; i++)
                  _CardExercicio(
                    key: ValueKey(
                        _exercicios[i].treinoExercicioId ?? 'avulso-$i-${_exercicios[i].exercicioId}'),
                    exercicio: _exercicios[i],
                    aoMudar: () => setState(() {}),
                  ),
              const SizedBox(height: AppSpacing.x4),
              SizedBox(
                height: AppSizes.touchMin,
                child: OutlinedButton.icon(
                  onPressed: _adicionarForaDaFicha,
                  icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                  label: const Text('Adicionar exercício fora da ficha'),
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
              TextField(
                controller: _observacao,
                maxLines: 4,
                minLines: 2,
                style: AppText.body,
                decoration: const InputDecoration(
                  labelText: 'Observação do dia (opcional)',
                  hintText: 'Ex.: dormi mal, ombro incomodou no supino',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        _BarraSalvar(
          salvando: _salvando,
          aoSalvar: _salvar,
          rotulo: _editando ? 'SALVAR ALTERAÇÕES' : 'SALVAR TREINO',
        ),
      ],
    );
  }
}

enum _AcaoPosRegistro { inicio, progresso, verTreino }

class _CampoData extends StatelessWidget {
  const _CampoData({required this.data, required this.aoTocar});

  final DateTime data;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final texto =
        '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(AppRadius.campoForm),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Dia em que treinou'),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: AppSizes.iconeSm, color: cores.iconMuted),
            const SizedBox(width: AppSpacing.x8),
            Text(texto, style: AppText.inputValue),
          ],
        ),
      ),
    );
  }
}

class _CampoDuracao extends StatelessWidget {
  const _CampoDuracao({required this.controlador});
  final TextEditingController controlador;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppText.inputValue,
      decoration: const InputDecoration(
        labelText: 'Duração (opcional)',
        suffixText: 'min',
      ),
    );
  }
}

/// Card de um exercício no registro: recolhe para mostrar o resumo, ou expande
/// para editar as séries (adicionar, remover, ajustar valores). PBI-16.
class _CardExercicio extends StatelessWidget {
  const _CardExercicio({
    super.key,
    required this.exercicio,
    required this.aoMudar,
  });

  final ExercicioEdicao exercicio;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final subtitulo = [
      if (exercicio.grupoMuscular != null && exercicio.grupoMuscular!.isNotEmpty)
        exercicio.grupoMuscular!,
      exercicio.modalidade,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.entreCards),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho tocável: recolhe/expande.
          InkWell(
            onTap: () {
              exercicio.recolhido = !exercicio.recolhido;
              aoMudar();
            },
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(exercicio.nome, style: AppText.title)),
                          if (exercicio.foraDaFicha) ...[
                            const SizedBox(width: AppSpacing.x8),
                            _ChipForaDaFicha(cores: cores),
                          ],
                        ],
                      ),
                      if (subtitulo.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x4),
                        Text(subtitulo,
                            style: AppText.caption.copyWith(color: cores.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Icon(
                  exercicio.recolhido ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  size: AppSizes.iconeSm,
                  color: cores.iconMuted,
                ),
              ],
            ),
          ),
          if (exercicio.recolhido) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(exercicio.resumo,
                style: AppText.bodyS.copyWith(color: cores.textSecondary)),
          ] else ...[
            if (exercicio.origemPreenchimento != null) ...[
              const SizedBox(height: AppSpacing.x8),
              _AvisoOrigem(texto: exercicio.origemPreenchimento!, cores: cores),
            ],
            const SizedBox(height: AppSpacing.x12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercicio.realizado ? 'Realizado' : 'Não realizado',
                    style: AppText.label.copyWith(
                      color: exercicio.realizado ? cores.textStrong : cores.textSecondary,
                    ),
                  ),
                ),
                Semantics(
                  label: exercicio.realizado
                      ? 'Marcar ${exercicio.nome} como não realizado'
                      : 'Marcar ${exercicio.nome} como realizado',
                  child: Switch(
                    value: exercicio.realizado,
                    onChanged: (v) {
                      exercicio.realizado = v;
                      aoMudar();
                    },
                  ),
                ),
              ],
            ),
            if (exercicio.realizado) _CorpoSeries(exercicio: exercicio, aoMudar: aoMudar),
          ],
        ],
      ),
    );
  }
}

/// Lista editável de séries + botão "adicionar série".
class _CorpoSeries extends StatelessWidget {
  const _CorpoSeries({required this.exercicio, required this.aoMudar});

  final ExercicioEdicao exercicio;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    if (exercicio.series.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x8),
        child: Text('Sem séries sugeridas. Marque como não realizado se não fez.',
            style: AppText.bodyS.copyWith(color: cores.textSecondary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.x8),
        for (var i = 0; i < exercicio.series.length; i++)
          _LinhaSerie(
            key: ValueKey(exercicio.series[i].id),
            serie: exercicio.series[i],
            podeRemover: exercicio.series.length > 1,
            aoRemover: () {
              exercicio.removerSerie(i);
              aoMudar();
            },
          ),
        const SizedBox(height: AppSpacing.x4),
        SizedBox(
          height: AppSizes.touchMin,
          child: OutlinedButton.icon(
            onPressed: () {
              exercicio.adicionarSerie();
              aoMudar();
            },
            icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
            label: const Text('Adicionar série'),
          ),
        ),
      ],
    );
  }
}

/// Selo "Fora da ficha" para exercícios adicionados na hora (PBI-17).
class _ChipForaDaFicha extends StatelessWidget {
  const _ChipForaDaFicha({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: cores.lineDefault),
      ),
      child: Text('Fora da ficha',
          style: AppText.caption.copyWith(color: cores.textSecondary)),
    );
  }
}

/// Aviso de pré-preenchimento (fundo primaryTint, raio de avisos).
class _AvisoOrigem extends StatelessWidget {
  const _AvisoOrigem({required this.texto, required this.cores});

  final String texto;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.avisos),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: AppSizes.iconeSm, color: cores.primaryOnTint),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Text(texto,
                style: AppText.caption.copyWith(color: cores.primaryOnTint)),
          ),
        ],
      ),
    );
  }
}

/// Uma linha de série editável. Peso corporal mostra o selo "Intensidade: peso
/// corporal" no lugar do campo de carga (MER 3.11, critério do PBI-16).
class _LinhaSerie extends StatelessWidget {
  const _LinhaSerie({
    super.key,
    required this.serie,
    required this.podeRemover,
    required this.aoRemover,
  });

  final SerieEdicao serie;
  final bool podeRemover;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 24,
            child: Text('${serie.rodada}',
                style: AppText.numeralS.copyWith(color: cores.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.x6),
          if (serie.intensidadePorPesoCorporal)
            Expanded(child: _SeloPesoCorporal(cores: cores))
          else
            Expanded(
              child: _CampoNumero(
                rotulo: serie.intensidadeMetricaNome,
                controlador: serie.intensidade,
              ),
            ),
          const SizedBox(width: AppSpacing.x6),
          Expanded(
            child: _CampoNumero(
              rotulo: serie.volumeMetricaNome,
              controlador: serie.volume,
            ),
          ),
          const SizedBox(width: AppSpacing.x6),
          SizedBox(
            width: 64,
            child: _CampoNumero(
              rotulo: 'Desc.',
              controlador: serie.descanso,
              somenteInteiro: true,
            ),
          ),
          IconButton(
            onPressed: podeRemover ? aoRemover : null,
            icon: Icon(LucideIcons.x, size: AppSizes.iconeSm, color: cores.danger),
            tooltip: 'Remover série',
          ),
        ],
      ),
    );
  }
}

class _SeloPesoCorporal extends StatelessWidget {
  const _SeloPesoCorporal({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Intensidade: peso corporal',
      child: Container(
        height: AppSizes.campoSerie,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
        decoration: BoxDecoration(
          color: cores.bgInput,
          borderRadius: BorderRadius.circular(AppRadius.campoSerie),
          border: Border.all(color: cores.lineDefault),
        ),
        child: Text('Peso corporal',
            style: AppText.caption.copyWith(color: cores.textSecondary)),
      ),
    );
  }
}

class _CampoNumero extends StatelessWidget {
  const _CampoNumero({
    required this.rotulo,
    required this.controlador,
    this.somenteInteiro = false,
  });

  final String rotulo;
  final TextEditingController controlador;
  final bool somenteInteiro;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      keyboardType: TextInputType.numberWithOptions(decimal: !somenteInteiro),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          somenteInteiro ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
        ),
      ],
      style: AppText.inputValue,
      decoration: InputDecoration(
        labelText: rotulo,
        isDense: true,
      ),
    );
  }
}

class _BarraSalvar extends StatelessWidget {
  const _BarraSalvar({
    required this.salvando,
    required this.aoSalvar,
    required this.rotulo,
  });

  final String rotulo;
  final bool salvando;
  final VoidCallback aoSalvar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.margemTela),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: cores.lineDivider)),
        ),
        child: SizedBox(
          height: AppSizes.botaoPrincipal,
          child: FilledButton(
            onPressed: salvando ? null : aoSalvar,
            child: salvando
                ? const SizedBox(
                    height: AppSizes.iconeSm,
                    width: AppSizes.iconeSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(rotulo),
          ),
        ),
      ),
    );
  }
}

class _SemExercicios extends StatelessWidget {
  const _SemExercicios({required this.cores});
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: cores.bgInput,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        'Esta ficha ainda não tem exercícios. Adicione exercícios à ficha para registrar o treino.',
        style: AppText.body.copyWith(color: cores.textSecondary),
      ),
    );
  }
}

class _ErroCarregar extends StatelessWidget {
  const _ErroCarregar({required this.aoTentar});
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Não foi possível preparar o registro.', style: AppText.title),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
