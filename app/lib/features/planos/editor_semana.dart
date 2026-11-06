import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/mostrar_aviso.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import '../fichas/fichas_comandos.dart';
import '../fichas/fichas_repository.dart';
import '../fichas/plano_models.dart';
import 'plano_detalhe_screen.dart' show QuadradoFicha, rotuloQuadradoFicha;

/// Seção "Semana" do detalhe do plano (PBI-35): a ficha de cada dia (seg→dom).
/// Opcional — dia sem ficha é descanso. Quem pode editar toca no dia e escolhe
/// a ficha ou "Livre"; a semana é salva na hora. Plano somente leitura mostra a
/// semana (se houver) sem toque. Sem fichas no plano, a seção não aparece.
class SecaoSemana extends ConsumerStatefulWidget {
  const SecaoSemana({super.key, required this.plano, required this.podeEditar});

  final PlanoDetalhe plano;

  /// Só o autor do plano edita (regra do backend; o 403 vira aviso de erro).
  final bool podeEditar;

  @override
  ConsumerState<SecaoSemana> createState() => _SecaoSemanaState();
}

class _SecaoSemanaState extends ConsumerState<SecaoSemana> {
  /// Semana mostrada (dia ISO → id da ficha). Muda na hora ao escolher; volta
  /// ao que veio da API se a gravação falhar.
  late Map<int, String> _dias = _doPlano();
  bool _salvando = false;

  Map<int, String> _doPlano() => {
        for (final e in fichasPorDia(widget.plano.semana, widget.plano.treinos).entries)
          e.key: e.value.id,
      };

  @override
  void didUpdateWidget(SecaoSemana antigo) {
    super.didUpdateWidget(antigo);
    // A API recarregou o plano (depois de gravar ou de outra tela): segue ela.
    if (!listEquals(antigo.plano.semana, widget.plano.semana) ||
        !listEquals(antigo.plano.treinos.map((t) => t.id).toList(),
            widget.plano.treinos.map((t) => t.id).toList())) {
      _dias = _doPlano();
    }
  }

  Future<void> _escolher(int dia) async {
    if (_salvando) return;
    final escolha = await showModalBottomSheet<_Escolha>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FolhaEscolha(
        dia: dia,
        fichas: widget.plano.treinos,
        atual: _dias[dia],
      ),
    );
    if (escolha == null || !mounted || escolha.treinoId == _dias[dia]) return;

    final anterior = Map<int, String>.of(_dias);
    setState(() {
      _salvando = true;
      if (escolha.treinoId == null) {
        _dias.remove(dia);
      } else {
        _dias[dia] = escolha.treinoId!;
      }
    });

    final dias = (_dias.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => DiaPlanejado(diaSemana: e.key, treinoId: e.value))
        .toList();
    try {
      await ref.read(fichasComandosProvider).definirSemana(
            planoId: widget.plano.id,
            dias: dias,
          );
      if (!mounted) return;
      final nome = escolha.treinoId == null
          ? 'livre'
          : widget.plano.treinos.firstWhere((f) => f.id == escolha.treinoId).nome;
      mostrarAviso(context, '${nomeDiaSemana(dia)}: $nome');
    } on FichasException catch (e) {
      if (!mounted) return;
      setState(() => _dias = anterior);
      mostrarErro(context, e.mensagem);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plano = widget.plano;
    if (plano.treinos.isEmpty) return const SizedBox.shrink();
    // Somente leitura sem semana: nada a mostrar (a semana é opcional).
    if (!widget.podeEditar && _dias.isEmpty) return const SizedBox.shrink();

    final cores = AppColors.of(context);
    final porId = {for (final f in plano.treinos) f.id: f};
    final posicao = {for (var i = 0; i < plano.treinos.length; i++) plano.treinos[i].id: i + 1};

    // O espaço de cima é da própria seção: quando ela não aparece, a tela fica
    // exatamente como antes da PBI-35.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x24),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('SEMANA', style: AppText.overline.copyWith(color: cores.textSecondary)),
        const SizedBox(height: AppSpacing.x4),
        Text(
          widget.podeEditar
              ? 'Opcional. Escolha a ficha de cada dia; os outros ficam como descanso.'
              : 'A ficha de cada dia, definida por quem montou o plano.',
          style: AppText.caption.copyWith(color: cores.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: cores.lineDefault),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var dia = 1; dia <= 7; dia++) ...[
                if (dia > 1) Divider(height: 1, thickness: 1, color: cores.lineDivider),
                _LinhaDia(
                  dia: dia,
                  ficha: porId[_dias[dia]],
                  posicao: posicao[_dias[dia]],
                  aoTocar: widget.podeEditar && !_salvando ? () => _escolher(dia) : null,
                ),
              ],
            ],
          ),
        ),
      ],
      ),
    );
  }
}

/// Um dia na seção "Semana": nome do dia e a ficha (ou "Livre").
class _LinhaDia extends StatelessWidget {
  const _LinhaDia({
    required this.dia,
    required this.ficha,
    required this.posicao,
    required this.aoTocar,
  });

  final int dia;
  final TreinoResumo? ficha;
  final int? posicao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final nomeDia = nomeDiaSemana(dia);
    final valor = ficha?.nome ?? 'Livre';
    final rotulo = aoTocar == null
        ? '$nomeDia: ${ficha == null ? 'livre' : ficha!.nome}'
        : '$nomeDia: ${ficha == null ? 'livre' : ficha!.nome}. Toque para trocar';

    return Semantics(
      button: aoTocar != null,
      label: rotulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: aoTocar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingCardCompacto, vertical: AppSpacing.x6),
            child: Row(
              children: [
                Expanded(child: Text(nomeDia, style: AppText.body)),
                if (ficha != null) ...[
                  _Selo(texto: rotuloQuadradoFicha(ficha!.nome, posicao ?? 1)),
                  const SizedBox(width: AppSpacing.x8),
                ],
                Flexible(
                  child: Text(
                    valor,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(
                      color: ficha == null ? cores.textSecondary : cores.textStrong,
                      fontWeight: ficha == null ? null : FontWeight.w600,
                    ),
                  ),
                ),
                if (aoTocar != null) ...[
                  const SizedBox(width: AppSpacing.x4),
                  Icon(LucideIcons.chevronRight, color: cores.iconMuted, size: AppSizes.iconeSm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo pequeno com o rótulo curto da ficha (o mesmo do quadrado das fichas).
class _Selo extends StatelessWidget {
  const _Selo({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8, vertical: AppSpacing.x4),
      decoration: BoxDecoration(
        color: cores.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(texto,
          style: AppText.caption.copyWith(
              color: cores.primaryOnTint, fontWeight: FontWeight.w700)),
    );
  }
}

/// Escolha feita na folha: id da ficha, ou nulo para "Livre".
class _Escolha {
  const _Escolha(this.treinoId);
  final String? treinoId;
}

/// Folha para escolher a ficha de um dia (ou deixar livre).
class _FolhaEscolha extends StatelessWidget {
  const _FolhaEscolha({required this.dia, required this.fichas, required this.atual});

  final int dia;
  final List<TreinoResumo> fichas;
  final String? atual;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    void escolher(String? id) => Navigator.of(context).pop(_Escolha(id));

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
              child: Text(nomeDiaSemana(dia), style: AppText.displayS),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text('Qual ficha é deste dia?',
                style: AppText.caption.copyWith(color: cores.textSecondary)),
            const SizedBox(height: AppSpacing.x12),
            for (var i = 0; i < fichas.length; i++) ...[
              _OpcaoFolha(
                inicio: QuadradoFicha(texto: rotuloQuadradoFicha(fichas[i].nome, i + 1)),
                titulo: fichas[i].nome,
                subtitulo: fichas[i].descricao,
                selecionada: fichas[i].id == atual,
                rotulo: '${fichas[i].nome} na ${nomeDiaSemana(dia).toLowerCase()}',
                aoTocar: () => escolher(fichas[i].id),
              ),
              const SizedBox(height: AppSpacing.entreItens),
            ],
            _OpcaoFolha(
              inicio: Icon(LucideIcons.moon, size: AppSizes.iconeMd, color: cores.textStrong),
              titulo: 'Livre',
              subtitulo: 'Sem ficha: dia de descanso',
              selecionada: atual == null,
              rotulo: 'Deixar ${nomeDiaSemana(dia).toLowerCase()} livre',
              aoTocar: () => escolher(null),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoFolha extends StatelessWidget {
  const _OpcaoFolha({
    required this.inicio,
    required this.titulo,
    required this.subtitulo,
    required this.selecionada,
    required this.rotulo,
    required this.aoTocar,
  });

  final Widget inicio;
  final String titulo;
  final String? subtitulo;
  final bool selecionada;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final temSub = subtitulo != null && subtitulo!.trim().isNotEmpty;
    return Semantics(
      button: true,
      selected: selecionada,
      label: selecionada ? '$rotulo, escolhida agora' : rotulo,
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
              // A escolhida tem borda azul mais grossa e o check (não só cor).
              border: Border.all(
                color: selecionada ? cores.primaryText : cores.lineDefault,
                width: selecionada ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.campoForm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
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
                if (selecionada)
                  Icon(LucideIcons.checkCircle, size: AppSizes.iconeMd, color: cores.primaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
