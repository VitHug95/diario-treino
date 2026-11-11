import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/estado_erro.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'medidas_formato.dart';
import 'medidas_models.dart';
import 'medidas_repository.dart';

/// Medidas corporais (E12 / PBI-92, tela 24): botão para registrar, as últimas
/// medidas de cada tipo com a variação e o histórico por dia. Todas as medidas
/// existem e nenhuma é obrigatória: tipo sem registro mostra "Sem registro".
class MedidasCorporaisScreen extends ConsumerWidget {
  const MedidasCorporaisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(resumoMedidasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Medidas corporais')),
      body: SafeArea(
        child: resumo.when(
          // Centralizado e com altura própria: a tela não "pula" ao carregar.
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar suas medidas.',
            aoTentar: () => tentarDeNovo(ref, [resumoMedidasProvider]),
          ),
          data: (dados) => _Conteudo(resumo: dados),
        ),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.resumo});

  final ResumoMedidas resumo;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        SizedBox(
          height: AppSizes.botaoPrincipal,
          child: FilledButton.icon(
            onPressed: () => context.push(Rotas.registrarMedidas),
            icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
            label: const Text('Registrar medidas'),
          ),
        ),
        const SizedBox(height: AppSpacing.x24),
        if (resumo.vazio)
          _CartaoVazio()
        else ...[
          Text('ÚLTIMAS MEDIDAS',
              style: AppText.overline.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x8),
          _CartaoUltimas(resumo: resumo),
          const SizedBox(height: AppSpacing.x8),
          Text(
            'A variação compara com a medição anterior de cada medida.',
            style: AppText.caption.copyWith(color: cores.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x24),
          Text('HISTÓRICO',
              style: AppText.overline.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x8),
          for (final dia in resumo.historico) ...[
            _LinhaHistorico(dia: dia),
            const SizedBox(height: AppSpacing.entreItens),
          ],
        ],
      ],
    );
  }
}

class _CartaoVazio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          Text('Nenhuma medida ainda', style: AppText.title),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Registre a primeira. Você mede só o que quiser, no seu ritmo.',
            style: AppText.body.copyWith(color: cores.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Uma linha por tipo, na ordem de [TipoMedida]. A linha com registro abre o
/// gráfico da evolução (PBI-94); a sem registro fica sem ação e sem seta.
class _CartaoUltimas extends StatelessWidget {
  const _CartaoUltimas({required this.resumo});

  final ResumoMedidas resumo;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingCard, vertical: AppSpacing.x4),
      child: Column(
        children: [
          for (var i = 0; i < TipoMedida.values.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cores.lineDivider),
            _LinhaMedida(
              tipo: TipoMedida.values[i],
              ultima: resumo.ultimaDe(TipoMedida.values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaMedida extends StatelessWidget {
  const _LinhaMedida({required this.tipo, required this.ultima});

  final TipoMedida tipo;
  final UltimaMedida? ultima;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final u = ultima;

    final falado = u == null
        ? '${tipo.rotulo}: sem registro'
        : [
            '${tipo.rotulo}: ${falarValor(u.valor, tipo)}',
            if (u.variacao != null)
              '${falarVariacao(u.variacao!, tipo)} desde a medição anterior',
          ].join(', ');

    // container: cada linha é um item próprio para o leitor de tela (sem isso o
    // cartão inteiro viraria uma frase só).
    final conteudo = Container(
      constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: Row(
        children: [
          Expanded(child: Text(tipo.rotulo, style: AppText.body)),
          if (u == null)
            Text('Sem registro',
                style: AppText.body.copyWith(color: cores.textSecondary))
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatarComUnidade(u.valor, tipo), style: AppText.title),
                if (u.variacao != null) _Variacao(variacao: u.variacao!, tipo: tipo),
              ],
            ),
            const SizedBox(width: AppSpacing.x8),
            Icon(LucideIcons.chevronRight,
                size: AppSizes.iconeSm, color: cores.iconMuted),
          ],
        ],
      ),
    );

    if (u == null) {
      return Semantics(
        container: true,
        label: falado,
        excludeSemantics: true,
        child: conteudo,
      );
    }

    return Semantics(
      container: true,
      button: true,
      label: '$falado. Toque para ver a evolução',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(Rotas.medidaEvolucao, extra: tipo),
        child: conteudo,
      ),
    );
  }
}
/// Seta + sinal + valor: a direção nunca depende só de cor.
class _Variacao extends StatelessWidget {
  const _Variacao({required this.variacao, required this.tipo});

  final double variacao;
  final TipoMedida tipo;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final igual = variacao.abs() < 0.05;
    final icone = igual
        ? LucideIcons.minus
        : (variacao < 0 ? LucideIcons.trendingDown : LucideIcons.trendingUp);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: AppSizes.iconeSm, color: cores.textSecondary),
        const SizedBox(width: AppSpacing.x4),
        Text(formatarVariacao(variacao, tipo),
            style: AppText.caption.copyWith(color: cores.textSecondary)),
      ],
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  const _LinhaHistorico({required this.dia});

  final DiaHistoricoMedidas dia;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final quantidade =
        dia.quantidade == 1 ? '1 medida' : '${dia.quantidade} medidas';
    final data = dataCompleta(dia.data);
    return Semantics(
      container: true,
      button: true,
      label: 'Medição de $data, $quantidade. Toque para abrir',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(Rotas.registrarMedidas, extra: dia.data),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            children: [
              Icon(LucideIcons.calendar,
                  size: AppSizes.iconeSm, color: cores.iconMuted),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: Text(data, style: AppText.titleS)),
              Text(quantidade,
                  style: AppText.caption.copyWith(color: cores.textSecondary)),
              const SizedBox(width: AppSpacing.x8),
              Icon(LucideIcons.chevronRight,
                  size: AppSizes.iconeSm, color: cores.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}
