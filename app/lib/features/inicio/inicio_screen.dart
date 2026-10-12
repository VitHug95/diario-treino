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
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';

/// Tela inicial (tela 2 do protótipo), PBI-23 (parte B).
///
/// Lista as fichas do plano ativo e permite iniciar o registro com um toque.
/// O "próximo da sequência" inteligente (ficha seguinte à última registrada) e
/// a "data da última vez" dependem do histórico de sessões (PBI-22) e entram
/// quando esse endpoint existir.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final usuario = ref.watch(authStateProvider).value;
    final primeiroNome = (usuario?.displayName ?? 'Atleta').split(' ').first;
    final planoAsync = ref.watch(planoAtivoProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(planoAtivoProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.margemTela),
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
              planoAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.x28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _Erro(
                  aoTentar: () => ref.invalidate(planoAtivoProvider),
                ),
                data: (plano) => _Conteudo(plano: plano),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decide o que mostrar conforme o estado do plano: sem plano/sem fichas
/// (chamada para montar) ou com fichas (destaque + lista para registrar).
class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.plano});

  final PlanoAtivo? plano;

  @override
  Widget build(BuildContext context) {
    final fichas = plano?.treinos ?? const <TreinoResumo>[];
    if (fichas.isEmpty) {
      return const _SemFichas();
    }

    // Respeita a ordem das fichas; a primeira é o destaque "comece por aqui".
    final ordenadas = [...fichas]..sort((a, b) => a.ordem.compareTo(b.ordem));
    final destaque = ordenadas.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CartaoDestaque(ficha: destaque),
        const SizedBox(height: AppSpacing.x24),
        Text('SUAS FICHAS', style: AppText.overline),
        const SizedBox(height: AppSpacing.x12),
        for (final ficha in ordenadas) ...[
          _CartaoFicha(ficha: ficha),
          const SizedBox(height: AppSpacing.entreItens),
        ],
      ],
    );
  }
}

void _registrar(BuildContext context, TreinoResumo ficha) {
  context.push(
    Rotas.registrarSessao,
    extra: RegistrarSessaoArgs(treinoId: ficha.id, treinoNome: ficha.nome),
  );
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

/// Cartão "próximo da sequência" — fundo escuro (bg-header). Hoje destaca a
/// primeira ficha da ordem (PBI-23 parte B); o cálculo pela última registrada
/// entra com o histórico de sessões (PBI-22).
class _CartaoDestaque extends StatelessWidget {
  const _CartaoDestaque({required this.ficha});

  final TreinoResumo ficha;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final titulo = ficha.descricao != null && ficha.descricao!.isNotEmpty
        ? '${ficha.nome} · ${ficha.descricao}'
        : ficha.nome;

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
          Text('COMECE POR AQUI',
              style: AppText.overline.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x8),
          Text(titulo,
              style: AppText.displayM.copyWith(color: cores.textOnHeader)),
          const SizedBox(height: AppSpacing.x4),
          Text('Toque para registrar o treino de hoje.',
              style: AppText.body.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x16),
          FilledButton.icon(
            onPressed: () => _registrar(context, ficha),
            icon: const Icon(LucideIcons.clipboardCheck, size: AppSizes.iconeSm),
            label: const Text('REGISTRAR TREINO'),
          ),
        ],
      ),
    );
  }
}

/// Ficha da lista: toque abre o registro direto.
class _CartaoFicha extends StatelessWidget {
  const _CartaoFicha({required this.ficha});

  final TreinoResumo ficha;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temDescricao = ficha.descricao != null && ficha.descricao!.isNotEmpty;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => _registrar(context, ficha),
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
                    Text(ficha.nome, style: AppText.title),
                    if (temDescricao) ...[
                      const SizedBox(height: AppSpacing.x4),
                      Text(ficha.descricao!,
                          style: AppText.caption
                              .copyWith(color: cores.textSecondary)),
                    ],
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
}

/// Sem plano ou sem fichas: convida a montar as fichas.
class _SemFichas extends StatelessWidget {
  const _SemFichas();

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
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

class _Erro extends StatelessWidget {
  const _Erro({required this.aoTentar});

  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x24),
      child: Column(
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: cores.iconMuted),
          const SizedBox(height: AppSpacing.x12),
          Text('Não foi possível carregar suas fichas.',
              style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
