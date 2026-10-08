import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/catalogo_repository.dart';
import '../catalogo/metrica.dart';
import 'fichas_repository.dart';
import 'plano_models.dart';

/// Resultado do editor: o que mudou na ficha ao fechar a tela.
enum ResultadoAlvos { salvo, removido }

/// Tela 10 do protótipo: define séries e alvos de um exercício da ficha.
/// Consome PUT /treinos/{id}/exercicios/{teId}/alvos e DELETE do exercício.
class EditarAlvosScreen extends ConsumerStatefulWidget {
  const EditarAlvosScreen({
    super.key,
    required this.treinoId,
    required this.exercicio,
  });

  final String treinoId;
  final TreinoExercicioResumo exercicio;

  @override
  ConsumerState<EditarAlvosScreen> createState() => _EditarAlvosScreenState();
}

class _EditarAlvosScreenState extends ConsumerState<EditarAlvosScreen> {
  static const _minSeries = 1;
  static const _maxSeries = 12;

  late int _series;
  int? _intensidadeId;
  int? _volumeId;
  late final TextEditingController _intensidadeAlvo;
  late final TextEditingController _volumeAlvo;
  late final TextEditingController _descanso;
  late final TextEditingController _instrucao;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final te = widget.exercicio;
    final alvo = te.alvo;
    _series = te.rodadas.clamp(_minSeries, _maxSeries);
    _intensidadeId = alvo?.intensidadeMetricaId;
    _volumeId = alvo?.volumeMetricaId;
    _intensidadeAlvo = TextEditingController(text: _formatar(alvo?.intensidadeAlvo));
    _volumeAlvo = TextEditingController(text: _formatar(alvo?.volumeAlvo));
    _descanso = TextEditingController(
        text: te.descansoSeg == null ? '' : te.descansoSeg.toString());
    _instrucao = TextEditingController(text: te.instrucao ?? '');
  }

  @override
  void dispose() {
    _intensidadeAlvo.dispose();
    _volumeAlvo.dispose();
    _descanso.dispose();
    _instrucao.dispose();
    super.dispose();
  }

  static String _formatar(double? v) {
    if (v == null) return '';
    // Mostra inteiro sem casas decimais (ex.: "30"), senão com vírgula.
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString().replaceAll('.', ',');
  }

  static double? _parse(String texto) {
    final limpo = texto.trim().replaceAll(',', '.');
    if (limpo.isEmpty) return null;
    return double.tryParse(limpo);
  }

  /// Pré-seleciona as métricas sugeridas pela modalidade quando o exercício
  /// ainda não tem alvo definido.
  void _aplicarSugestao(List<Metrica> metricas) {
    if (_intensidadeId != null && _volumeId != null) return;
    final (codIntensidade, codVolume) = _sugestaoPorModalidade(widget.exercicio.modalidade);
    _intensidadeId ??=
        metricas.where((m) => m.codigo == codIntensidade).firstOrNull?.id;
    _volumeId ??= metricas.where((m) => m.codigo == codVolume).firstOrNull?.id;
  }

  static (String, String) _sugestaoPorModalidade(String modalidade) =>
      switch (modalidade) {
        'ISOMETRIA' => (MetricaCodigos.pesoCorporal, MetricaCodigos.tempoSeg),
        'CARDIO' => (MetricaCodigos.zona, MetricaCodigos.tempoSeg),
        _ => (MetricaCodigos.cargaKg, MetricaCodigos.repeticoes),
      };

  void _ajustarSeries(int delta) {
    setState(() => _series = (_series + delta).clamp(_minSeries, _maxSeries));
  }

  Future<void> _salvar() async {
    if (_intensidadeId == null || _volumeId == null) {
      _erro('Escolha as métricas de intensidade e volume.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(fichasRepositoryProvider).definirAlvos(
            treinoId: widget.treinoId,
            treinoExercicioId: widget.exercicio.id,
            series: _series,
            intensidadeMetricaId: _intensidadeId!,
            intensidadeAlvo: _parse(_intensidadeAlvo.text),
            volumeMetricaId: _volumeId!,
            volumeAlvo: _parse(_volumeAlvo.text),
            descansoSeg: int.tryParse(_descanso.text.trim()),
            instrucao: _instrucao.text.trim().isEmpty ? null : _instrucao.text.trim(),
          );
      if (mounted) Navigator.pop(context, ResultadoAlvos.salvo);
    } on FichasException catch (e) {
      _erro(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _remover() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover da ficha?'),
        content: Text(
            '"${widget.exercicio.nome}" sai desta ficha. O histórico de treinos dele continua guardado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _salvando = true);
    try {
      await ref.read(fichasRepositoryProvider).removerExercicio(
            treinoId: widget.treinoId,
            treinoExercicioId: widget.exercicio.id,
          );
      if (mounted) Navigator.pop(context, ResultadoAlvos.removido);
    } on FichasException catch (e) {
      _erro(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
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
    final metricasAsync = ref.watch(metricasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alvos do exercício')),
      body: metricasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErroMetricas(
          aoTentar: () => ref.invalidate(metricasProvider),
        ),
        data: (metricas) {
          _aplicarSugestao(metricas);
          final intensidades = metricas.where((m) => m.ehIntensidade).toList();
          final volumes = metricas.where((m) => m.ehVolume).toList();
          final mIntensidade = metricas.where((m) => m.id == _intensidadeId).firstOrNull;
          final mVolume = metricas.where((m) => m.id == _volumeId).firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              _Cabecalho(exercicio: widget.exercicio),
              const SizedBox(height: AppSpacing.x24),
              _CampoSeries(
                series: _series,
                podeMenos: _series > _minSeries,
                podeMais: _series < _maxSeries,
                aoMenos: () => _ajustarSeries(-1),
                aoMais: () => _ajustarSeries(1),
              ),
              const SizedBox(height: AppSpacing.x20),
              _SeletorMetrica(
                rotulo: 'Intensidade',
                metricas: intensidades,
                selecionadaId: _intensidadeId,
                aoSelecionar: (id) => setState(() => _intensidadeId = id),
              ),
              const SizedBox(height: AppSpacing.x12),
              _CampoAlvo(
                controlador: _intensidadeAlvo,
                rotulo: 'Alvo de ${mIntensidade?.nome ?? 'intensidade'} (opcional)',
                sufixo: mIntensidade?.unidade,
                aoMudar: () => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.x20),
              _SeletorMetrica(
                rotulo: 'Volume',
                metricas: volumes,
                selecionadaId: _volumeId,
                aoSelecionar: (id) => setState(() => _volumeId = id),
              ),
              const SizedBox(height: AppSpacing.x12),
              _CampoAlvo(
                controlador: _volumeAlvo,
                rotulo: 'Alvo de ${mVolume?.nome ?? 'volume'} (opcional)',
                sufixo: mVolume?.unidade,
                aoMudar: () => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.x20),
              _CampoAlvo(
                controlador: _descanso,
                rotulo: 'Descanso entre séries (opcional)',
                sufixo: 's',
                somenteInteiro: true,
                aoMudar: () => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.x20),
              TextField(
                controller: _instrucao,
                maxLines: 3,
                minLines: 1,
                style: AppText.body,
                decoration: const InputDecoration(
                  labelText: 'Instrução (opcional)',
                  hintText: 'Ex.: cadência lenta na descida',
                ),
              ),
              const SizedBox(height: AppSpacing.x24),
              _Resumo(
                series: _series,
                intensidade: mIntensidade,
                intensidadeAlvo: _parse(_intensidadeAlvo.text),
                volume: mVolume,
                volumeAlvo: _parse(_volumeAlvo.text),
                descansoSeg: int.tryParse(_descanso.text.trim()),
              ),
              const SizedBox(height: AppSpacing.x24),
              SizedBox(
                height: AppSizes.botaoPrincipal,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          height: AppSizes.iconeSm,
                          width: AppSizes.iconeSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SALVAR'),
                ),
              ),
              const SizedBox(height: AppSpacing.x12),
              SizedBox(
                height: AppSizes.botaoSecundario,
                child: OutlinedButton.icon(
                  onPressed: _salvando ? null : _remover,
                  icon: const Icon(LucideIcons.trash2, size: AppSizes.iconeSm),
                  label: const Text('Remover da ficha'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.of(context).danger,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.exercicio});
  final TreinoExercicioResumo exercicio;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final subtitulo = [
      if (exercicio.grupoMuscular != null && exercicio.grupoMuscular!.isNotEmpty)
        exercicio.grupoMuscular!,
      exercicio.modalidade,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EXERCÍCIO',
            style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x4),
        Text(exercicio.nome, style: AppText.displayS),
        if (subtitulo.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x4),
          Text(subtitulo, style: AppText.caption.copyWith(color: cores.textSecondary)),
        ],
      ],
    );
  }
}

class _CampoSeries extends StatelessWidget {
  const _CampoSeries({
    required this.series,
    required this.podeMenos,
    required this.podeMais,
    required this.aoMenos,
    required this.aoMais,
  });

  final int series;
  final bool podeMenos;
  final bool podeMais;
  final VoidCallback aoMenos;
  final VoidCallback aoMais;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Séries', style: AppText.title),
        Row(
          children: [
            _BotaoPasso(
              icone: LucideIcons.minus,
              rotulo: 'Menos uma série',
              aoTocar: podeMenos ? aoMenos : null,
            ),
            Container(
              width: AppSizes.botaoSecundario,
              alignment: Alignment.center,
              child: Semantics(
                label: '$series séries',
                child: Text('$series', style: AppText.numeral),
              ),
            ),
            _BotaoPasso(
              icone: LucideIcons.plus,
              rotulo: 'Mais uma série',
              aoTocar: podeMais ? aoMais : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _BotaoPasso extends StatelessWidget {
  const _BotaoPasso({required this.icone, required this.rotulo, required this.aoTocar});

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: true,
      label: rotulo,
      child: SizedBox(
        width: AppSizes.campoSerie,
        height: AppSizes.campoSerie,
        child: OutlinedButton(
          onPressed: aoTocar,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(color: cores.lineDefault),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.campoSerie),
            ),
          ),
          child: Icon(icone, size: AppSizes.iconeSm),
        ),
      ),
    );
  }
}

class _SeletorMetrica extends StatelessWidget {
  const _SeletorMetrica({
    required this.rotulo,
    required this.metricas,
    required this.selecionadaId,
    required this.aoSelecionar,
  });

  final String rotulo;
  final List<Metrica> metricas;
  final int? selecionadaId;
  final ValueChanged<int?> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: selecionadaId,
      decoration: InputDecoration(labelText: rotulo),
      items: [
        for (final m in metricas)
          DropdownMenuItem(value: m.id, child: Text(m.nome)),
      ],
      onChanged: aoSelecionar,
    );
  }
}

class _CampoAlvo extends StatelessWidget {
  const _CampoAlvo({
    required this.controlador,
    required this.rotulo,
    required this.aoMudar,
    this.sufixo,
    this.somenteInteiro = false,
  });

  final TextEditingController controlador;
  final String rotulo;
  final VoidCallback aoMudar;
  final String? sufixo;
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
      onChanged: (_) => aoMudar(),
      decoration: InputDecoration(
        labelText: rotulo,
        suffixText: sufixo,
      ),
    );
  }
}

/// Frase-resumo que atualiza ao editar os campos.
class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.series,
    required this.intensidade,
    required this.intensidadeAlvo,
    required this.volume,
    required this.volumeAlvo,
    required this.descansoSeg,
  });

  final int series;
  final Metrica? intensidade;
  final double? intensidadeAlvo;
  final Metrica? volume;
  final double? volumeAlvo;
  final int? descansoSeg;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.avisos),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RESUMO',
              style: AppText.overline.copyWith(color: cores.primaryOnTint)),
          const SizedBox(height: AppSpacing.x6),
          Text(
            montarResumo(
              series: series,
              intensidade: intensidade,
              intensidadeAlvo: intensidadeAlvo,
              volume: volume,
              volumeAlvo: volumeAlvo,
              descansoSeg: descansoSeg,
            ),
            style: AppText.body.copyWith(color: cores.primaryOnTint),
          ),
        ],
      ),
    );
  }
}

/// Monta a frase-resumo dos alvos (ex.: "3 séries de 10 com 30 kg, 90 s de
/// descanso"). Exposta para teste.
String montarResumo({
  required int series,
  required Metrica? intensidade,
  required double? intensidadeAlvo,
  required Metrica? volume,
  required double? volumeAlvo,
  required int? descansoSeg,
}) {
  String num(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString().replaceAll('.', ',');

  final plural = series == 1 ? 'série' : 'séries';
  final partes = <String>['$series $plural'];

  // Volume: "de 10 repetições" / "de 10".
  if (volume != null && volumeAlvo != null) {
    partes.add('de ${num(volumeAlvo)} ${volume.unidade}'.trimRight());
  }
  // Intensidade: "com 30 kg".
  if (intensidade != null && intensidadeAlvo != null) {
    partes.add('com ${num(intensidadeAlvo)} ${intensidade.unidade}'.trimRight());
  }

  var frase = partes.join(' ');
  if (descansoSeg != null) {
    frase = '$frase, $descansoSeg s de descanso';
  }
  return '$frase.';
}

class _ErroMetricas extends StatelessWidget {
  const _ErroMetricas({required this.aoTentar});
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Não foi possível carregar as métricas.'),
          const SizedBox(height: AppSpacing.x12),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
