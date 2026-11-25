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
import '../medidas/medidas_formato.dart';
import '../medidas/medidas_models.dart';
import '../medidas/perfil_corporal_models.dart';
import 'corpo_do_aluno.dart';

/// O corpo do aluno visto pelo educador (E12 / PBI-96, telas 28 e 29). Só
/// leitura. Cada seção (dados corporais, medidas) aparece só se o aluno a
/// destrancou; trancada, mostra o cadeado e a explicação. A API já garante o
/// vínculo ativo (sem ele, 404) e nunca manda o que está trancado.
class AlunoCorpoScreen extends ConsumerWidget {
  const AlunoCorpoScreen({super.key, required this.atletaId, required this.alunoNome});

  final String atletaId;
  final String alunoNome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corpo = ref.watch(corpoDoAlunoProvider(atletaId));
    return Scaffold(
      appBar: AppBar(title: Text('Corpo de $alunoNome', overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => tentarDeNovo(ref, [corpoDoAlunoProvider(atletaId)]),
          child: corpo.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => EstadoErro(
              mensagem: 'Não foi possível carregar o corpo do aluno.',
              aoTentar: () => tentarDeNovo(ref, [corpoDoAlunoProvider(atletaId)]),
            ),
            data: (c) => _Conteudo(corpo: c, atletaId: atletaId, alunoNome: alunoNome),
          ),
        ),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.corpo, required this.atletaId, required this.alunoNome});

  final CorpoDoAluno corpo;
  final String atletaId;
  final String alunoNome;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.margemTela),
      children: [
        Text('Só leitura: o que o aluno escolheu compartilhar.',
            style: AppText.caption.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x16),
        Text('DADOS CORPORAIS', style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        if (corpo.dadosCorporaisCompartilhados && corpo.dadosCorporais != null)
          _CartaoDados(dados: corpo.dadosCorporais!)
        else
          const _Trancado(texto: 'O aluno não compartilhou os dados corporais.'),
        const SizedBox(height: AppSpacing.x24),
        Text('MEDIDAS CORPORAIS', style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x8),
        if (!corpo.medidasCompartilhadas || corpo.medidas == null)
          const _Trancado(texto: 'O aluno não compartilhou as medidas.')
        else if (corpo.medidas!.ultimas.isEmpty)
          _Cartao(
            child: Text('O aluno ainda não registrou medidas.',
                style: AppText.body.copyWith(color: cores.textSecondary)),
          )
        else
          _CartaoMedidas(medidas: corpo.medidas!, atletaId: atletaId, alunoNome: alunoNome),
      ],
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.child, this.vertical = AppSpacing.paddingCard});

  final Widget child;
  final double vertical;

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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingCard, vertical: vertical),
      child: child,
    );
  }
}

/// Seção trancada (tela 29): o cadeado e a explicação, sem nenhum valor.
class _Trancado extends StatelessWidget {
  const _Trancado({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Semantics(
      container: true,
      label: 'Privado. $texto',
      excludeSemantics: true,
      child: _Cartao(
        child: Row(
          children: [
            Icon(LucideIcons.lock, size: AppSizes.iconeMd, color: cores.iconMuted),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privado', style: AppText.title),
                  const SizedBox(height: AppSpacing.x4),
                  Text(texto, style: AppText.bodyS.copyWith(color: cores.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dados corporais do aluno (tela 28): sexo, idade, altura, peso e a TMB que
/// vale para ele, com o selo "Informada pelo aluno" quando for o caso.
class _CartaoDados extends StatelessWidget {
  const _CartaoDados({required this.dados});

  final PerfilCorporal dados;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final tmb = dados.tmbKcal;
    final String tmbTexto;
    if (tmb != null) {
      tmbTexto = '${formatarMilhar(tmb)} kcal por dia';
    } else if (dados.motivoSemTmb == MotivoSemTmb.menorDeIdade) {
      tmbTexto = 'Só para adultos';
    } else {
      tmbTexto = 'Sem dados para calcular';
    }
    final linhas = <(String, String)>[
      ('Sexo', dados.sexo?.rotulo ?? 'Não informado'),
      ('Idade', dados.idade == null ? 'Não informada' : '${dados.idade} anos'),
      ('Altura', dados.alturaCm == null ? 'Não informada' : '${dados.alturaCm} cm'),
      ('Peso', dados.pesoKg == null ? 'Não informado' : formatarPesoCurto(dados.pesoKg!)),
      ('TMB', tmbTexto),
    ];
    return _Cartao(
      vertical: AppSpacing.x4,
      child: Column(
        children: [
          for (var i = 0; i < linhas.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cores.lineDivider),
            Semantics(
              container: true,
              label: '${linhas[i].$1}: ${linhas[i].$2}'
                  '${linhas[i].$1 == 'TMB' && dados.tmbManual && tmb != null ? ', informada pelo aluno' : ''}',
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                  child: Row(
                    children: [
                      Expanded(child: Text(linhas[i].$1, style: AppText.body)),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(linhas[i].$2,
                                textAlign: TextAlign.end, style: AppText.titleS),
                            if (linhas[i].$1 == 'TMB' && dados.tmbManual && tmb != null)
                              Text('Informada pelo aluno',
                                  style: AppText.caption.copyWith(color: cores.primaryText)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Últimas medidas do aluno; cada uma abre a evolução (sem edição).
class _CartaoMedidas extends StatelessWidget {
  const _CartaoMedidas({required this.medidas, required this.atletaId, required this.alunoNome});

  final ResumoMedidas medidas;
  final String atletaId;
  final String alunoNome;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return _Cartao(
      vertical: AppSpacing.x4,
      child: Column(
        children: [
          for (var i = 0; i < medidas.ultimas.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cores.lineDivider),
            _LinhaMedida(
              ultima: medidas.ultimas[i],
              aoTocar: () => context.push(
                Rotas.alunoMedidaEvolucao,
                extra: AlunoMedidaArgs(
                    atletaId: atletaId, alunoNome: alunoNome, tipo: medidas.ultimas[i].tipo),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaMedida extends StatelessWidget {
  const _LinhaMedida({required this.ultima, required this.aoTocar});

  final UltimaMedida ultima;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final u = ultima;
    final falado = [
      '${u.tipo.rotulo}: ${falarValor(u.valor, u.tipo)} em ${dataCurta(u.data)}',
      if (u.variacao != null) '${falarVariacao(u.variacao!, u.tipo)} desde a medição anterior',
    ].join(', ');
    return Semantics(
      container: true,
      button: true,
      label: '$falado. Toque para ver a evolução',
      excludeSemantics: true,
      child: InkWell(
        onTap: aoTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
            child: Row(
              children: [
                Expanded(child: Text(u.tipo.rotulo, style: AppText.body)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatarComUnidade(u.valor, u.tipo), style: AppText.title),
                    Text(
                      u.variacao == null
                          ? 'em ${dataCurta(u.data)}'
                          : '${formatarVariacao(u.variacao!, u.tipo)} · ${dataCurta(u.data)}',
                      style: AppText.caption.copyWith(color: cores.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.x8),
                Icon(LucideIcons.chevronRight, size: AppSizes.iconeSm, color: cores.iconMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
