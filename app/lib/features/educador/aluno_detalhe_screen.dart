import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../shared/progresso/grafico_exercicio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../sessao/sessao_models.dart';
import 'educador_repository.dart';

/// Argumentos para abrir o detalhe de um aluno (PBI-88c).
class AlunoDetalheArgs {
  const AlunoDetalheArgs({required this.atletaId, required this.alunoNome});
  final String atletaId;
  final String alunoNome;
}

/// Tela do educador com os dados de um aluno (PBI-88c): evolução por exercício
/// (gráfico) e sessões recentes. Só leitura — a regra de acesso (vínculo ativo)
/// e a privacidade (observação privada oculta) são garantidas pela API.
class AlunoDetalheScreen extends ConsumerWidget {
  const AlunoDetalheScreen({
    super.key,
    required this.atletaId,
    required this.alunoNome,
  });

  final String atletaId;
  final String alunoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final sessoesAsync = ref.watch(sessoesDoAlunoProvider(atletaId));

    return Scaffold(
      appBar: AppBar(title: Text(alunoNome)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => tentarDeNovo(ref, [
            exerciciosDoAlunoProvider(atletaId),
            progressoDoAlunoProvider(atletaId),
            sessoesDoAlunoProvider(atletaId),
          ]),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
            children: [
              Text('EVOLUÇÃO',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              _SeletorExercicioAluno(atletaId: atletaId),
              const SizedBox(height: AppSpacing.x16),
              _GraficoAluno(atletaId: atletaId),
              const SizedBox(height: AppSpacing.x28),
              Text('SESSÕES RECENTES',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              sessoesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.x28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => EstadoErro(
                  mensagem: 'Não foi possível carregar as sessões do aluno.',
                  aoTentar: () =>
                      tentarDeNovo(ref, [sessoesDoAlunoProvider(atletaId)]),
                ),
                data: (sessoes) => sessoes.isEmpty
                    ? const EstadoVazio(
                        icone: LucideIcons.calendarOff,
                        titulo: 'Nenhum treino recente',
                        texto:
                            'Quando o aluno registrar um treino, ele aparece aqui.',
                      )
                    : Column(
                        children: [
                          for (final s in sessoes) ...[
                            _CardSessaoAluno(sessao: s),
                            const SizedBox(height: AppSpacing.entreItens),
                          ],
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

/// Seletor de exercício do aluno (dropdown), por aluno.
class _SeletorExercicioAluno extends ConsumerWidget {
  const _SeletorExercicioAluno({required this.atletaId});
  final String atletaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final exerciciosAsync = ref.watch(exerciciosDoAlunoProvider(atletaId));
    final selecionado = ref.watch(exercicioDoAlunoSelecionadoProvider);

    return exerciciosAsync.when(
      loading: () => const _CampoVazio(texto: 'Carregando exercícios…'),
      error: (_, __) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        onTap: () => tentarDeNovo(ref, [exerciciosDoAlunoProvider(atletaId)]),
        child: const _CampoVazio(
            texto: 'Erro ao carregar. Toque para tentar de novo.'),
      ),
      data: (exercicios) {
        if (exercicios.isEmpty) {
          return const _CampoVazio(
              texto: 'O aluno ainda não tem exercícios com histórico.');
        }
        final valorValido =
            exercicios.any((e) => e.id == selecionado) ? selecionado : null;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.campoForm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
          child: Semantics(
            label: 'Exercício do gráfico',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: valorValido,
                hint: Text('Selecione um exercício',
                    style: AppText.body.copyWith(color: cores.textSecondary)),
                icon: Icon(LucideIcons.chevronDown,
                    color: cores.iconMuted, size: AppSizes.iconeMd),
                borderRadius: BorderRadius.circular(AppRadius.campoForm),
                items: [
                  for (final e in exercicios)
                    DropdownMenuItem<String>(
                      value: e.id,
                      child: Text(e.nome,
                          style: AppText.body.copyWith(color: cores.textStrong),
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => ref
                    .read(exercicioDoAlunoSelecionadoProvider.notifier)
                    .selecionar(id),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CampoVazio extends StatelessWidget {
  const _CampoVazio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      height: AppSizes.campoForm,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12),
      child: Text(texto,
          style: AppText.body.copyWith(color: cores.textSecondary)),
    );
  }
}

/// Gráfico de evolução do aluno: reage ao exercício selecionado.
class _GraficoAluno extends ConsumerWidget {
  const _GraficoAluno({required this.atletaId});
  final String atletaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecionado = ref.watch(exercicioDoAlunoSelecionadoProvider);
    if (selecionado == null) {
      return const CaixaGrafico(
        child: MensagemGrafico(
          icone: LucideIcons.lineChart,
          texto: 'Selecione um exercício para ver a evolução do aluno.',
        ),
      );
    }

    final progressoAsync = ref.watch(progressoDoAlunoProvider(atletaId));
    return progressoAsync.when(
      loading: () => const CaixaGrafico(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => CaixaGrafico(
        child: MensagemGrafico(
          icone: LucideIcons.cloudOff,
          texto: 'Não foi possível carregar o gráfico.',
          aoTentar: () => tentarDeNovo(ref, [progressoDoAlunoProvider(atletaId)]),
        ),
      ),
      data: (progresso) {
        if (progresso == null) {
          return const CaixaGrafico(
            child: MensagemGrafico(
              icone: LucideIcons.lineChart,
              texto: 'Selecione um exercício para ver a evolução do aluno.',
            ),
          );
        }
        if (!progresso.temGrafico || progresso.pontos.isEmpty) {
          return const CaixaGrafico(
            child: MensagemGrafico(
              icone: LucideIcons.calendarOff,
              texto: 'Sem dados no período para este exercício.',
            ),
          );
        }
        return GraficoExercicio(
          key: ValueKey('${progresso.exercicioId}-${progresso.pontos.length}'),
          progresso: progresso,
        );
      },
    );
  }
}

/// Cartão de uma sessão do aluno; toca abre o detalhe (reusa a tela do atleta,
/// que já aplica o controle de acesso e oculta a observação privada).
class _CardSessaoAluno extends StatelessWidget {
  const _CardSessaoAluno({required this.sessao});
  final SessaoResumo sessao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final titulo = sessao.treinoNome ?? 'Treino livre';
    final detalhes = <String>[
      '${sessao.quantidadeExercicios} '
          '${sessao.quantidadeExercicios == 1 ? 'exercício' : 'exercícios'}',
      if (sessao.duracaoMin != null) '${sessao.duracaoMin} min',
    ].join(' · ');

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => context.push(
          Rotas.detalheSessao,
          extra: DetalheSessaoArgs(
              sessaoId: sessao.id, treinoNome: sessao.treinoNome),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dataLonga(sessao.data), style: AppText.title),
                    const SizedBox(height: AppSpacing.x4),
                    Text(titulo,
                        style: AppText.body.copyWith(color: cores.textStrong)),
                    const SizedBox(height: AppSpacing.x4),
                    Text(detalhes,
                        style: AppText.caption
                            .copyWith(color: cores.textSecondary)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  color: cores.iconMuted, size: AppSizes.iconeMd),
            ],
          ),
        ),
      ),
    );
  }

  static String _dataLonga(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
