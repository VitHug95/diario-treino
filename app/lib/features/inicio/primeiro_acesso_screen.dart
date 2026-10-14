import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';

/// Tela 6 do protótipo: primeiro acesso (PBI-09). Aparece no lugar da tela
/// inicial enquanto o atleta não tem nenhuma ficha nem sessão. Explica o app em
/// segundos e oferece dois caminhos: montar as fichas ou registrar sem ficha.
class PrimeiroAcessoScreen extends StatelessWidget {
  const PrimeiroAcessoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.x24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.x20),
                decoration: BoxDecoration(
                  color: cores.bgHeader,
                  borderRadius: BorderRadius.circular(AppRadius.destaque),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BEM-VINDO',
                        style: AppText.overline
                            .copyWith(color: cores.textOnHeaderMuted)),
                    const SizedBox(height: AppSpacing.x8),
                    Text('Seu diário de treino',
                        style: AppText.displayM
                            .copyWith(color: cores.textOnHeader)),
                    const SizedBox(height: AppSpacing.x8),
                    Text(
                      'Registre seus treinos (mesmo dias depois) e acompanhe a '
                      'evolução por exercício. Comece montando suas fichas ou '
                      'registrando um treino avulso.',
                      style: AppText.body
                          .copyWith(color: cores.textOnHeaderMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x24),
              const _Passo(
                icone: LucideIcons.listChecks,
                titulo: 'Monte suas fichas',
                texto: 'Crie o Treino A, B, C com os exercícios e seus alvos.',
              ),
              const SizedBox(height: AppSpacing.entreCards),
              const _Passo(
                icone: LucideIcons.pencil,
                titulo: 'Registre o treino',
                texto: 'Anote as séries feitas, com carga e repetições.',
              ),
              const SizedBox(height: AppSpacing.entreCards),
              const _Passo(
                icone: LucideIcons.trendingUp,
                titulo: 'Acompanhe a evolução',
                texto: 'Veja no gráfico como cada exercício progride.',
              ),
              const Spacer(),
              SizedBox(
                height: AppSizes.botaoPrincipal,
                child: FilledButton(
                  onPressed: () => context.go(Rotas.fichas),
                  child: const Text('MONTAR MINHAS FICHAS'),
                ),
              ),
              const SizedBox(height: AppSpacing.entreItens),
              SizedBox(
                height: AppSizes.botaoSecundario,
                child: OutlinedButton(
                  onPressed: () => context.go(Rotas.treinoLivre),
                  child: const Text('Registrar sem ficha'),
                ),
              ),
              const SizedBox(height: AppSpacing.x8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um passo do "como funciona", com ícone, título e explicação curta.
class _Passo extends StatelessWidget {
  const _Passo({
    required this.icone,
    required this.titulo,
    required this.texto,
  });

  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: AppSizes.iconeMd, color: cores.primaryText),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppText.title),
              const SizedBox(height: AppSpacing.x4),
              Text(texto,
                  style: AppText.bodyS.copyWith(color: cores.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
