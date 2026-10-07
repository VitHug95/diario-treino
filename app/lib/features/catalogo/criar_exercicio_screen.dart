import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'catalogo_repository.dart';
import 'metrica.dart';

/// Tela 9 (PBI-11): criar um exercício próprio. Ao escolher o tipo, as métricas
/// de intensidade e volume vêm sugeridas, mas podem ser trocadas.
class CriarExercicioScreen extends ConsumerStatefulWidget {
  const CriarExercicioScreen({super.key});

  @override
  ConsumerState<CriarExercicioScreen> createState() => _CriarExercicioScreenState();
}

class _CriarExercicioScreenState extends ConsumerState<CriarExercicioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _grupo = TextEditingController();

  // Começa em Força (tipo mais comum).
  ModalidadeTipo _tipo = ModalidadeTipo.forca;
  int? _intensidadeId;
  int? _volumeId;
  bool _usuarioTrocouMetricas = false;
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _grupo.dispose();
    super.dispose();
  }

  /// Pré-seleciona as métricas sugeridas para o tipo, se o usuário ainda não
  /// trocou manualmente. Chamado quando as métricas carregam e ao mudar o tipo.
  void _aplicarSugestao(List<Metrica> metricas) {
    if (_usuarioTrocouMetricas) return;
    final sugestao = _tipo.sugestao;
    final intensidade = metricas.where((m) => m.codigo == sugestao.$1).firstOrNull;
    final volume = metricas.where((m) => m.codigo == sugestao.$2).firstOrNull;
    _intensidadeId = intensidade?.id;
    _volumeId = volume?.id;
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) return;
    if (_intensidadeId == null || _volumeId == null) {
      _mostrar('Escolha as métricas de intensidade e volume.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await ref.read(catalogoRepositoryProvider).criarExercicio(
            nome: _nome.text,
            grupoMuscular: _grupo.text,
            modalidade: _tipo.valorApi,
            intensidadeMetricaId: _intensidadeId!,
            volumeMetricaId: _volumeId!,
          );
      // Atualiza a lista do catálogo e volta.
      ref.invalidate(catalogoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercício criado.')),
        );
        Navigator.of(context).pop(true);
      }
    } on CatalogoException catch (e) {
      _mostrar(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final metricasAsync = ref.watch(metricasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo exercício')),
      body: metricasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErroMetricas(
          aoTentar: () => ref.invalidate(metricasProvider),
        ),
        data: (metricas) {
          _aplicarSugestao(metricas);
          final intensidades = metricas.where((m) => m.ehIntensidade).toList();
          final volumes = metricas.where((m) => m.ehVolume).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _grupo,
                    decoration: const InputDecoration(
                      labelText: 'Grupo (opcional)',
                      hintText: 'Ex.: peito, pernas',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _SeletorTipo(
                    selecionado: _tipo,
                    aoSelecionar: (t) => setState(() {
                      _tipo = t;
                      // Novo tipo volta a sugerir, a menos que já tenham trocado.
                      if (!_usuarioTrocouMetricas) {
                        _aplicarSugestao(metricas);
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  _SeletorMetrica(
                    rotulo: 'Intensidade',
                    metricas: intensidades,
                    selecionadaId: _intensidadeId,
                    aoSelecionar: (id) => setState(() {
                      _intensidadeId = id;
                      _usuarioTrocouMetricas = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _SeletorMetrica(
                    rotulo: 'Volume',
                    metricas: volumes,
                    selecionadaId: _volumeId,
                    aoSelecionar: (id) => setState(() {
                      _volumeId = id;
                      _usuarioTrocouMetricas = true;
                    }),
                  ),
                  const SizedBox(height: 24),
                  _Previa(
                    metricas: metricas,
                    intensidadeId: _intensidadeId,
                    volumeId: _volumeId,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar exercício'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tipos de exercício para a criação, com a sugestão de métricas (códigos) e o
/// valor enviado à API.
enum ModalidadeTipo {
  forca('Força', 'FORCA', 'Carga × repetições. Ex.: supino, agachamento',
      (MetricaCodigos.cargaKg, MetricaCodigos.repeticoes)),
  isometria('Isometria', 'ISOMETRIA', 'Segurar por um tempo. Ex.: prancha, equilíbrio',
      (MetricaCodigos.pesoCorporal, MetricaCodigos.tempoSeg)),
  cardio('Cardio', 'CARDIO', 'Zona × tempo ou distância. Ex.: corrida, bike',
      (MetricaCodigos.zona, MetricaCodigos.tempoSeg));

  const ModalidadeTipo(this.rotulo, this.valorApi, this.descricao, this.sugestao);

  final String rotulo;
  final String valorApi;
  final String descricao;

  /// (código da intensidade sugerida, código do volume sugerido).
  final (String, String) sugestao;
}

class _SeletorTipo extends StatelessWidget {
  const _SeletorTipo({required this.selecionado, required this.aoSelecionar});

  final ModalidadeTipo selecionado;
  final ValueChanged<ModalidadeTipo> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        for (final t in ModalidadeTipo.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => aoSelecionar(t),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.paddingCard),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: t == selecionado ? primary : cores.lineDefault,
                    width: t == selecionado ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<ModalidadeTipo>(
                      value: t,
                      groupValue: selecionado,
                      onChanged: (v) => v == null ? null : aoSelecionar(v),
                    ),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.rotulo, style: AppText.title),
                          const SizedBox(height: AppSpacing.x4),
                          Text(t.descricao,
                              style: AppText.caption
                                  .copyWith(color: cores.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
      decoration: InputDecoration(
        labelText: rotulo,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final m in metricas)
          DropdownMenuItem(value: m.id, child: Text(m.nome)),
      ],
      onChanged: aoSelecionar,
    );
  }
}

class _Previa extends StatelessWidget {
  const _Previa({
    required this.metricas,
    required this.intensidadeId,
    required this.volumeId,
  });

  final List<Metrica> metricas;
  final int? intensidadeId;
  final int? volumeId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i = metricas.where((m) => m.id == intensidadeId).firstOrNull;
    final v = metricas.where((m) => m.id == volumeId).firstOrNull;
    final texto = (i == null || v == null)
        ? 'Escolha as métricas para ver a prévia.'
        : 'No registro, cada série vai pedir: ${i.nome} × ${v.nome}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prévia', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(texto, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
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
          const SizedBox(height: 12),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
