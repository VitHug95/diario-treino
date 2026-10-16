import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/flags.dart';
import '../../core/rotas/app_router.dart';
import '../../shared/acoes_cabecalho.dart';
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
import '../sessao/iniciar_treino_ao_vivo.dart';
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

  /// Cria a ficha e fica no plano (PBI-61): a ficha aparece na lista e o aviso
  /// oferece "Adicionar exercícios", que abre a ficha nova. Criar não abre a
  /// ficha sozinho, para criar e treinar serem momentos separados.
  Future<void> _novaFicha(PlanoDetalhe plano) async {
    final dados = await dialogoFicha(context);
    if (dados == null) return;
    try {
      final fichaId = await ref.read(fichasRepositoryProvider).adicionarFicha(
          planoId: plano.id, nome: dados.nome, descricao: dados.descricao);
      atualizarPlanos(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Ficha “${dados.nome}” criada'),
          action: SnackBarAction(
            label: 'Adicionar exercícios',
            onPressed: () => context.push(rotaDaFicha(plano.id, fichaId)),
          ),
        ));
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
        _Cabecalho(
          plano: plano,
          aoVoltar: aoVoltar,
          aoRenomear: aoRenomear,
          aoExcluir: aoExcluir,
        ),
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
                  planoNome: plano.nome,
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
              // Rodapé só com Duplicar (PBI-58): renomear e excluir ficam no
              // cabeçalho, como ícones.
              SizedBox(
                height: AppSizes.botaoSecundario,
                child: OutlinedButton.icon(
                  onPressed: aoDuplicar,
                  icon: const Icon(LucideIcons.copy, size: AppSizes.iconeSm),
                  label: Text(plano.somenteLeitura ? 'Copiar para editar' : 'Duplicar plano'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho escuro da tela 19: voltar, lápis e lixeira (PBI-58), "Plano em
/// uso", nome e resumo. Plano do professor não mostra lápis nem lixeira.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.plano,
    required this.aoVoltar,
    required this.aoRenomear,
    required this.aoExcluir,
  });

  final PlanoDetalhe plano;
  final VoidCallback aoVoltar;
  final VoidCallback aoRenomear;
  final VoidCallback aoExcluir;

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
              Row(
                children: [
                  _BotaoVoltar(aoTocar: aoVoltar, cor: cores.textOnHeader),
                  const Spacer(),
                  if (!plano.somenteLeitura)
                    AcoesRenomearExcluir(
                      rotuloRenomear: 'Renomear plano',
                      rotuloExcluir: 'Excluir plano',
                      aoRenomear: aoRenomear,
                      aoExcluir: aoExcluir,
                    ),
                ],
              ),
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

/// Rota da tela de edição de uma ficha do plano (tela 22).
String rotaDaFicha(String planoId, String fichaId) => '${Rotas.fichaDoPlano}'
    '?plano=${Uri.encodeQueryComponent(planoId)}'
    '&ficha=${Uri.encodeQueryComponent(fichaId)}';

/// Uma ficha do plano: quadrado (nome curto ou posição), nome, "N exercícios ·
/// último em dd/mm" e o play (PBI-61). O corpo abre a ficha para editar (tela
/// 22); o play abre o sheet de treinar. Ficha vazia: play desabilitado.
class _LinhaFicha extends ConsumerWidget {
  const _LinhaFicha({
    required this.ficha,
    required this.posicao,
    required this.ultimaVez,
    required this.planoId,
    required this.planoNome,
  });

  final TreinoResumo ficha;
  final int posicao;
  final DateTime? ultimaVez;
  final String planoId;
  final String planoNome;

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
    // Enquanto a contagem carrega, trata como vazia: não deixa treinar sem
    // saber se há exercícios.
    final podeTreinar = (qtd ?? 0) > 0;
    final raio = BorderRadius.circular(AppRadius.card);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: raio,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cores.lineDefault),
          borderRadius: raio,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Abrir ficha ${ficha.nome}, $resumo',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.card)),
                  onTap: () => context.push(rotaDaFicha(planoId, ficha.id)),
                  child: Padding(
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
                                  style: AppText.caption
                                      .copyWith(color: cores.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.paddingCardCompacto),
              child: SizedBox(
                width: AppSizes.touchMin,
                height: AppSizes.touchMin,
                child: IconButton.filled(
                  onPressed: podeTreinar
                      ? () => abrirTreinarFicha(context, ref,
                          ficha: ficha, posicao: posicao, planoNome: planoNome)
                      : null,
                  tooltip: podeTreinar
                      ? 'Treinar ${ficha.nome}'
                      : '${ficha.nome}: adicione exercícios para treinar',
                  padding: EdgeInsets.zero,
                  icon: const Icon(LucideIcons.play, size: AppSizes.iconeSm),
                ),
              ),
            ),
          ],
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

enum _EscolhaTreinar { agora, jaFeito }

/// Play da ficha (PBI-61): abre o sheet de treinar e segue a escolha. O sheet
/// só devolve a escolha; a navegação sai daqui, com o contexto do plano, e o
/// foco volta ao play quando o sheet fecha.
Future<void> abrirTreinarFicha(
  BuildContext context,
  WidgetRef ref, {
  required TreinoResumo ficha,
  required int posicao,
  required String planoNome,
}) async {
  final escolha = await showModalBottomSheet<_EscolhaTreinar>(
    context: context,
    // Por cima da navegação inferior.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => _SheetTreinar(
      ficha: ficha,
      posicao: posicao,
      planoNome: planoNome,
    ),
  );
  if (escolha == null || !context.mounted) return;

  switch (escolha) {
    case _EscolhaTreinar.agora:
      // Flag TV-3: treino ao vivo (que retoma o treino em andamento da mesma
      // ficha em vez de abrir um segundo); desligada, o registro de uma vez.
      if (treinoAoVivoHabilitado) {
        await iniciarTreinoAoVivoDaFicha(context, ref,
            treinoId: ficha.id, treinoNome: ficha.nome);
      } else {
        context.push(Rotas.registrarSessao,
            extra: RegistrarSessaoArgs(treinoId: ficha.id, treinoNome: ficha.nome));
      }
    case _EscolhaTreinar.jaFeito:
      context.push(Rotas.registrarSessao,
          extra: RegistrarSessaoArgs(
              treinoId: ficha.id, treinoNome: ficha.nome, registroPosterior: true));
  }
}

/// Sheet de treinar: "Ficha N · {plano}", o nome da ficha, "Iniciar treino
/// agora" (primário), "Registrar treino já feito" (secundário) e Cancelar.
class _SheetTreinar extends StatelessWidget {
  const _SheetTreinar({
    required this.ficha,
    required this.posicao,
    required this.planoNome,
  });

  final TreinoResumo ficha;
  final int posicao;
  final String planoNome;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final descricao = ficha.descricao?.trim() ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.margemTela, 0,
            AppSpacing.margemTela, AppSpacing.margemTela),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('FICHA $posicao · ${planoNome.toUpperCase()}',
                style: AppText.overline.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x4),
            Semantics(
              header: true,
              child: Text(ficha.nome.toUpperCase(), style: AppText.displayS),
            ),
            if (descricao.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x4),
              Text(descricao, style: AppText.body.copyWith(color: cores.textSecondary)),
            ],
            const SizedBox(height: AppSpacing.x20),
            SizedBox(
              height: AppSizes.botaoPrincipal,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_EscolhaTreinar.agora),
                icon: const Icon(LucideIcons.play, size: AppSizes.iconeSm),
                label: const Text('INICIAR TREINO AGORA'),
              ),
            ),
            const SizedBox(height: AppSpacing.entreItens),
            SizedBox(
              height: AppSizes.botaoSecundario,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(_EscolhaTreinar.jaFeito),
                icon: const Icon(LucideIcons.clipboardCheck, size: AppSizes.iconeSm),
                label: const Text('Registrar treino já feito'),
              ),
            ),
            const SizedBox(height: AppSpacing.entreItens),
            SizedBox(
              height: AppSizes.touchMin,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dataLonga(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _dataCurta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
