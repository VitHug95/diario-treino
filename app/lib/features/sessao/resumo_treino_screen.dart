import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/relogio.dart';
import '../../shared/aviso_treino_salvo.dart';
import '../../shared/dialogos_perigo.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../catalogo/metrica.dart';
import 'descanso_controller.dart';
import 'manter_na_ficha.dart';
import 'sessao_edicao.dart';
import 'sessao_comandos.dart';
import 'sessao_repository.dart';
import 'treino_ao_vivo_controller.dart';
import 'widgets_ao_vivo.dart';

/// Tela 16 do protótipo: resumo do treino ao vivo antes de salvar (TV-6).
///
/// Mostra o que foi feito (volume total, status por exercício), com a data e a
/// duração editáveis e a observação do dia. "Salvar treino" grava a sessão com
/// SÓ as séries marcadas como feitas e encerra o treino ao vivo; uma falha de
/// rede mantém o rascunho para o atleta tentar de novo. "Voltar ao treino"
/// retorna à tela 14 sem perder nada.
class ResumoTreinoScreen extends ConsumerStatefulWidget {
  const ResumoTreinoScreen({super.key});

  @override
  ConsumerState<ResumoTreinoScreen> createState() => _ResumoTreinoScreenState();
}

class _ResumoTreinoScreenState extends ConsumerState<ResumoTreinoScreen> {
  late DateTime _data;
  final _duracao = TextEditingController();
  final _observacao = TextEditingController();
  bool _salvando = false;
  bool _iniciado = false;

  @override
  void dispose() {
    _duracao.dispose();
    _observacao.dispose();
    super.dispose();
  }

  /// Preenche data e duração a partir do estado vivo na primeira montagem.
  void _preencherUmaVez(TreinoAoVivoEstado estado) {
    if (_iniciado) return;
    _iniciado = true;
    _data = estado.data;
    final min = ref.read(relogioProvider).agora().difference(estado.inicio).inMinutes;
    if (min > 0) _duracao.text = min.toString();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(treinoAoVivoControllerProvider);
    if (estado == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Resumo do treino')),
        body: const Center(child: Text('Nenhum treino em andamento.')),
      );
    }
    _preencherUmaVez(estado);

    final cores = AppColors.of(context);
    final volume = _volumeTotal(estado.exercicios);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do treino')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.margemTela),
                children: [
                  Text(estado.treinoNome, style: AppText.displayS),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    '${estado.seriesFeitas} de ${estado.totalSeries} séries · '
                    '${estado.exerciciosConcluidos} de ${estado.exercicios.length} '
                    'exercícios concluídos',
                    style: AppText.body.copyWith(color: cores.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  if (volume > 0) _CardVolume(volume: volume, cores: cores),
                  const SizedBox(height: AppSpacing.x16),
                  _CampoData(data: _data, aoTocar: _escolherData),
                  const SizedBox(height: AppSpacing.x12),
                  _CampoDuracao(controlador: _duracao),
                  const SizedBox(height: AppSpacing.x24),
                  Text('EXERCÍCIOS',
                      style: AppText.overline
                          .copyWith(color: cores.textSecondary)),
                  const SizedBox(height: AppSpacing.x8),
                  for (final ex in estado.exercicios)
                    _LinhaResumoExercicio(exercicio: ex),
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
              aoVoltar: _salvando ? null : () => context.pop(),
              aoSalvar: _salvando ? null : _salvar,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(hoje.year - 2),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day)
          .add(const Duration(days: 1)),
      helpText: 'Dia em que você treinou',
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _salvar() async {
    final estado = ref.read(treinoAoVivoControllerProvider);
    if (estado == null) return;

    // Monta a lista a gravar com SÓ as séries feitas; exercício sem série feita
    // não é realizado (não vira série no POST, igual à regra do repositório).
    final paraSalvar = estado.exercicios.map(_somenteFeitas).toList();
    // Treino vazio (PBI-63, rodada 2): o aviso mora aqui, no único passo de
    // salvar. Salvar vazio só com a confirmação explícita (a trava silenciosa
    // da PBI-33 virou este diálogo).
    if (!paraSalvar.any((e) => e.temSerieFeita)) {
      final escolha = await dialogoTreinoVazio(context);
      if (!mounted) return;
      switch (escolha) {
        case EscolhaTreinoVazio.salvar:
          break; // segue e salva sem dados
        case EscolhaTreinoVazio.descartar:
          await _descartar();
          return;
        case EscolhaTreinoVazio.voltar:
        case null:
          return;
      }
    }

    // PBI-72: exercício adicionado fora da ficha, com série feita, pergunta se
    // fica na ficha. "Voltar ao resumo" não salva nada.
    if (!mounted) return;
    final manterNaFicha = await perguntarManterNaFicha(
      context,
      ref,
      treinoId: estado.treinoLivre ? null : estado.treinoId,
      treinoNome: estado.treinoNome,
      exercicios: paraSalvar,
    );
    if (manterNaFicha.ids == null || !mounted) return;

    setState(() => _salvando = true);
    try {
      final repo = ref.read(sessaoComandosProvider);
      final duracao = int.tryParse(_duracao.text.trim());
      final obs =
          _observacao.text.trim().isEmpty ? null : _observacao.text.trim();

      // Sessão e ficha numa chamada só (uma transação): ou grava tudo, ou nada.
      final sessaoId = await repo.criarSessao(
        treinoId: estado.treinoId,
        data: _data,
        duracaoMin: duracao,
        observacao: obs,
        exercicios: paraSalvar,
        manterNaFicha: manterNaFicha.ids!,
      );

      // Só encerra o treino ao vivo (apaga rascunho + descanso) DEPOIS de a
      // sessão ser salva: se o POST falha, o rascunho fica para tentar de novo.
      ref.read(treinoAoVivoControllerProvider.notifier).encerrar();
      ref.read(descansoControllerProvider.notifier).encerrar();

      // PBI-76: se a ficha não pôde ser lida para o "Manter na ficha?", o
      // treino foi salvo mesmo assim e o aviso diz isso.
      if (mounted) {
        _confirmar(
          sessaoId,
          mensagem: manterNaFicha.leituraFalhou
              ? 'Treino salvo. Não deu para conferir a ficha.'
              : 'Treino salvo',
        );
      }
    } on SessaoException catch (e) {
      _erro(e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Descartar pelo "Salvar treino vazio?": confirma, apaga o treino e fecha o
  /// Resumo devolvendo `true`, para a tela do treino sair também (volta ao
  /// plano). Nenhuma sessão é gravada.
  Future<void> _descartar() async {
    final confirmar = await confirmarDescarte(context, rotuloCancelar: 'Voltar ao resumo');
    if (!confirmar || !mounted) return;
    ref.read(treinoAoVivoControllerProvider.notifier).encerrar();
    ref.read(descansoControllerProvider.notifier).encerrar();
    Navigator.of(context).pop(true);
  }

  /// Salvou (PBI-64): Início com o aviso "Treino salvo", sem diálogo.
  void _confirmar(String sessaoId, {String mensagem = 'Treino salvo'}) =>
      irParaInicioComTreinoSalvo(context, sessaoId, mensagem: mensagem);

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Volume total do treino: soma de carga × reps das séries feitas que têm
  /// carga (CARGA_KG) e repetições. Séries de tempo/zona não entram no volume.
  static double _volumeTotal(List<ExercicioEdicao> exercicios) {
    var total = 0.0;
    for (final e in exercicios) {
      for (final s in e.series) {
        if (!s.feita) continue;
        if (s.intensidadeMetricaCodigo != MetricaCodigos.cargaKg) continue;
        if (s.volumeMetricaCodigo != MetricaCodigos.repeticoes) continue;
        final carga = _num(s.intensidadeTexto);
        final reps = _num(s.volumeTexto);
        if (carga != null && reps != null) total += carga * reps;
      }
    }
    return total;
  }

  static double? _num(String t) {
    final limpo = t.trim().replaceAll(',', '.');
    if (limpo.isEmpty) return null;
    return double.tryParse(limpo);
  }

  /// Cópia do exercício contendo só as séries feitas, com `realizado` conforme.
  static ExercicioEdicao _somenteFeitas(ExercicioEdicao e) {
    final feitas = e.series.where((s) => s.feita).toList();
    return ExercicioEdicao(
      treinoExercicioId: e.treinoExercicioId,
      exercicioId: e.exercicioId,
      nome: e.nome,
      grupoMuscular: e.grupoMuscular,
      modalidade: e.modalidade,
      origemPreenchimento: e.origemPreenchimento,
      series: feitas,
      realizado: feitas.isNotEmpty,
      foraDaFicha: e.foraDaFicha,
    );
  }
}

/// Cartão de destaque com o volume total do treino.
class _CardVolume extends StatelessWidget {
  const _CardVolume({required this.volume, required this.cores});

  final double volume;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    final txt = volume == volume.roundToDouble()
        ? volume.toInt().toString()
        : volume.toStringAsFixed(1);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.destaque),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VOLUME TOTAL',
              style: AppText.overline.copyWith(color: cores.primaryOnTint)),
          const SizedBox(height: AppSpacing.x4),
          Semantics(
            label: 'Volume total: $txt quilos levantados',
            child: Text('$txt kg',
                style: AppText.displayM.copyWith(color: cores.primaryOnTint)),
          ),
        ],
      ),
    );
  }
}

/// Linha de um exercício no resumo: nome + status (Completo / Incompleto N/M /
/// Não realizado), com uma barra de progresso por série.
class _LinhaResumoExercicio extends StatelessWidget {
  const _LinhaResumoExercicio({required this.exercicio});

  final ExercicioEdicao exercicio;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final total = exercicio.series.length;
    final feitas = exercicio.series.where((s) => s.feita).length;
    final (status, cor) = _status(total, feitas, exercicio.concluido, cores, context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.entreItens),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
      child: Semantics(
        label: '${exercicio.nome}${exercicio.foraDaFicha ? ', fora da ficha' : ''}: $status',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exercicio.nome,
                      style: AppText.titleS, overflow: TextOverflow.ellipsis),
                ),
                // PBI-72: o adicionado na hora fica marcado no Resumo.
                if (exercicio.foraDaFicha) ...[
                  _EtiquetaForaDaFicha(cores: cores),
                  const SizedBox(width: AppSpacing.x8),
                ],
                Text(status, style: AppText.label.copyWith(color: cor)),
              ],
            ),
            const SizedBox(height: AppSpacing.x8),
            BarraSeries(total: total, feitas: feitas),
          ],
        ),
      ),
    );
  }

  (String, Color) _status(int total, int feitas, bool concluido, AppColors cores,
      BuildContext context) {
    if (total == 0 || feitas == 0) {
      return ('Não realizado', cores.textSecondary);
    }
    if (feitas == total) {
      return ('Completo', Theme.of(context).colorScheme.primary);
    }
    // Encerrado pelo "Concluir exercício" (PBI-65): conta como concluído, com
    // o progresso; as séries não marcadas ficam de fora ao salvar.
    if (concluido) {
      return ('Concluído $feitas/$total', Theme.of(context).colorScheme.primary);
    }
    return ('Incompleto $feitas/$total', cores.obs);
  }
}

/// Etiqueta "Fora da ficha" (PBI-72): pílula com o tom primário claro.
class _EtiquetaForaDaFicha extends StatelessWidget {
  const _EtiquetaForaDaFicha({required this.cores});

  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('FORA DA FICHA',
          style: AppText.overline.copyWith(color: cores.primaryOnTint)),
    );
  }
}

class _CampoData extends StatelessWidget {
  const _CampoData({required this.data, required this.aoTocar});

  final DateTime data;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final texto = '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(AppRadius.campoForm),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Dia em que treinou'),
        child: Row(
          children: [
            Icon(LucideIcons.calendar,
                size: AppSizes.iconeSm, color: cores.iconMuted),
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

/// Barra inferior com "Voltar ao treino" e "Salvar treino".
class _BarraSalvar extends StatelessWidget {
  const _BarraSalvar({
    required this.salvando,
    required this.aoVoltar,
    required this.aoSalvar,
  });

  final bool salvando;
  final VoidCallback? aoVoltar;
  final VoidCallback? aoSalvar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: cores.lineDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppSizes.botaoPrincipal,
              child: OutlinedButton(
                onPressed: aoVoltar,
                child: const Text('Voltar ao treino'),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: AppSizes.botaoPrincipal,
              child: FilledButton(
                onPressed: aoSalvar,
                child: salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SALVAR TREINO'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
