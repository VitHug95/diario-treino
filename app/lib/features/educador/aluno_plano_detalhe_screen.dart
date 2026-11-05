import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/dialogo_ficha.dart';
import '../fichas/fichas_comandos.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/fichas_screen.dart';
import '../fichas/plano_models.dart';
import '../../shared/mostrar_aviso.dart';
import '../planos/acoes_plano.dart';
import 'educador_repository.dart';

/// Argumentos para abrir o detalhe de um plano do aluno (PBI-88d).
class AlunoPlanoDetalheArgs {
  const AlunoPlanoDetalheArgs({
    required this.atletaId,
    required this.alunoNome,
    required this.planoId,
  });
  final String atletaId;
  final String alunoNome;
  final String planoId;
}

/// Detalhe de um plano do aluno pelo educador (PBI-88d): as fichas do plano,
/// com "Nova ficha" e o toque abrindo o editor da ficha (o mesmo do atleta,
/// que grava por `treinoId` — a API autoriza pelo vínculo). Montar a ficha
/// (exercícios e alvos) acontece no editor reusado.
class AlunoPlanoDetalheScreen extends ConsumerWidget {
  const AlunoPlanoDetalheScreen({
    super.key,
    required this.atletaId,
    required this.alunoNome,
    required this.planoId,
  });

  final String atletaId;
  final String alunoNome;
  final String planoId;

  ({String atletaId, String planoId}) get _chave =>
      (atletaId: atletaId, planoId: planoId);

  Future<void> _novaFicha(BuildContext context, WidgetRef ref) async {
    final dados = await dialogoFicha(context);
    if (dados == null || !context.mounted) return;
    try {
      await ref.read(fichasComandosProvider).adicionarFicha(
          planoId: planoId, nome: dados.nome, descricao: dados.descricao);
      // Confirmação sem ação: pílula, igual ao detalhe do plano do atleta.
      if (context.mounted) mostrarAviso(context, 'Ficha “${dados.nome}” criada');
    } on FichasException catch (e) {
      if (context.mounted) avisarPlano(context, e.mensagem);
    }
  }

  /// Abre o editor da ficha (tela 22) empilhado sobre o fluxo do educador. O
  /// editor grava por `treinoId`/`planoId`; o backend autoriza pelo vínculo.
  void _abrirFicha(BuildContext context, String fichaId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FichasScreen(
          key: ValueKey('aluno:$atletaId|plano:$planoId|ficha:$fichaId'),
          planoId: planoId,
          fichaInicialId: fichaId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final planoAsync = ref.watch(planoDoAlunoDetalheProvider(_chave));

    return Scaffold(
      appBar: AppBar(
        title: planoAsync.maybeWhen(
          data: (p) => Text(p.nome),
          orElse: () => Text('Plano de $alunoNome'),
        ),
      ),
      body: SafeArea(
        child: planoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => EstadoErro(
            mensagem: 'Não foi possível carregar o plano.',
            aoTentar: () =>
                tentarDeNovo(ref, [planoDoAlunoDetalheProvider(_chave)]),
          ),
          data: (plano) => RefreshIndicator(
            onRefresh: () =>
                ref.refresh(planoDoAlunoDetalheProvider(_chave).future),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.margemTela),
              children: [
                Text('FICHAS',
                    style:
                        AppText.overline.copyWith(color: cores.textSecondary)),
                const SizedBox(height: AppSpacing.x8),
                if (plano.treinos.isEmpty)
                  _SemFichas(
                    alunoNome: alunoNome,
                    aoCriar: () => _novaFicha(context, ref),
                  )
                else ...[
                  for (final ficha in plano.treinos) ...[
                    _CartaoFicha(
                      ficha: ficha,
                      aoAbrir: () => _abrirFicha(context, ficha.id),
                    ),
                    const SizedBox(height: AppSpacing.entreItens),
                  ],
                  const SizedBox(height: AppSpacing.x8),
                  OutlinedButton.icon(
                    onPressed: () => _novaFicha(context, ref),
                    icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
                    label: const Text('Nova ficha'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão de uma ficha do plano do aluno: nome, descrição e seta. Toca abre o
/// editor.
class _CartaoFicha extends StatelessWidget {
  const _CartaoFicha({required this.ficha, required this.aoAbrir});

  final TreinoResumo ficha;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final descricao = ficha.descricao?.trim() ?? '';

    return Semantics(
      button: true,
      label: 'Abrir ficha ${ficha.nome}',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: aoAbrir,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
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
                      if (descricao.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.x4),
                        Text(descricao,
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
      ),
    );
  }
}

/// Plano do aluno ainda sem fichas: convida a montar a primeira.
class _SemFichas extends StatelessWidget {
  const _SemFichas({required this.alunoNome, required this.aoCriar});

  final String alunoNome;
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: LucideIcons.listChecks,
      titulo: 'Nenhuma ficha ainda',
      texto: 'Monte a primeira ficha deste plano. '
          'Depois é só adicionar os exercícios e os alvos.',
      acao: FilledButton.icon(
        onPressed: aoCriar,
        icon: const Icon(LucideIcons.plus, size: AppSizes.iconeSm),
        label: const Text('NOVA FICHA'),
      ),
    );
  }
}
