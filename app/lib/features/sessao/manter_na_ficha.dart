import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_repository.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';

/// Escolha no "Manter na ficha?" (PBI-72).
enum EscolhaManterNaFicha { manter, soNesteTreino, voltar }

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

/// Pergunta "Manter na ficha?" ao salvar (PBI-72) e devolve os ids a manter:
/// lista vazia = salvar só neste treino (ou nem precisou perguntar); `null` =
/// voltar sem salvar.
///
/// Só pergunta quando a sessão veio de uma ficha editável (não do professor)
/// e há exercício fora da ficha com série salva. Treino livre ([treinoId]
/// nulo) e edição de sessão antiga não chamam isto. Se não der para ler a
/// ficha (sem rede), não pergunta: o treino é salvo como sempre.
Future<List<String>?> perguntarManterNaFicha(
  BuildContext context,
  WidgetRef ref, {
  required String? treinoId,
  required String treinoNome,
  required List<ExercicioEdicao> exercicios,
  String rotuloVoltar = 'Voltar ao resumo',
}) async {
  if (treinoId == null) return const [];
  var candidatos = exerciciosForaDaFichaSalvos(exercicios);
  if (candidatos.isEmpty) return const [];

  try {
    final ficha = await ref.read(fichaDetalheProvider(treinoId).future);
    if (ficha.somenteLeitura) return const [];
    // Já está na ficha (adicionado "fora" mas é o mesmo exercício): não repete.
    final naFicha = ficha.exercicios.map((e) => e.exercicioId).toSet();
    candidatos = candidatos.where((e) => !naFicha.contains(e.exercicioId)).toList();
  } catch (_) {
    return const [];
  }
  if (candidatos.isEmpty || !context.mounted) return const [];

  final escolha = await showDialog<EscolhaManterNaFicha>(
    context: context,
    builder: (_) => DialogoManterNaFicha(
      treinoNome: treinoNome,
      exercicios: candidatos,
      rotuloVoltar: rotuloVoltar,
    ),
  );
  return switch (escolha) {
    EscolhaManterNaFicha.manter => [for (final e in candidatos) e.exercicioId],
    EscolhaManterNaFicha.soNesteTreino => const [],
    EscolhaManterNaFicha.voltar || null => null,
  };
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

/// Diálogo "Manter na ficha?" (tela 25): "Manter na ficha" (primário), "Só
/// neste treino" (secundário) e voltar (texto). Uma decisão vale para todos os
/// exercícios listados.
class DialogoManterNaFicha extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final estilo = AppText.body.copyWith(color: cores.textSecondary);
    final forte = AppText.body.copyWith(
        color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600);
    void fechar(EscolhaManterNaFicha e) => Navigator.of(context).pop(e);

    final um = exercicios.length == 1;
    final texto = um
        ? Text.rich(
            TextSpan(style: estilo, children: [
              TextSpan(text: 'Você adicionou um exercício que não está na ficha $treinoNome: '),
              TextSpan(text: exercicios.single.nome, style: forte),
              TextSpan(
                  text: '. Se mantiver, ele entra no fim da ficha com '
                      '${resumoParaFicha(exercicios.single)}.'),
            ]),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Você adicionou exercícios que não estão na ficha $treinoNome. '
                  'Se mantiver, eles entram no fim da ficha:',
                  style: estilo),
              const SizedBox(height: AppSpacing.x8),
              for (final e in exercicios)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x4),
                  child: Text.rich(TextSpan(style: estilo, children: [
                    TextSpan(text: e.nome, style: forte),
                    TextSpan(text: ' · ${resumoParaFicha(e)}'),
                  ])),
                ),
            ],
          );

    return AlertDialog(
      title: const Text('Manter na ficha?'),
      content: texto,
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        SizedBox(
          width: double.infinity,
          height: AppSizes.botaoSecundario,
          child: FilledButton(
            onPressed: () => fechar(EscolhaManterNaFicha.manter),
            child: const Text('MANTER NA FICHA'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: AppSizes.botaoSecundario,
          child: OutlinedButton(
            onPressed: () => fechar(EscolhaManterNaFicha.soNesteTreino),
            child: const Text('Só neste treino'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => fechar(EscolhaManterNaFicha.voltar),
            child: Text(rotuloVoltar),
          ),
        ),
      ],
    );
  }
}
