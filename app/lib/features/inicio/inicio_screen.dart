import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/flags.dart';
import '../../core/relogio.dart';
import '../../core/rotas/app_router.dart';
import '../../core/tema/tema_controller.dart';
import '../../shared/estado_erro.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../auth/auth_service.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';
import '../planos/plano_detalhe_screen.dart' show QuadradoFicha, rotuloQuadradoFicha;
import '../sessao/iniciar_treino_ao_vivo.dart';
import '../sessao/sessao_models.dart';
import '../sessao/sessao_repository.dart';
import '../sessao/treino_em_andamento.dart';
import 'dicas.dart';
import 'inicio_logica.dart';
import 'primeiro_acesso_screen.dart';

/// Tela inicial (tela 23, PBI-59): a semana e o último treino, de relance.
/// Sem lista de fichas nem sugestão: treinar fica nas telas de plano (PBI-61).
///
/// Tocar num dia (menos os futuros) abre a folha do dia: o que foi registrado
/// nele e como registrar um treino naquele dia (fichas do plano em uso ou
/// "Sem ficha").
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
    final emAndamento = ref.watch(treinoEmAndamentoProvider);

    // Primeiro acesso (tela 6) no lugar da inicial quando:
    // - não há plano em uso (PBI-47: todos os planos excluídos), mesmo que já
    //   existam sessões; ou
    // - há plano em uso, mas sem fichas e sem nenhuma sessão (PBI-09).
    // Exige os dados carregados para não piscar a tela de boas-vindas durante o
    // carregamento ou um erro de rede.
    final plano = planoAsync.value;
    final sessoes = sessoesAsync.value;
    final semPlanoEmUso = planoAsync.hasValue && plano == null;
    final semFichas = plano == null || plano.treinos.isEmpty;
    final semSessoes = sessoes != null && sessoes.isEmpty;
    if (semPlanoEmUso ||
        (planoAsync.hasValue && sessoesAsync.hasValue && semFichas && semSessoes)) {
      return const PrimeiroAcessoScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async =>
              tentarDeNovo(ref, [planoAtivoProvider, sessoesRecentesProvider]),
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
                  const SizedBox(width: AppSpacing.x8),
                  IconButton(
                    onPressed: () => context.push(Rotas.perfil),
                    icon: const Icon(LucideIcons.user),
                    tooltip: 'Perfil',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x20),
              // Treino em andamento: sempre no topo, nunca some (PBI-59).
              if (emAndamento != null) ...[
                _ContinuarTreino(treino: emAndamento),
                const SizedBox(height: AppSpacing.x20),
              ],
              planoAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.x28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => EstadoErro(
                  mensagem: 'Não foi possível carregar suas fichas.',
                  aoTentar: () => ref.refresh(planoAtivoProvider),
                ),
                data: (plano) => _Conteudo(
                  plano: plano,
                  sessoes: sessoesAsync,
                  aoTentarSessoes: () => ref.refresh(sessoesRecentesProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semana, último treino e, se o plano em uso não tem fichas, o convite para
/// montar.
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
    final fichas = [...?plano?.treinos]..sort((a, b) => a.ordem.compareTo(b.ordem));
    final ultima = sessoes.whenOrNull(data: InicioLogica.ultimaSessao);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartaoSemana(
          sessoes: sessoes,
          aoTentar: aoTentarSessoes,
          aoTocarDia: (dia, lista) => abrirFolhaDoDia(context,
              dia: dia,
              sessoes: InicioLogica.sessoesDoDia(dia, lista),
              fichas: fichas,
              planoNome: plano?.nome),
        ),
        if (ultima != null) ...[
          const SizedBox(height: AppSpacing.entreCards),
          _CartaoUltimoTreino(sessao: ultima),
        ],
        // Dica de treino do acesso (PBI-60).
        const _CartaoDica(),
        if (fichas.isEmpty) ...[
          const SizedBox(height: AppSpacing.x20),
          const _SemFichas(),
        ],
      ],
    );
  }
}

/// Cartão "Dica de treino" (PBI-60): uma dica por acesso ao app, que troca no
/// acesso seguinte. Sem dicas, não aparece.
class _CartaoDica extends ConsumerWidget {
  const _CartaoDica();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dica = ref.watch(dicaDoAcessoProvider);
    if (dica == null) return const SizedBox.shrink();
    final cores = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.entreCards),
      child: Semantics(
        container: true,
        label: 'Dica de treino: $dica',
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizes.touchMin,
                height: AppSizes.touchMin,
                decoration: BoxDecoration(
                  color: cores.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.campoSerie),
                ),
                child: Icon(LucideIcons.lightbulb,
                    size: AppSizes.iconeSm, color: cores.primaryOnTint),
              ),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DICA DE TREINO',
                        style: AppText.overline.copyWith(color: cores.textSecondary)),
                    const SizedBox(height: AppSpacing.x4),
                    Text(dica, style: AppText.body.copyWith(color: cores.textStrong)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartão "Esta semana": seg a dom e "N dias treinados". Carregando, um
/// indicador; erro, aviso com "Tentar de novo" (nunca uma semana vazia falsa).
class _CartaoSemana extends StatelessWidget {
  const _CartaoSemana({
    required this.sessoes,
    required this.aoTentar,
    required this.aoTocarDia,
  });

  final AsyncValue<List<SessaoResumo>> sessoes;
  final VoidCallback aoTentar;
  final void Function(DateTime dia, List<SessaoResumo> sessoes) aoTocarDia;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final dias = sessoes.whenOrNull(
        data: (lista) => InicioLogica.diasDaSemana(DateTime.now(), lista));
    final treinados = dias?.where((d) => d.treinou).length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: cores.lineDefault),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      // Lateral menor que a do card (8): sete alvos de 44 px cabem em 360 px.
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x8, vertical: AppSpacing.paddingCardCompacto),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
            child: Row(
              children: [
                Expanded(
                  child: Text('ESTA SEMANA',
                      style: AppText.overline.copyWith(color: cores.textSecondary)),
                ),
                if (treinados != null)
                  Text('$treinados ${treinados == 1 ? 'dia treinado' : 'dias treinados'}',
                      style: AppText.caption.copyWith(color: cores.textStrong)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          sessoes.when(
            data: (lista) => _FaixaSemana(
              dias: dias!,
              aoTocarDia: (dia) => aoTocarDia(dia, lista),
            ),
            loading: () => const SizedBox(
              height: 64,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
              child: Row(
                children: [
                  Icon(LucideIcons.cloudOff,
                      size: AppSizes.iconeSm, color: cores.textSecondary),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(
                    child: Text('Não foi possível carregar seu histórico.',
                        style: AppText.caption.copyWith(color: cores.textSecondary)),
                  ),
                  TextButton(onPressed: aoTentar, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa dos 7 dias (seg→dom). Quatro estados que não dependem só da cor:
/// treinou (círculo cheio com check), passado sem treino (círculo vazio), hoje
/// (anel e letra azuis) e futuro (tracejado, sem toque).
class _FaixaSemana extends StatelessWidget {
  const _FaixaSemana({required this.dias, required this.aoTocarDia});

  final List<DiaSemana> dias;
  final ValueChanged<DateTime> aoTocarDia;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Row(
      children: [
        for (final dia in dias)
          Expanded(
            child: Semantics(
              // Nó próprio também no dia futuro (sem toque), para o leitor de
              // tela anunciar cada dia separado.
              container: true,
              button: !dia.futuro,
              label: _rotuloAcessivel(dia),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.campoSerie),
                onTap: dia.futuro ? null : () => aoTocarDia(dia.data),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
                    child: Column(
                      children: [
                        Text(dia.inicial,
                            style: AppText.caption.copyWith(
                              color: dia.ehHoje ? cores.primaryText : cores.textSecondary,
                              fontWeight: dia.ehHoje ? FontWeight.w700 : null,
                            )),
                        const SizedBox(height: AppSpacing.x6),
                        _MarcaDia(dia: dia, cores: cores),
                      ],
                    ),
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

/// Marca do dia, conforme o estado (ver [_FaixaSemana]).
class _MarcaDia extends StatelessWidget {
  const _MarcaDia({required this.dia, required this.cores});

  final DiaSemana dia;
  final AppColors cores;

  static const _tamanho = 28.0;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (dia.treinou) {
      return Container(
        width: _tamanho,
        height: _tamanho,
        decoration: BoxDecoration(color: esquema.primary, shape: BoxShape.circle),
        child: Icon(LucideIcons.check, size: AppSizes.iconeSm, color: esquema.onPrimary),
      );
    }
    if (dia.futuro) {
      return CustomPaint(
        size: const Size.square(_tamanho),
        painter: _CirculoTracejado(cor: cores.lineDashed),
      );
    }
    return Container(
      width: _tamanho,
      height: _tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Hoje: anel azul mais grosso. Passado sem treino: círculo vazio.
        border: dia.ehHoje
            ? Border.all(color: cores.primaryText, width: 2)
            : Border.all(color: cores.lineDashed, width: 1.5),
      ),
    );
  }
}

/// Círculo tracejado do dia futuro.
class _CirculoTracejado extends CustomPainter {
  _CirculoTracejado({required this.cor});

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    const tracos = 12;
    const preenchido = 0.55; // fração de cada passo que é traço
    final raio = size.width / 2 - 0.75;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: raio);
    final pincel = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const passo = 2 * math.pi / tracos;
    for (var i = 0; i < tracos; i++) {
      canvas.drawArc(rect, i * passo, passo * preenchido, false, pincel);
    }
  }

  @override
  bool shouldRepaint(_CirculoTracejado old) => old.cor != cor;
}

/// Cartão "Último treino": ficha (ou "Treino livre"), data e quantidade de
/// exercícios. Toque abre o detalhe da sessão.
class _CartaoUltimoTreino extends StatelessWidget {
  const _CartaoUltimoTreino({required this.sessao});

  final SessaoResumo sessao;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final nome = _nomeSessao(sessao);
    final resumo = '${dataCurtaInicio(sessao.data)} · ${_exercicios(sessao.quantidadeExercicios)}';

    return Semantics(
      button: true,
      label: 'Último treino: $nome, $resumo. Abrir detalhe',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => _abrirSessao(context, sessao),
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
                      Text('ÚLTIMO TREINO',
                          style: AppText.overline.copyWith(color: cores.textSecondary)),
                      const SizedBox(height: AppSpacing.x6),
                      Text(nome, style: AppText.title),
                      const SizedBox(height: AppSpacing.x4),
                      Text(resumo,
                          style: AppText.caption.copyWith(color: cores.textSecondary)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: cores.iconMuted, size: AppSizes.iconeMd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _abrirSessao(BuildContext context, SessaoResumo sessao) => context.push(
      Rotas.detalheSessao,
      extra: DetalheSessaoArgs(sessaoId: sessao.id, treinoNome: sessao.treinoNome),
    );

String _nomeSessao(SessaoResumo s) =>
    (s.treinoNome == null || s.treinoNome!.isEmpty) ? 'Treino livre' : s.treinoNome!;

String _exercicios(int n) => '$n ${n == 1 ? 'exercício' : 'exercícios'}';

/// Formata uma data como "seg, 13/10".
String dataCurtaInicio(DateTime d) {
  const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  final dia = dias[d.weekday - 1];
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dia, $dd/$mm';
}

/// O que o atleta escolheu na folha do dia.
sealed class _EscolhaDia {
  const _EscolhaDia();
}

class _VerSessao extends _EscolhaDia {
  const _VerSessao(this.sessao);
  final SessaoResumo sessao;
}

class _RegistrarFicha extends _EscolhaDia {
  const _RegistrarFicha(this.ficha);
  final TreinoResumo ficha;
}

class _RegistrarSemFicha extends _EscolhaDia {
  const _RegistrarSemFicha();
}

/// Folha do dia (PBI-59): título "qua, 14/10", o que foi registrado nele e as
/// opções de registrar um treino naquele dia. A folha só devolve a escolha; a
/// navegação sai daqui, com o contexto da Início.
Future<void> abrirFolhaDoDia(
  BuildContext context, {
  required DateTime dia,
  required List<SessaoResumo> sessoes,
  required List<TreinoResumo> fichas,
  required String? planoNome,
}) async {
  final escolha = await showModalBottomSheet<_EscolhaDia>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FolhaDoDia(
      dia: dia,
      sessoes: sessoes,
      fichas: fichas,
      planoNome: planoNome,
    ),
  );
  if (escolha == null || !context.mounted) return;

  switch (escolha) {
    case _VerSessao(:final sessao):
      _abrirSessao(context, sessao);
    case _RegistrarFicha(:final ficha):
      // Registro retroativo (data editável, duração digitada), no dia tocado.
      context.push(
        Rotas.registrarSessao,
        extra: RegistrarSessaoArgs(
          treinoId: ficha.id,
          treinoNome: ficha.nome,
          data: dia,
          registroPosterior: true,
        ),
      );
    case _RegistrarSemFicha():
      context.push(Rotas.treinoLivre, extra: dia);
  }
}

class _FolhaDoDia extends StatelessWidget {
  const _FolhaDoDia({
    required this.dia,
    required this.sessoes,
    required this.fichas,
    required this.planoNome,
  });

  final DateTime dia;
  final List<SessaoResumo> sessoes;
  final List<TreinoResumo> fichas;
  final String? planoNome;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    void escolher(_EscolhaDia e) => Navigator.of(context).pop(e);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.margemTela, 0, AppSpacing.margemTela, AppSpacing.margemTela),
          children: [
            Semantics(
              header: true,
              child: Text(dataCurtaInicio(dia), style: AppText.displayS),
            ),
            if (sessoes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x16),
              Text('REGISTRADO', style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              for (final s in sessoes) ...[
                _LinhaFolha(
                  inicio: Icon(LucideIcons.checkCircle,
                      size: AppSizes.iconeMd, color: cores.primaryText),
                  titulo: _nomeSessao(s),
                  subtitulo: [
                    _exercicios(s.quantidadeExercicios),
                    if (s.duracaoMin != null) '${s.duracaoMin} min',
                  ].join(' · '),
                  rotulo: 'Ver treino ${_nomeSessao(s)}',
                  aoTocar: () => escolher(_VerSessao(s)),
                ),
                const SizedBox(height: AppSpacing.entreItens),
              ],
            ],
            const SizedBox(height: AppSpacing.x16),
            Text(
              sessoes.isEmpty ? 'REGISTRAR TREINO NESTE DIA' : 'REGISTRAR OUTRO TREINO NESTE DIA',
              style: AppText.overline.copyWith(color: cores.textSecondary),
            ),
            if (fichas.isNotEmpty && planoNome != null) ...[
              const SizedBox(height: AppSpacing.x4),
              Text('Fichas do plano $planoNome',
                  style: AppText.caption.copyWith(color: cores.textSecondary)),
            ],
            const SizedBox(height: AppSpacing.x8),
            for (var i = 0; i < fichas.length; i++) ...[
              _LinhaFolha(
                inicio: QuadradoFicha(texto: rotuloQuadradoFicha(fichas[i].nome, i + 1)),
                titulo: fichas[i].nome,
                subtitulo: fichas[i].descricao,
                rotulo: 'Registrar ${fichas[i].nome} em ${dataCurtaInicio(dia)}',
                aoTocar: () => escolher(_RegistrarFicha(fichas[i])),
              ),
              const SizedBox(height: AppSpacing.entreItens),
            ],
            _LinhaFolha(
              inicio: Icon(LucideIcons.plus, size: AppSizes.iconeMd, color: cores.textStrong),
              titulo: 'Sem ficha',
              subtitulo: 'Treino livre',
              rotulo: 'Registrar sem ficha em ${dataCurtaInicio(dia)}',
              aoTocar: () => escolher(const _RegistrarSemFicha()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma opção da folha do dia: ícone ou quadrado, título e subtítulo.
class _LinhaFolha extends StatelessWidget {
  const _LinhaFolha({
    required this.inicio,
    required this.titulo,
    required this.subtitulo,
    required this.rotulo,
    required this.aoTocar,
  });

  final Widget inicio;
  final String titulo;
  final String? subtitulo;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temSub = subtitulo != null && subtitulo!.trim().isNotEmpty;
    return Semantics(
      button: true,
      label: rotulo,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.campoForm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.campoForm),
          onTap: aoTocar,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.campoForm),
            decoration: BoxDecoration(
              border: Border.all(color: cores.lineDefault),
              borderRadius: BorderRadius.circular(AppRadius.campoForm),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
            child: Row(
              children: [
                inicio,
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: AppText.titleS),
                      if (temSub)
                        Text(subtitulo!,
                            style: AppText.caption.copyWith(color: cores.textSecondary)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: cores.iconMuted, size: AppSizes.iconeSm),
              ],
            ),
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

/// Card "Continuar treino" (PBI-37): aparece quando há um treino em andamento
/// salvo no aparelho. Toque reabre o registro de onde parou.
class _ContinuarTreino extends ConsumerWidget {
  const _ContinuarTreino({required this.treino});

  final TreinoEmAndamento treino;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    final feitos = treino.exercicios.where((e) => e.realizado).length;
    final total = treino.exercicios.length;
    final tempo =
        minutosEmAndamento(ref.read(relogioProvider).agora(), treino.inicio);

    return Material(
      color: cores.primaryTint,
      borderRadius: BorderRadius.circular(AppRadius.card),
      // PBI-67: o leitor de tela ouve há quanto tempo o treino está aberto.
      child: Semantics(
        button: true,
        label: 'Continuar treino ${treino.treinoNome}, em andamento há $tempo, '
            '$feitos de $total exercícios marcados',
        excludeSemantics: true,
        child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () {
          // Flag TV-3: retoma na tela 14 ao vivo. O treino livre segue no
          // fluxo antigo (ainda não tem versão ao vivo).
          if (treinoAoVivoHabilitado &&
              !treino.treinoLivre &&
              treino.treinoId != null) {
            if (retomarTreinoAoVivo(context, ref)) return;
          }
          if (treino.treinoLivre || treino.treinoId == null) {
            context.push(Rotas.treinoLivre);
          } else {
            context.push(
              Rotas.registrarSessao,
              extra: RegistrarSessaoArgs(
                treinoId: treino.treinoId!,
                treinoNome: treino.treinoNome,
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Row(
            children: [
              Icon(LucideIcons.play, color: cores.primaryOnTint, size: AppSizes.iconeMd),
              const SizedBox(width: AppSpacing.x12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Continuar treino',
                        style: AppText.overline.copyWith(color: cores.primaryOnTint)),
                    const SizedBox(height: AppSpacing.x4),
                    Text(treino.treinoNome,
                        style: AppText.title.copyWith(color: cores.primaryOnTint)),
                    Text('$feitos de $total exercícios marcados',
                        style: AppText.caption.copyWith(color: cores.primaryOnTint)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  color: cores.primaryOnTint, size: AppSizes.iconeMd),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Plano em uso sem fichas (já treinou sem ficha): convida a montar.
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
          Text('PLANO EM USO',
              style: AppText.overline.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x8),
          Text('Monte suas fichas',
              style: AppText.displayM.copyWith(color: cores.textOnHeader)),
          const SizedBox(height: AppSpacing.x4),
          Text('Crie o Treino A, B, C para começar a registrar.',
              style: AppText.body.copyWith(color: cores.textOnHeaderMuted)),
          const SizedBox(height: AppSpacing.x16),
          FilledButton(
            // Direto nas fichas do plano em uso (cria o primeiro ao salvar a
            // primeira ficha), como antes da lista de planos.
            onPressed: () => context.go(Rotas.fichaDoPlano),
            child: const Text('MONTAR FICHAS'),
          ),
        ],
      ),
    );
  }
}

// _Erro extraído para shared/estado_erro.dart (PBI-51).
