import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';

/// Termo de consentimento LGPD mostrado antes de o aluno aceitar um convite
/// (PBI-87/88). Devolve `true` por `Navigator.pop` quando o aluno aceita.
///
/// TEXTO PROVISÓRIO: o conteúdo jurídico final será definido com o PO. A versão
/// aceita é registrada no backend (TermoConsentimento.VersaoVigente) no aceite.
class TermoConsentimentoScreen extends StatelessWidget {
  const TermoConsentimentoScreen({super.key, required this.educadorNome});

  final String educadorNome;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Termo de consentimento')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.margemTela),
                children: [
                  Text(
                    'Acompanhamento de $educadorNome',
                    style: AppText.title,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  Text(
                    'Ao aceitar, você autoriza $educadorNome a ver seus treinos '
                    'registrados e sua evolução enquanto o vínculo estiver '
                    'ativo. Observações marcadas como privadas não são '
                    'compartilhadas. Você pode encerrar o acompanhamento quando '
                    'quiser, e o acesso é removido na hora — seus dados '
                    'continuam com você.',
                    style: AppText.body.copyWith(color: cores.textStrong),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  Text(
                    'Texto provisório: a versão final do termo será definida '
                    'antes do lançamento do modo educador.',
                    style: AppText.caption.copyWith(color: cores.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.margemTela),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.botaoPrincipal,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('ACEITAR E ATIVAR'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x8),
                  SizedBox(
                    width: double.infinity,
                    height: AppSizes.botaoSecundario,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
