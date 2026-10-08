import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'sessao_edicao.dart';
import 'sessao_models.dart';
import 'sessao_repository.dart';

/// Tela 3 do protótipo: registrar o treino de uma ficha, com as séries já
/// preenchidas pelo histórico ou pelos alvos (PBI-15).
class RegistrarSessaoScreen extends ConsumerWidget {
  const RegistrarSessaoScreen({
    super.key,
    required this.treinoId,
    required this.treinoNome,
  });

  final String treinoId;
  final String treinoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rascunho = ref.watch(rascunhoSessaoProvider(treinoId));

    return Scaffold(
      appBar: AppBar(title: Text('Registrar $treinoNome')),
      body: rascunho.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErroCarregar(
          aoTentar: () => ref.invalidate(rascunhoSessaoProvider(treinoId)),
        ),
        data: (dados) => _Formulario(treinoId: treinoId, rascunho: dados),
      ),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({required this.treinoId, required this.rascunho});

  final String treinoId;
  final RascunhoSessao rascunho;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  late DateTime _data;
  late final List<ExercicioEdicao> _exercicios;
  final _duracao = TextEditingController();
  final _observacao = TextEditingController();
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _data = widget.rascunho.data;
    _exercicios =
        widget.rascunho.exercicios.map(ExercicioEdicao.doRascunho).toList();
  }

  @override
  void dispose() {
    _duracao.dispose();
    _observacao.dispose();
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

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await ref.read(sessaoRepositoryProvider).criarSessao(
            treinoId: widget.treinoId,
            data: _data,
            duracaoMin: int.tryParse(_duracao.text.trim()),
            observacao:
                _observacao.text.trim().isEmpty ? null : _observacao.text.trim(),
            exercicios: _exercicios,
          );
      if (mounted) await _confirmar();
    } on SessaoException catch (e) {
      _erro(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _confirmar() async {
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _AcaoPosRegistro.progresso),
            child: const Text('Ver progresso'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (acao) {
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
                for (final ex in _exercicios)
                  _CardExercicio(
                    exercicio: ex,
                    aoAlternarRealizado: (v) => setState(() => ex.realizado = v),
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
        _BarraSalvar(salvando: _salvando, aoSalvar: _salvar),
      ],
    );
  }
}

enum _AcaoPosRegistro { inicio, progresso }

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

class _CardExercicio extends StatelessWidget {
  const _CardExercicio({
    required this.exercicio,
    required this.aoAlternarRealizado,
  });

  final ExercicioEdicao exercicio;
  final ValueChanged<bool> aoAlternarRealizado;

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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercicio.nome, style: AppText.title),
                    if (subtitulo.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x4),
                      Text(subtitulo,
                          style: AppText.caption.copyWith(color: cores.textSecondary)),
                    ],
                  ],
                ),
              ),
              Semantics(
                label: exercicio.realizado
                    ? 'Marcar ${exercicio.nome} como não realizado'
                    : 'Marcar ${exercicio.nome} como realizado',
                child: Switch(
                  value: exercicio.realizado,
                  onChanged: aoAlternarRealizado,
                ),
              ),
            ],
          ),
          if (exercicio.origemPreenchimento != null) ...[
            const SizedBox(height: AppSpacing.x8),
            _AvisoOrigem(texto: exercicio.origemPreenchimento!, cores: cores),
          ],
          const SizedBox(height: AppSpacing.x12),
          if (!exercicio.realizado)
            Text('Não realizado neste treino.',
                style: AppText.bodyS.copyWith(color: cores.textSecondary))
          else if (exercicio.series.isEmpty)
            Text('Sem séries sugeridas. Marque como não realizado se não fez.',
                style: AppText.bodyS.copyWith(color: cores.textSecondary))
          else
            for (final s in exercicio.series) _LinhaSerie(serie: s),
        ],
      ),
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

/// Uma linha de série editável: rótulo da rodada + campos de intensidade,
/// volume e descanso conforme as métricas do exercício.
class _LinhaSerie extends StatelessWidget {
  const _LinhaSerie({required this.serie});
  final SerieEdicao serie;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 28,
            child: Text('${serie.rodada}',
                style: AppText.numeralS.copyWith(color: cores.textSecondary)),
          ),
          const SizedBox(width: AppSpacing.x8),
          if (serie.intensidadePorPesoCorporal)
            Expanded(
              child: _SeloPesoCorporal(cores: cores),
            )
          else
            Expanded(
              child: _CampoNumero(
                rotulo: serie.intensidadeMetricaNome,
                valorInicial: serie.intensidadeTexto,
                aoMudar: (v) => serie.intensidadeTexto = v,
              ),
            ),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: _CampoNumero(
              rotulo: serie.volumeMetricaNome,
              valorInicial: serie.volumeTexto,
              aoMudar: (v) => serie.volumeTexto = v,
            ),
          ),
          const SizedBox(width: AppSpacing.x8),
          SizedBox(
            width: 72,
            child: _CampoNumero(
              rotulo: 'Desc.',
              valorInicial: serie.descansoTexto,
              somenteInteiro: true,
              aoMudar: (v) => serie.descansoTexto = v,
            ),
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
    return Container(
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
    );
  }
}

class _CampoNumero extends StatefulWidget {
  const _CampoNumero({
    required this.rotulo,
    required this.valorInicial,
    required this.aoMudar,
    this.somenteInteiro = false,
  });

  final String rotulo;
  final String valorInicial;
  final ValueChanged<String> aoMudar;
  final bool somenteInteiro;

  @override
  State<_CampoNumero> createState() => _CampoNumeroState();
}

class _CampoNumeroState extends State<_CampoNumero> {
  late final TextEditingController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.valorInicial);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controlador,
      keyboardType: TextInputType.numberWithOptions(decimal: !widget.somenteInteiro),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.somenteInteiro ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
        ),
      ],
      style: AppText.inputValue,
      onChanged: widget.aoMudar,
      decoration: InputDecoration(
        labelText: widget.rotulo,
        isDense: true,
      ),
    );
  }
}

class _BarraSalvar extends StatelessWidget {
  const _BarraSalvar({required this.salvando, required this.aoSalvar});

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
                : const Text('SALVAR TREINO'),
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
