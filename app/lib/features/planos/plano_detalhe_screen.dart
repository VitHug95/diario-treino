import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rotas/app_router.dart';
import '../../shared/botao_tracejado.dart';
import '../../shared/dialogos_perigo.dart';
import '../../shared/estado_erro.dart';
import '../../shared/estado_vazio.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/dialogo_ficha.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';
import '../inicio/inicio_logica.dart';
import '../sessao/sessao_repository.dart';
import 'acoes_plano.dart';

/// Tela 19 (PBI-46): detalhe de um plano, com as fichas dele. Dá para abrir
/// qualquer ficha (tela 13) e treinar mesmo com o plano fora de uso: a sessão
/// fica ligada à ficha e a Início continua seguindo o plano em uso.
///
/// [planoId] nulo abre o plano em uso.
class PlanoDetalheScreen extends ConsumerStatefulWidget {
  const PlanoDetalheScreen({super.key, this.planoId});

  final String? planoId;

  @override
  ConsumerState<PlanoDetalheScreen> createState() => _PlanoDetalheScreenState();
}

class _PlanoDetalheScreenState extends ConsumerState<PlanoDetalheScreen> {
  /// Fica true depois que o atleta toca em "Definir como plano em uso" nesta
  /// tela, para o botão virar "Este plano está em uso" (critério 7).
  bool _definidoAgora = false;

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Rotas.fichas);
    }
  }

  Future<void> _definirEmUso(PlanoDetalhe plano) async {
    try {
      await ref.read(fichasRepositoryProvider).definirEmUso(plano.id);
      atualizarPlanos(ref);
      if (mounted) setState(() => _definidoAgora = true);
    } on FichasException catch (e) {
      if (mounted) avisarPlano(context, e.mensagem);
    }
  }

  Future<void> _novaFicha(PlanoDetalhe plano) async {
    final dados = await dialogoFicha(context);
    if (dados == null) return;
    try {
      await ref.read(fichasRepositoryProvider).adicionarFicha(
          planoId: plano.id, nome: dados.nome, descricao: dados.descricao);
      atualizarPlanos(ref);
    } on FichasException catch (e) {
      if (mounted) avisarPlano(context, e.mensagem);
    }
  }

  Future<void> _duplicar(PlanoDetalhe plano) async {
    if (plano.somenteLeitura && !await confirmarCopiaPlano(context)) return;
    try {
      final id = await ref.read(fichasRepositoryProvider).duplicarPlano(plano.id);
      atualizarPlanos(ref);
      // Abre a cópia no lugar deste plano: a seta volta para a lista.
      if (mounted) {
        context.pushReplacement(
            '${Rotas.planoDetalhe}?id=${Uri.encodeQueryComponent(id)}');
      }
    } on FichasException catch (e) {
      if (mounted) avisarPlano(context, e.mensagem);
    }
  }

  Future<void> _renomear(PlanoDetalhe plano) async {
    final nome = await dialogoNomePlano(context,
        titulo: 'Renomear plano', inicial: plano.nome);
    if (nome == null) return;
    try {
      await ref.read(fichasRepositoryProvider).renomearPlano(planoId: plano.id, nome: nome);
      atualizarPlanos(ref);
    } on FichasException catch (e) {
      if (mounted) avisarPlano(context, e.mensagem);
    }
  }

  Future<void> _excluir(PlanoDetalhe plano) async {
    final confirmou = await confirmarPerigo(
      context,
      titulo: 'Excluir plano?',
      texto: textoExcluirPlano(emUso: plano.emUso),
      rotuloConfirmar: 'Excluir plano',
    );
    if (!confirmou) return;
    try {
      await ref.read(fichasRepositoryProvider).excluirPlano(plano.id);
      atualizarPlanos(ref);
      if (mounted) context.go(Rotas.fichas);
    } on FichasException catch (e) {
      if (mounted) avisarPlano(context, e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planoAsync = ref.watch(planoDetalheProvider(widget.planoId));

    return Scaffold(
      body: planoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _BotaoVoltar(aoTocar: _voltar),
              ),
              Expanded(
                child: EstadoErro(
                  mensagem: 'Não foi possível carregar o plano.',
                  aoTentar: () =>
                      ref.invalidate(planoDetalheProvider(widget.planoId)),
                ),
              ),
            ],
          ),
        ),
        data: (plano) {
          if (plano == null) {
            return SafeArea(
              child: EstadoVazio(
                icone: LucideIcons.calendar,
                titulo: 'Nenhum plano em uso',
                texto: 'Monte a primeira ficha para começar.',
                acao: FilledButton(
                  onPressed: () => context.push(Rotas.fichaDoPlano),
                  child: const Text('MONTAR FICHAS'),
                ),
              ),
            );
          }
          return _Conteudo(
            plano: plano,
            definidoAgora: _definidoAgora,
            aoVoltar: _voltar,
            aoDefinirEmUso: () => _definirEmUso(plano),
            aoNovaFicha: () => _novaFicha(plano),
            aoDuplicar: () => _duplicar(plano),
            aoRenomear: () => _renomear(plano),
            aoExcluir: () => _excluir(plano),
          );
        },
      ),
    );
  }
}

class _Conteudo extends ConsumerWidget {
  const _Conteudo({
    required this.plano,
    required this.definidoAgora,
    required this.aoVoltar,
    required this.aoDefinirEmUso,
    required this.aoNovaFicha,
    required this.aoDuplicar,
    required this.aoRenomear,
    required this.aoExcluir,
  });

  final PlanoDetalhe plano;
  final bool definidoAgora;
  final VoidCallback aoVoltar;
  final VoidCallback aoDefinirEmUso;
  final VoidCallback aoNovaFicha;
  final VoidCallback aoDuplicar;
  final VoidCallback aoRenomear;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    // "Último em dd/mm" de cada ficha vem das sessões recentes (as mesmas da
    // Início). Enquanto carrega ou se falhar, as linhas só não mostram a data.
    final ultimaVez = ref.watch(sessoesRecentesProvider).maybeWhen(
          data: InicioLogica.ultimaVezPorFicha,
          orElse: () => const <String, DateTime>{},
        );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Cabecalho(plano: plano, aoVoltar: aoVoltar),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.margemTela),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('FICHAS',
                  style: AppText.overline.copyWith(color: cores.textSecondary)),
              const SizedBox(height: AppSpacing.x8),
              for (var i = 0; i < plano.treinos.length; i++) ...[
                _LinhaFicha(
                  ficha: plano.treinos[i],
                  posicao: i + 1,
                  ultimaVez: ultimaVez[plano.treinos[i].id],
                  planoId: plano.id,
                ),
                const SizedBox(height: AppSpacing.entreItens),
              ],
              if (!plano.somenteLeitura)
                BotaoTracejado(rotulo: 'Nova ficha', aoTocar: aoNovaFicha),
              const SizedBox(height: AppSpacing.x24),
              if (!plano.emUso)
                SizedBox(
                  height: AppSizes.botaoPrincipal,
                  child: FilledButton.icon(
                    onPressed: aoDefinirEmUso,
                    icon: const Icon(LucideIcons.checkCircle, size: AppSizes.iconeSm),
                    label: const Text('DEFINIR COMO PLANO EM USO'),
                  ),
                )
              else if (definidoAgora)
                _AvisoEmUso(cores: cores),
              if (!plano.emUso || definidoAgora)
                const SizedBox(height: AppSpacing.entreItens),
              SizedBox(
                height: AppSizes.botaoSecundario,
                child: OutlinedButton.icon(
                  onPressed: aoDuplicar,
                  icon: const Icon(LucideIcons.copy, size: AppSizes.iconeSm),
                  label: Text(plano.somenteLeitura ? 'Copiar para editar' : 'Duplicar plano'),
                ),
              ),
              if (!plano.somenteLeitura) ...[
                const SizedBox(height: AppSpacing.x4),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: aoRenomear,
                        child: const Text('Renomear'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: aoExcluir,
                        style: TextButton.styleFrom(foregroundColor: cores.danger),
                        child: const Text('Excluir plano'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho escuro da tela 19: voltar, "Plano em uso", nome e resumo.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.plano, required this.aoVoltar});

  final PlanoDetalhe plano;
  final VoidCallback aoVoltar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final n = plano.treinos.length;
    final autoria = plano.somenteLeitura && plano.autor.isNotEmpty
        ? 'criado por Prof. ${plano.autor}'
        : 'criado por você';
    final resumo =
        'Desde ${_dataLonga(plano.inicio)} · $n ${n == 1 ? 'ficha' : 'fichas'} · $autoria';

    return Container(
      color: cores.bgHeader,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x8, AppSpacing.x8, AppSpacing.margemCabecalho, AppSpacing.x20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BotaoVoltar(aoTocar: aoVoltar, cor: cores.textOnHeader),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.x12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (plano.emUso)
                      Row(
                        children: [
                          Icon(LucideIcons.checkCircle,
                              size: 14, color: cores.textOnHeaderMuted),
                          const SizedBox(width: AppSpacing.x6),
                          Text('PLANO EM USO',
                              style: AppText.overline
                                  .copyWith(color: cores.textOnHeaderMuted)),
                        ],
                      )
                    else if (plano.somenteLeitura)
                      Row(
                        children: [
                          Icon(LucideIcons.lock,
                              size: 14, color: cores.textOnHeaderMuted),
                          const SizedBox(width: AppSpacing.x6),
                          Text('PLANO DO PROFESSOR',
                              style: AppText.overline
                                  .copyWith(color: cores.textOnHeaderMuted)),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.x4),
                    Text(plano.nome.toUpperCase(),
                        style: AppText.displayM.copyWith(color: cores.textOnHeader)),
                    const SizedBox(height: AppSpacing.x4),
                    Text(resumo,
                        style: AppText.caption
                            .copyWith(color: cores.textOnHeaderMuted)),
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

class _BotaoVoltar extends StatelessWidget {
  const _BotaoVoltar({required this.aoTocar, this.cor});

  final VoidCallback aoTocar;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: aoTocar,
      icon: Icon(LucideIcons.arrowLeft, size: AppSizes.iconeMd, color: cor),
      tooltip: 'Voltar para os planos',
      constraints: const BoxConstraints(
        minWidth: AppSizes.touchMin,
        minHeight: AppSizes.touchMin,
      ),
    );
  }
}

/// Uma ficha do plano: quadrado (nome curto ou posição), nome, "N exercícios ·
/// último em dd/mm" e a seta. Toque abre a ficha (tela 13).
class _LinhaFicha extends ConsumerWidget {
  const _LinhaFicha({
    required this.ficha,
    required this.posicao,
    required this.ultimaVez,
    required this.planoId,
  });

  final TreinoResumo ficha;
  final int posicao;
  final DateTime? ultimaVez;
  final String planoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cores = AppColors.of(context);
    // Quantidade de exercícios vem do detalhe da ficha (o mesmo que a tela 13
    // usa, então fica em cache ao abrir).
    final qtd = ref.watch(fichaDetalheProvider(ficha.id)).maybeWhen(
          data: (d) => d.exercicios.length,
          orElse: () => null,
        );
    final partes = <String>[
      if (qtd != null) '$qtd ${qtd == 1 ? 'exercício' : 'exercícios'}',
      ultimaVez == null ? 'nunca feito' : 'último em ${_dataCurta(ultimaVez!)}',
    ];
    final resumo = partes.join(' · ');

    return Semantics(
      button: true,
      label: 'Abrir ficha ${ficha.nome}, $resumo',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push(
            '${Rotas.fichaDoPlano}'
            '?plano=${Uri.encodeQueryComponent(planoId)}'
            '&ficha=${Uri.encodeQueryComponent(ficha.id)}',
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: cores.lineDefault),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            padding: const EdgeInsets.all(AppSpacing.paddingCardCompacto),
            child: Row(
              children: [
                QuadradoFicha(texto: rotuloQuadradoFicha(ficha.nome, posicao)),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_titulo(ficha), style: AppText.title),
                      const SizedBox(height: AppSpacing.x4),
                      Text(resumo,
                          style: AppText.caption.copyWith(color: cores.textSecondary)),
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

  /// Com descrição ("Peito e tríceps"), mostra a descrição como título, igual
  /// ao protótipo; sem descrição, o próprio nome.
  static String _titulo(TreinoResumo f) =>
      (f.descricao != null && f.descricao!.trim().isNotEmpty) ? f.descricao! : f.nome;
}

/// O que vai dentro do quadrado da ficha: o próprio nome quando ele tem até 3
/// caracteres (A, B, C); senão, a posição na sequência (1, 2, 3). A posição vem
/// de `ordem`, não do nome.
String rotuloQuadradoFicha(String nome, int posicao) {
  final limpo = nome.trim();
  return limpo.length <= 3 ? limpo.toUpperCase() : '$posicao';
}

/// Quadrado com o nome curto ou a posição da ficha.
class QuadradoFicha extends StatelessWidget {
  const QuadradoFicha({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      width: AppSizes.touchMin,
      height: AppSizes.touchMin,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.campoSerie),
      ),
      child: Text(texto,
          style: AppText.numeralS.copyWith(color: cores.primaryOnTint)),
    );
  }
}

/// "Este plano está em uso", depois de definir pela tela (critério 7).
class _AvisoEmUso extends StatelessWidget {
  const _AvisoEmUso({required this.cores});

  final AppColors cores;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.botaoPrincipal,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.botaoPrincipal),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.checkCircle, size: AppSizes.iconeSm, color: cores.primaryOnTint),
          const SizedBox(width: AppSpacing.x8),
          Text('Este plano está em uso',
              style: AppText.titleS.copyWith(color: cores.primaryOnTint)),
        ],
      ),
    );
  }
}

String _dataLonga(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _dataCurta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
