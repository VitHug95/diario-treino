import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:go_router/go_router.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'aluno_detalhe_screen.dart';
import 'dialogo_convidar_aluno.dart';
import 'educador_comandos.dart';
import 'educador_models.dart';
import 'educador_repository.dart';

/// Lista de alunos com vínculo ativo do educador (PBI-88). Permite convidar um
/// novo aluno por e-mail. Empilhada a partir do Perfil.
class AlunosScreen extends ConsumerWidget {
  const AlunosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alunosAsync = ref.watch(alunosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus alunos'),
        actions: [
          IconButton(
            tooltip: 'Convidar aluno',
            icon: const Icon(LucideIcons.userPlus, size: AppSizes.iconeMd),
            onPressed: () => _convidar(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: alunosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar seus alunos.',
            aoTentar: () => tentarDeNovo(ref, [alunosProvider]),
          ),
          data: (alunos) => alunos.isEmpty
              ? EstadoVazio(
                  icone: LucideIcons.users,
                  titulo: 'Nenhum aluno ainda',
                  texto:
                      'Convide um aluno por e-mail. Quando ele aceitar, aparece aqui.',
                  acao: FilledButton.icon(
                    onPressed: () => _convidar(context, ref),
                    icon: const Icon(LucideIcons.userPlus, size: AppSizes.iconeSm),
                    label: const Text('Convidar aluno'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.margemTela),
                  itemCount: alunos.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.entreCards),
                  itemBuilder: (_, i) => _CartaoAluno(aluno: alunos[i]),
                ),
        ),
      ),
    );
  }

  Future<void> _convidar(BuildContext context, WidgetRef ref) async {
    final email = await dialogoConvidarAluno(context);
    if (email == null || email.isEmpty) return;
    try {
      await ref.read(educadorComandosProvider).convidar(email);
      if (context.mounted) mostrarAviso(context, 'Convite enviado');
    } on EducadorException catch (e) {
      if (context.mounted) mostrarAviso(context, e.mensagem);
    }
  }
}

class _CartaoAluno extends StatelessWidget {
  const _CartaoAluno({required this.aluno});
  final AlunoVinculado aluno;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      button: true,
      label: 'Abrir aluno ${aluno.alunoNome}',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push(
            Rotas.alunoDetalhe,
            extra: AlunoDetalheArgs(
                atletaId: aluno.alunoId, alunoNome: aluno.alunoNome),
          ),
          child: Container(
            width: double.infinity,
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
                      Text(aluno.alunoNome, style: AppText.title),
                      const SizedBox(height: AppSpacing.x4),
                      Text(aluno.alunoEmail,
                          style: AppText.bodyS
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
    );
  }
}
