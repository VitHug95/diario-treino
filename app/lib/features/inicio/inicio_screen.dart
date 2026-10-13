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
import '../sessao/sessao_models.dart';
import '../sessao/sessao_repository.dart';
import 'inicio_logica.dart';

/// Tela inicial (tela 2 do protótipo), PBI-23 (partes B e A).
///
/// Lista as fichas do plano ativo, recomenda a próxima ficha da sequência
/// (rotação a partir da última registrada — recomendação, não obrigação),
/// mostra a data da última vez de cada ficha e uma faixa semanal (seg→dom)
/// marcando os dias com treino registrado.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final usuario = ref.watch(authStateProvider).value;
    final primeiroNome = (usuario?.displayName ?? 'Atleta').split(' ').first;
    final planoAsync = ref.watch(planoAtivoProvider);
    final sessoesAsync = ref.watch(sessoesRecentesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(planoAtivoProvider);
            ref.invalidate(sessoesRecentesProvider);
          },
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
                data: (plano) => _Conteudo(
                  plano: plano,
                  sessoes: sessoesAsync,
                  aoTentarSessoes: () => ref.invalidate(sessoesRecentesProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decide o que mostrar conforme o estado do plano: sem plano/sem fichas
/// (chamada para montar) ou com fichas (faixa semanal + destaque + lista).
///
/// As sessões (histórico) são tratadas por estado explícito: a recomendação, a
/// faixa semanal e a "última vez" só aparecem quando o histórico carregou. Em
/// carregamento, mostra a lista de fichas sem fingir uma sugestão (evita o bug
/// de sugerir sempre a primeira ficha). Em erro, oferece recarregar.
class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.plano,
    required this.sessoes,
    required this.aoTentarSessoes,
  });

  final PlanoAtivo? plano;
  final AsyncValue<List<SessaoResumo>> sessoes;
  final VoidCallback aoTentarSessoes;

  @override
  Widget build(BuildContext context) {
    final fichas = plano?.treinos ?? const <TreinoResumo>[];
    if (fichas.isEmpty) {
      return const _SemFichas();
    }

    final ordenadas = [...fichas]..sort((a, b) => a.ordem.compareTo(b.ordem));

    return sessoes.when(
      // Histórico carregado: recomendação, semana e "última vez" reais.
      data: (lista) => _ComHistorico(fichas: ordenadas, sessoes: lista),
      // Carregando: mostra as fichas para registrar, sem sugestão prematura.
      loading: () => _SemHistorico(fichas: ordenadas, carregando: true, aoTentar: aoTentarSessoes),
      // Erro: não engole; mostra as fichas e um aviso para recarregar.
      error: (_, __) => _SemHistorico(fichas: ordenadas, carregando: false, aoTentar: aoTentarSessoes),
    );
  }
}

/// Estado completo: histórico disponível. Recomenda a próxima ficha, mostra a
/// faixa semanal e a "última vez" de cada ficha.
class _ComHistorico extends StatelessWidget {
  const _ComHistorico({required this.fichas, required this.sessoes});

  final List<TreinoResumo> fichas;
  final List<SessaoResumo> sessoes;

  @override
  Widget build(BuildContext context) {
    final recomendada = InicioLogica.proximaFicha(fichas, sessoes) ?? fichas.first;
    final ultimaVez = InicioLogica.ultimaVezPorFicha(sessoes);
    final dias = InicioLogica.diasDaSemana(DateTime.now(), sessoes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FaixaSemana(dias: dias, aoTocarDia: (d) => _registrar(context, recomendada, data: d)),
        const SizedBox(height: AppSpacing.x20),
        _CartaoDestaque(ficha: recomendada),
        const SizedBox(height: AppSpacing.x24),
        Text('SUAS FICHAS', style: AppText.overline),
        const SizedBox(height: AppSpacing.x12),
        for (final ficha in fichas) ...[
          _CartaoFicha(ficha: ficha, ultimaVez: ultimaVez[ficha.id]),
          const SizedBox(height: AppSpacing.entreItens),
        ],
      ],
    );
  }
}

/// Estado sem histórico pronto (carregando ou erro): lista as fichas para
/// registrar, sem recomendação nem checks (não finge uma sugestão). Em erro,
/// mostra um aviso discreto com recarregar.
class _SemHistorico extends StatelessWidget {
  const _SemHistorico({
    required this.fichas,
    required this.carregando,
    required this.aoTentar,
  });

  final List<TreinoResumo> fichas;
  final bool carregando;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!carregando)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x12),
            child: Row(
              children: [
                Icon(LucideIcons.cloudOff, size: AppSizes.iconeSm, color: cores.textSecondary),
                const SizedBox(width: AppSpacing.x8),
                Expanded(
                  child: Text('Não foi possível carregar seu histórico.',
                      style: AppText.caption.copyWith(color: cores.textSecondary)),
                ),
                TextButton(onPressed: aoTentar, child: const Text('Recarregar')),
              ],
            ),
          ),
        Text('SUAS FICHAS', style: AppText.overline),
        const SizedBox(height: AppSpacing.x12),
        for (final ficha in fichas) ...[
          _CartaoFicha(ficha: ficha, ultimaVez: null),
          const SizedBox(height: AppSpacing.entreItens),
        ],
      ],
    );
  }
}

/// Abre o registro de uma ficha. [data] opcional pré-seleciona o dia (faixa
/// semanal); hoje é o padrão da própria tela de registro quando não informado.
void _registrar(BuildContext context, TreinoResumo ficha, {DateTime? data}) {
  context.push(
    Rotas.registrarSessao,
    extra: RegistrarSessaoArgs(
      treinoId: ficha.id,
      treinoNome: ficha.nome,
      data: data,
    ),
  );
}

/// Formata uma data como "seg, 13/10".
String _dataCurta(DateTime d) {
  const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  final dia = dias[d.weekday - 1];
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dia, $dd/$mm';
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

/// Faixa dos 7 dias da semana (seg→dom) com check nos dias com treino. Tocar
/// num dia (que não seja futuro) abre o registro naquela data (PBI-23A).
class _FaixaSemana extends StatelessWidget {
  const _FaixaSemana({required this.dias, required this.aoTocarDia});

  final List<DiaSemana> dias;
  final ValueChanged<DateTime> aoTocarDia;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final dia in dias)
          Expanded(
            child: Semantics(
              button: !dia.futuro,
              label: _rotuloAcessivel(dia),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.campoSerie),
                onTap: dia.futuro ? null : () => aoTocarDia(dia.data),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
                  child: Column(
                    children: [
                      Text(dia.inicial,
                          style: AppText.caption.copyWith(
                            color: dia.ehHoje ? cores.primaryText : cores.textSecondary,
                          )),
                      const SizedBox(height: AppSpacing.x6),
                      _MarcaDia(dia: dia, cores: cores),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _rotuloAcessivel(DiaSemana dia) {
    final dd = '${dia.data.day.toString().padLeft(2, '0')}/${dia.data.month.toString().padLeft(2, '0')}';
    if (dia.treinou) return 'Dia $dd, treino registrado';
    if (dia.futuro) return 'Dia $dd, ainda não chegou';
    return 'Dia $dd, sem treino. Toque para registrar';
  }
}

/// Bolinha do dia: check quando treinou; círculo apagado quando não.
class _MarcaDia extends StatelessWidget {
  const _MarcaDia({required this.dia, required this.cores});

  final DiaSemana dia;
  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    const tamanho = 28.0;
    if (dia.treinou) {
      return Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.check,
            size: AppSizes.iconeSm, color: Theme.of(context).colorScheme.onPrimary),
      );
    }
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: dia.ehHoje ? cores.primaryText : cores.lineDefault,
        ),
      ),
    );
  }
}

/// Cartão de recomendação — fundo escuro (bg-header). Sugere a próxima ficha da
/// sequência (rotação a partir da última registrada). É recomendação, não trava:
/// qualquer ficha pode ser registrada pela lista abaixo (PBI-23A).
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
          Text('SUGESTÃO DE HOJE',
              style: AppText.overline.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x8),
          Text(titulo,
              style: AppText.displayM.copyWith(color: cores.textOnHeader)),
          const SizedBox(height: AppSpacing.x4),
          Text('Próxima da sua sequência. Você pode registrar qualquer ficha.',
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

/// Ficha da lista: toque abre o registro direto. Mostra a data da última vez.
class _CartaoFicha extends StatelessWidget {
  const _CartaoFicha({required this.ficha, required this.ultimaVez});

  final TreinoResumo ficha;
  final DateTime? ultimaVez;

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
                    const SizedBox(height: AppSpacing.x4),
                    Text(
                      ultimaVez == null
                          ? 'Ainda não registrada'
                          : 'Última vez: ${_dataCurta(ultimaVez!)}',
                      style: AppText.caption.copyWith(color: cores.textSecondary),
                    ),
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
