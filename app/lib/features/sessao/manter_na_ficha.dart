import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_repository.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';

/// Resultado de [perguntarManterNaFicha] (PBI-72/76).
///
/// - [ids] nulo = o atleta escolheu "voltar" (não salvar).
/// - [ids] vazio = salvar só neste treino, ou não houve o que perguntar.
/// - [leituraFalhou] true = não deu para ler a ficha (sem rede): o treino
///   ainda é salvo, mas a tela avisa que não dá para confirmar o "manter".
class ResultadoManterNaFicha {
  const ResultadoManterNaFicha(this.ids, {this.leituraFalhou = false});

  final List<String>? ids;
  final bool leituraFalhou;

  /// Atalho: só os ids quando houve escolha (ou lista vazia). Nulo = voltar.
  static const ResultadoManterNaFicha voltar = ResultadoManterNaFicha(null);
  static const ResultadoManterNaFicha nenhum = ResultadoManterNaFicha(<String>[]);
}

/// Exercícios adicionados fora da ficha que serão salvos (têm ao menos uma
/// série que vai para o servidor). Exercício sem série marcada não conta.
List<ExercicioEdicao> exerciciosForaDaFichaSalvos(List<ExercicioEdicao> exercicios) {
  final vistos = <String>{};
  return [
    for (final e in exercicios)
      if (e.treinoExercicioId == null &&
          SessaoRepository.seriesQueVaoSalvar(e).isNotEmpty &&
          vistos.add(e.exercicioId))
        e,
  ];
}

/// Pergunta "Manter na ficha?" ao salvar (PBI-72). Devolve um
/// [ResultadoManterNaFicha]: ids a manter (lista vazia = só neste treino),
/// nulo = voltar sem salvar, e um sinal quando a ficha não pôde ser lida.
///
/// Só pergunta quando a sessão veio de uma ficha editável (não do professor)
/// e há exercício fora da ficha com série salva. Treino livre ([treinoId]
/// nulo) e edição de sessão antiga não chamam isto. Se não der para ler a
/// ficha (sem rede), o treino é salvo como sempre, mas o chamador recebe
/// [ResultadoManterNaFicha.leituraFalhou] para avisar o atleta (PBI-76).
Future<ResultadoManterNaFicha> perguntarManterNaFicha(
  BuildContext context,
  WidgetRef ref, {
  required String? treinoId,
  required String treinoNome,
  required List<ExercicioEdicao> exercicios,
  String rotuloVoltar = 'Voltar ao resumo',
}) async {
  if (treinoId == null) return ResultadoManterNaFicha.nenhum;
  var candidatos = exerciciosForaDaFichaSalvos(exercicios);
  if (candidatos.isEmpty) return ResultadoManterNaFicha.nenhum;

  try {
    final ficha = await ref.read(fichaDetalheProvider(treinoId).future);
    if (ficha.somenteLeitura) return ResultadoManterNaFicha.nenhum;
    // Já está na ficha (adicionado "fora" mas é o mesmo exercício): não repete.
    final naFicha = ficha.exercicios.map((e) => e.exercicioId).toSet();
    candidatos = candidatos.where((e) => !naFicha.contains(e.exercicioId)).toList();
  } catch (e, pilha) {
    // PBI-76: não engole mais o erro em silêncio. Registra e sinaliza para o
    // chamador avisar o atleta — o treino segue sendo salvo.
    debugPrint('Falha ao ler a ficha para "Manter na ficha?": $e\n$pilha');
    return const ResultadoManterNaFicha(<String>[], leituraFalhou: true);
  }
  if (candidatos.isEmpty || !context.mounted) return ResultadoManterNaFicha.nenhum;

  // O diálogo devolve a lista de ids a manter: null = voltar (não salvar),
  // lista vazia = só neste treino, lista = os exercícios escolhidos. Com um
  // exercício é a decisão única de sempre; com vários, a escolha é por
  // exercício (PBI-81).
  final ids = await showDialog<List<String>>(
    context: context,
    builder: (_) => DialogoManterNaFicha(
      treinoNome: treinoNome,
      exercicios: candidatos,
      rotuloVoltar: rotuloVoltar,
    ),
  );
  if (ids == null) return ResultadoManterNaFicha.voltar;
  return ResultadoManterNaFicha(ids);
}

/// "2 séries de 20 × 10": quantas séries vão para a ficha e o alvo da última.
String resumoParaFicha(ExercicioEdicao e) {
  final series = SessaoRepository.seriesQueVaoSalvar(e);
  if (series.isEmpty) return '';
  final ultima = series.last;
  final volume = ultima.volume.text.trim();
  final carga = ultima.intensidadePorPesoCorporal ? '' : ultima.intensidade.text.trim();
  final volumeComUnidade = switch (ultima.volumeMetricaCodigo) {
    'TEMPO_SEG' => '$volume s',
    'DISTANCIA_M' => '$volume m',
    _ => carga.isEmpty ? '$volume repetições' : volume,
  };
  final alvo = carga.isEmpty ? volumeComUnidade : '$carga × $volumeComUnidade';
  final n = series.length;
  return '$n ${n == 1 ? 'série' : 'séries'} de $alvo';
}

/// Diálogo "Manter na ficha?" (tela 25). Devolve (via `Navigator.pop`) a lista
/// de ids a manter na ficha: `null` = voltar (não salvar), lista vazia = só
/// neste treino, lista = os exercícios escolhidos.
///
/// - **Um exercício:** a decisão única de sempre — "MANTER NA FICHA" (devolve
///   `[id]`), "Só neste treino" (devolve `[]`) e voltar (`null`).
/// - **Dois ou mais (PBI-81):** uma linha por exercício com a escolha "Manter
///   na ficha" / "Só neste treino" (padrão: manter), e as ações "Salvar"
///   (devolve só os marcados) e voltar. Assim o atleta mantém o que funcionou e
///   deixa de fora o que fez só naquele dia.
class DialogoManterNaFicha extends StatefulWidget {
  const DialogoManterNaFicha({
    super.key,
    required this.treinoNome,
    required this.exercicios,
    this.rotuloVoltar = 'Voltar ao resumo',
  });

  final String treinoNome;
  final List<ExercicioEdicao> exercicios;
  final String rotuloVoltar;

  @override
  State<DialogoManterNaFicha> createState() => _DialogoManterNaFichaState();
}

class _DialogoManterNaFichaState extends State<DialogoManterNaFicha> {
  /// Ids marcados como "manter". Todos começam marcados (caminho feliz: tocar
  /// em Salvar sem mexer mantém tudo, igual ao comportamento antigo).
  late final Set<String> _manter = {
    for (final e in widget.exercicios) e.exercicioId,
  };

  void _devolver(List<String>? ids) => Navigator.of(context).pop(ids);

  @override
  Widget build(BuildContext context) {
    final um = widget.exercicios.length == 1;
    return um ? _umExercicio(context) : _variosExercicios(context);
  }

  // ---- Um exercício: três botões, decisão única (comportamento de sempre) ----
  Widget _umExercicio(BuildContext context) {
    final cores = AppColors.of(context);
    final estilo = AppText.body.copyWith(color: cores.textSecondary);
    final forte = AppText.body.copyWith(
        color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600);
    final e = widget.exercicios.single;

    return AlertDialog(
      title: const Text('Manter na ficha?'),
      content: Text.rich(
        TextSpan(style: estilo, children: [
          TextSpan(text: 'Você adicionou um exercício que não está na ficha ${widget.treinoNome}: '),
          TextSpan(text: e.nome, style: forte),
          TextSpan(
              text: '. Se mantiver, ele entra no fim da ficha com '
                  '${resumoParaFicha(e)}.'),
        ]),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x12),
      actions: [
        // Column única (largura total): três botões empilhados e tocáveis mesmo
        // em 360 px e fonte ampliada (PBI-76), sem depender do OverflowBar.
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: AppSizes.botaoSecundario,
              child: FilledButton(
                onPressed: () => _devolver([e.exercicioId]),
                child: const Text('MANTER NA FICHA'),
              ),
            ),
            const SizedBox(height: AppSpacing.x8),
            SizedBox(
              width: double.infinity,
              height: AppSizes.botaoSecundario,
              child: OutlinedButton(
                onPressed: () => _devolver(const <String>[]),
                child: const Text('Só neste treino'),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _devolver(null),
                child: Text(widget.rotuloVoltar),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Dois ou mais: escolha por exercício (PBI-81) ----
  Widget _variosExercicios(BuildContext context) {
    final cores = AppColors.of(context);
    final estilo = AppText.body.copyWith(color: cores.textSecondary);

    return AlertDialog(
      title: const Text('Manter na ficha?'),
      // Conteúdo rola quando há muitos exercícios (3+) ou fonte ampliada, para
      // as ações no rodapé continuarem visíveis em 360 px.
      content: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Você adicionou exercícios que não estão na ficha ${widget.treinoNome}. '
                  'Escolha o que fica na ficha:',
                  style: estilo),
              const SizedBox(height: AppSpacing.x12),
              for (final e in widget.exercicios)
                _LinhaEscolha(
                  exercicio: e,
                  manter: _manter.contains(e.exercicioId),
                  aoMudar: (manter) => setState(() {
                    if (manter) {
                      _manter.add(e.exercicioId);
                    } else {
                      _manter.remove(e.exercicioId);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x12),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: AppSizes.botaoSecundario,
              child: FilledButton(
                // Devolve só os marcados, na ordem em que foram listados.
                onPressed: () => _devolver([
                  for (final e in widget.exercicios)
                    if (_manter.contains(e.exercicioId)) e.exercicioId,
                ]),
                child: const Text('SALVAR'),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _devolver(null),
                child: Text(widget.rotuloVoltar),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Uma linha do diálogo com vários exercícios (PBI-81): nome + resumo e a
/// escolha "Manter na ficha" / "Só neste treino". A escolha não depende só de
/// cor — tem texto explícito e é anunciada pelo leitor de tela com o nome do
/// exercício ("Supino reto: manter na ficha").
class _LinhaEscolha extends StatelessWidget {
  const _LinhaEscolha({
    required this.exercicio,
    required this.manter,
    required this.aoMudar,
  });

  final ExercicioEdicao exercicio;
  final bool manter;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final forte = AppText.body.copyWith(
        color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600);
    final sub = AppText.caption.copyWith(color: cores.textSecondary);
    final rotulo = manter
        ? '${exercicio.nome}: manter na ficha'
        : '${exercicio.nome}: só neste treino';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercicio.nome, style: forte),
          const SizedBox(height: AppSpacing.x4),
          Text(resumoParaFicha(exercicio), style: sub),
          const SizedBox(height: AppSpacing.x8),
          // SegmentedButton: duas opções com texto; estado selecionado anunciado.
          Semantics(
            label: rotulo,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Manter na ficha')),
                ButtonSegment(value: false, label: Text('Só neste treino')),
              ],
              selected: {manter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => aoMudar(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
