import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'educador_comandos.dart';
import 'educador_models.dart';
import 'educador_repository.dart';
import 'termo_consentimento_screen.dart';

/// Convites de educador recebidos pelo aluno (PBI-88). Aceitar passa pelo termo
/// de consentimento (LGPD); recusar encerra o convite. Empilhada do Perfil.
class ConvitesScreen extends ConsumerWidget {
  const ConvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convitesAsync = ref.watch(convitesPendentesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: SafeArea(
        child: convitesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar seus convites.',
            aoTentar: () => tentarDeNovo(ref, [convitesPendentesProvider]),
          ),
          data: (convites) => convites.isEmpty
              ? const EstadoVazio(
                  icone: LucideIcons.mailOpen,
                  titulo: 'Nenhum convite',
                  texto:
                      'Quando um educador te convidar para acompanhamento, o convite aparece aqui.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.margemTela),
                  itemCount: convites.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.entreCards),
                  itemBuilder: (_, i) => _CartaoConvite(convite: convites[i]),
                ),
        ),
      ),
    );
  }
}

class _CartaoConvite extends ConsumerWidget {
  const _CartaoConvite({required this.convite});
  final ConvitePendente convite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(convite.educadorNome, style: AppText.title),
          const SizedBox(height: AppSpacing.x4),
          Text(convite.educadorEmail,
              style: AppText.bodyS.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x4),
          Text('quer acompanhar seus treinos',
              style: AppText.body.copyWith(color: cores.textStrong)),
          const SizedBox(height: AppSpacing.x12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _recusar(context, ref),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _aceitar(context, ref),
                  child: const Text('Aceitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _aceitar(BuildContext context, WidgetRef ref) async {
    // Aceitar passa pelo termo de consentimento (PBI-87): só aceita de verdade
    // depois que o aluno confirma no termo.
    final confirmou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TermoConsentimentoScreen(educadorNome: convite.educadorNome),
      ),
    );
    if (confirmou != true || !context.mounted) return;
    try {
      await ref.read(educadorComandosProvider).aceitar(convite.vinculoId);
      if (context.mounted) mostrarAviso(context, 'Convite aceito');
    } on EducadorException catch (e) {
      if (context.mounted) mostrarAviso(context, e.mensagem);
    }
  }

  Future<void> _recusar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(educadorComandosProvider).recusar(convite.vinculoId);
      if (context.mounted) mostrarAviso(context, 'Convite recusado');
    } on EducadorException catch (e) {
      if (context.mounted) mostrarAviso(context, e.mensagem);
    }
  }
}
