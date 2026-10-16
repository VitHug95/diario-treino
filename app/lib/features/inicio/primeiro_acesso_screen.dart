import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/plano_models.dart';
import '../planos/acoes_plano.dart';

/// Tela 29 (era a 6): primeiro acesso (PBI-09, PBI-68). Só na Início e só para
/// conta nova: nenhuma sessão e nenhuma ficha (sem plano, ou plano vazio).
/// Explica o app e oferece dois caminhos: o plano e "Registrar treino".
///
/// [plano]: o plano em uso, se houver. Sem plano, o primário cria um ("Criar
/// meu plano"); com plano vazio, abre o detalhe dele ("Montar a primeira
/// ficha"). Nenhum caminho passa pela tela Fichas sem plano (PBI-69).
class PrimeiroAcessoScreen extends ConsumerWidget {
  const PrimeiroAcessoScreen({super.key, this.plano});

  final PlanoAtivo? plano;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      'evolução por exercício. Comece montando seu plano ou '
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
                titulo: 'Monte seu plano',
                texto: 'Crie o plano e as fichas A, B e C, com os exercícios e '
                    'seus alvos.',
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
                child: plano == null
                    ? FilledButton(
                        onPressed: () => criarPlanoEAbrir(context, ref),
                        child: const Text('CRIAR MEU PLANO'),
                      )
                    : FilledButton(
                        onPressed: () => context.go(rotaDoPlano(plano!.id)),
                        child: const Text('MONTAR A PRIMEIRA FICHA'),
                      ),
              ),
              const SizedBox(height: AppSpacing.entreItens),
              SizedBox(
                height: AppSizes.botaoSecundario,
                // Conta nova não tem fichas: "Registrar treino" abre direto o
                // treino livre (PBI-71).
                child: OutlinedButton.icon(
                  onPressed: () => context.go(Rotas.treinoLivre),
                  icon: const Icon(LucideIcons.clipboardCheck,
                      size: AppSizes.iconeSm),
                  label: const Text('Registrar treino'),
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
