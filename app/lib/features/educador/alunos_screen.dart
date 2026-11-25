import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:go_router/go_router.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/dialogos_perigo.dart';
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
/// novo aluno por e-mail e encerrar o acompanhamento (PBI-104). Empilhada a
/// partir do Perfil.
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
      if (context.mounted) mostrarErro(context, e.mensagem);
    }
  }
}

/// Cartão do aluno: a parte de cima abre a tela do aluno; embaixo, "Encerrar"
/// (PBI-104), o mesmo vínculo que o aluno encerra em "Meus educadores".
class _CartaoAluno extends ConsumerStatefulWidget {
  const _CartaoAluno({required this.aluno});

  final AlunoVinculado aluno;

  @override
  ConsumerState<_CartaoAluno> createState() => _CartaoAlunoState();
}

class _CartaoAlunoState extends ConsumerState<_CartaoAluno> {
  bool _encerrando = false;

  Future<void> _encerrar() async {
    final a = widget.aluno;
    final confirmou = await confirmarPerigo(
      context,
      titulo: 'Encerrar acompanhamento?',
      texto: 'Você deixa de ver os treinos e a evolução de ${a.alunoNome} agora. '
          'Os dados e os planos que você montou continuam com o aluno. Para '
          'voltar a acompanhar, convide de novo.',
      rotuloConfirmar: 'Encerrar',
    );
    if (!confirmou || !mounted) return;
    // O cartão some quando a lista recarrega: o aviso vai pelo messenger da
    // tela, pego antes da escrita.
    final messenger = ScaffoldMessenger.of(context);
    final cores = AppColors.of(context);
    setState(() => _encerrando = true);
    try {
      await ref.read(educadorComandosProvider).encerrar(a.vinculoId);
      mostrarAvisoNoMessenger(messenger, cores, 'Acompanhamento encerrado');
    } on EducadorException catch (erro) {
      // 409: o aluno já encerrou. O comando já recarregou a lista.
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(erro.mensagem)));
    } finally {
      if (mounted) setState(() => _encerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final aluno = widget.aluno;
    final raio = BorderRadius.circular(AppRadius.card);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: raio,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Abrir aluno ${aluno.alunoNome}',
            excludeSemantics: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: raio,
                onTap: () => context.push(
                  Rotas.alunoDetalhe,
                  extra: AlunoDetalheArgs(atletaId: aluno.alunoId, alunoNome: aluno.alunoNome),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.paddingCard, AppSpacing.paddingCard, AppSpacing.paddingCard, AppSpacing.x8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(aluno.alunoNome, style: AppText.title),
                            const SizedBox(height: AppSpacing.x4),
                            Text(aluno.alunoEmail,
                                style: AppText.bodyS.copyWith(color: cores.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: cores.iconMuted, size: AppSizes.iconeMd),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingCard, 0, AppSpacing.x8, AppSpacing.x8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Encerrar acompanhamento de ${aluno.alunoNome}',
                excludeSemantics: true,
                child: TextButton.icon(
                  onPressed: _encerrando ? null : _encerrar,
                  style: TextButton.styleFrom(
                    foregroundColor: cores.danger,
                    minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
                  ),
                  icon: const Icon(LucideIcons.userMinus, size: AppSizes.iconeSm),
                  label: const Text('Encerrar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
