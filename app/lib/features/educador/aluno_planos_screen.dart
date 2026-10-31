import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';
import '../planos/acoes_plano.dart';
import 'aluno_plano_detalhe_screen.dart';
import 'aluno_planos_comandos.dart';
import 'educador_repository.dart';

/// Argumentos para abrir os planos de um aluno (PBI-88d).
class AlunoPlanosArgs {
  const AlunoPlanosArgs({required this.atletaId, required this.alunoNome});
  final String atletaId;
  final String alunoNome;
}

/// Tela do educador com os planos de um aluno (PBI-88d, fecha a PBI-48). Lista
/// os planos do aluno e cria um plano novo (autor = educador). Montar as fichas
/// acontece no detalhe do plano. Só o educador com vínculo ativo chega aqui; a
/// API aplica o controle de acesso (sem vínculo, 404).
class AlunoPlanosScreen extends ConsumerWidget {
  const AlunoPlanosScreen({
    super.key,
    required this.atletaId,
    required this.alunoNome,
  });

  final String atletaId;
  final String alunoNome;

  Future<void> _criarPlano(BuildContext context, WidgetRef ref) async {
    final nome = await dialogoNovoPlano(context);
    if (nome == null || !context.mounted) return;
    try {
      final id = await ref
          .read(alunoPlanosComandosProvider)
          .criarPlanoParaAluno(atletaId: atletaId, nome: nome);
      if (context.mounted) {
        context.push(
          Rotas.alunoPlanoDetalhe,
          extra: AlunoPlanoDetalheArgs(
              atletaId: atletaId, alunoNome: alunoNome, planoId: id),
        );
      }
    } on FichasException catch (e) {
      if (context.mounted) avisarPlano(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final planosAsync = ref.watch(planosDoAlunoProvider(atletaId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Planos de $alunoNome'),
        actions: [
          IconButton(
            onPressed: () => _criarPlano(context, ref),
            icon: const Icon(LucideIcons.plus, size: AppSizes.iconeMd),
            tooltip: 'Criar plano para $alunoNome',
          ),
        ],
      ),
      body: SafeArea(
        child: planosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar os planos do aluno.',
            aoTentar: () =>
                tentarDeNovo(ref, [planosDoAlunoProvider(atletaId)]),
          ),
          data: (planos) {
            if (planos.isEmpty) {
              return _SemPlanosDoAluno(
                alunoNome: alunoNome,
                aoCriar: () => _criarPlano(context, ref),
              );
            }
            return RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(planosDoAlunoProvider(atletaId).future),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.margemTela),
                children: [
                  Text(
                    'Os planos que você monta para o aluno aparecem com seu '
                    'nome como professor. O aluno lê, treina e copia, mas só '
                    'você edita.',
                    style:
                        AppText.caption.copyWith(color: cores.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  for (final plano in ordenarPlanos(planos)) ...[
                    _CartaoPlanoAluno(
                      plano: plano,
                      aoAbrir: () => context.push(
                        Rotas.alunoPlanoDetalhe,
                        extra: AlunoPlanoDetalheArgs(
                          atletaId: atletaId,
                          alunoNome: alunoNome,
                          planoId: plano.id,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.entreCards),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cartão de um plano do aluno: nome, tag "Em uso", resumo e, quando o plano é
/// de outro autor (ex.: o próprio aluno montou), o chip de leitura. Toca abre o
/// detalhe do plano.
class _CartaoPlanoAluno extends StatelessWidget {
  const _CartaoPlanoAluno({required this.plano, required this.aoAbrir});

  final PlanoDaLista plano;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final primaria = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: plano.emUso ? primaria : cores.lineDefault,
          width: plano.emUso ? 2 : 1,
        ),
      ),
      child: Semantics(
        button: true,
        label: 'Abrir plano ${plano.nome}',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: aoAbrir,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.paddingCard),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.x8,
                            runSpacing: AppSpacing.x4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(plano.nome.toUpperCase(),
                                  style: AppText.displayS),
                              if (plano.emUso) _TagEmUso(cores: cores),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.x4),
                          Text(_resumo(plano),
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
          ),
        ),
      ),
    );
  }

  static String _resumo(PlanoDaLista p) {
    final fichas =
        '${p.quantidadeFichas} ${p.quantidadeFichas == 1 ? 'ficha' : 'fichas'}';
    final exercicios =
        '${p.quantidadeExercicios} ${p.quantidadeExercicios == 1 ? 'exercício' : 'exercícios'}';
    return '$fichas · $exercicios';
  }
}

class _TagEmUso extends StatelessWidget {
  const _TagEmUso({required this.cores});
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.checkCircle, size: 14, color: cores.primaryOnTint),
          const SizedBox(width: AppSpacing.x4),
          Text('Em uso',
              style: AppText.caption.copyWith(
                  color: cores.primaryOnTint, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Aluno ainda sem planos: convida o educador a montar o primeiro.
class _SemPlanosDoAluno extends StatelessWidget {
  const _SemPlanosDoAluno({required this.alunoNome, required this.aoCriar});

  final String alunoNome;
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: LucideIcons.calendarPlus,
      titulo: 'Nenhum plano ainda',
      texto: 'Monte o primeiro plano de $alunoNome. '
          'Você cria o plano e adiciona as fichas e os exercícios.',
      acao: FilledButton.icon(
        onPressed: aoCriar,
        icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
        label: const Text('CRIAR PLANO'),
      ),
    );
  }
}
