import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../core/tema/tema_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../auth/auth_service.dart';

/// Tela inicial (tela 2 do protótipo). A sequência de fichas e o resumo reais
/// chegam nos PBIs 12 e 23; por ora o cartão de destaque é estrutural.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final usuario = ref.watch(authStateProvider).value;
    final primeiroNome = (usuario?.displayName ?? 'Atleta').split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bora treinar',
                            style: AppText.body.copyWith(color: cores.textSecondary)),
                        Text('BORA, ${primeiroNome.toUpperCase()}',
                            style: AppText.displayL),
                      ],
                    ),
                  ),
                  _BotaoTema(
                    escuro: escuro,
                    onPressed: () => ref
                        .read(temaControllerProvider.notifier)
                        .definir(escuro ? ThemeMode.light : ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x20),
              _CartaoDestaque(cores: cores),
              const SizedBox(height: AppSpacing.x24),
              // Atalho ao catálogo (parte da montagem de fichas, PBIs 12-14).
              OutlinedButton.icon(
                onPressed: () => context.push(Rotas.exercicios),
                icon: const Icon(LucideIcons.dumbbell, size: AppSizes.iconeSm),
                label: const Text('Ver exercícios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoTema extends StatelessWidget {
  const _BotaoTema({required this.escuro, required this.onPressed});

  final bool escuro;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return IconButton.filled(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: cores.textSecondary,
        side: BorderSide(color: cores.lineDefault),
      ),
      icon: Icon(escuro ? LucideIcons.sun : LucideIcons.moon,
          size: AppSizes.iconeSm),
      tooltip: escuro ? 'Usar tema claro' : 'Usar tema escuro',
    );
  }
}

/// Cartão "próximo da sequência" — fundo escuro (bg-header), raio 18.
/// Conteúdo definitivo (ficha seguinte) depende dos PBIs de fichas/registro.
class _CartaoDestaque extends StatelessWidget {
  const _CartaoDestaque({required this.cores});

  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x20),
      decoration: BoxDecoration(
        color: cores.bgHeader,
        borderRadius: BorderRadius.circular(AppRadius.destaque),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRÓXIMO DA SEQUÊNCIA',
              style: AppText.overline.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x8),
          Text('Monte suas fichas',
              style: AppText.displayM.copyWith(color: cores.textOnHeader)),
          const SizedBox(height: AppSpacing.x4),
          Text('Crie o Treino A, B, C para começar a registrar.',
              style: AppText.body.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(
            onPressed: () => context.go(Rotas.fichas),
            child: const Text('MONTAR FICHAS'),
          ),
        ],
      ),
    );
  }
}
