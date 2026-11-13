import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/theme_tokens.dart';
import 'plano_models.dart';

/// Textos e o sheet do bloco conjugado (PBI-101), usados pelo editor da ficha.

/// "descanso 30 s" ou "sem descanso".
String textoDescansoBloco(BlocoFicha bloco) =>
    bloco.temDescanso ? 'descanso ${bloco.descansoSeg} s' : 'sem descanso';

/// Cabeçalho do cartão: "Conjugado · 4 rodadas · descanso 30 s".
String textoCabecalhoBloco(BlocoFicha bloco) {
  final r = bloco.rodadas;
  return 'Conjugado · $r ${r == 1 ? 'rodada' : 'rodadas'} · ${textoDescansoBloco(bloco)}';
}

/// Rótulo falado: "Bloco conjugado, 4 rodadas, descanso 30 segundos, 2 exercícios".
String rotuloFaladoBloco(BlocoFicha bloco, int exercicios) {
  final r = bloco.rodadas;
  final descanso =
      bloco.temDescanso ? 'descanso ${bloco.descansoSeg} segundos' : 'sem descanso';
  return 'Bloco conjugado, $r ${r == 1 ? 'rodada' : 'rodadas'}, $descanso, '
      '$exercicios ${exercicios == 1 ? 'exercício' : 'exercícios'}';
}

/// Valida o descanso digitado (0 a 600 s). Nulo = válido.
String? validarDescansoBloco(String texto) {
  final t = texto.trim();
  if (t.isEmpty) return 'Informe os segundos ou marque "Sem descanso".';
  final v = int.tryParse(t);
  if (v == null || v < 0 || v > BlocoFicha.descansoMaximoSeg) {
    return 'Use de 0 a ${BlocoFicha.descansoMaximoSeg} segundos.';
  }
  return null;
}

/// Sheet "Descanso depois de cada rodada" (juntar ou mudar o descanso).
/// Devolve `(segundos: null)` para "Sem descanso", `(segundos: n)` para n
/// segundos, ou `null` se o atleta fechou sem confirmar.
Future<({int? segundos})?> pedirDescansoBloco(
  BuildContext context, {
  required String rotuloConfirmar,
  int? inicial,
  bool novo = false,
}) {
  return showModalBottomSheet<({int? segundos})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _SheetDescanso(rotuloConfirmar: rotuloConfirmar, inicial: inicial, novo: novo),
  );
}

class _SheetDescanso extends StatefulWidget {
  const _SheetDescanso({
    required this.rotuloConfirmar,
    required this.inicial,
    required this.novo,
  });

  final String rotuloConfirmar;
  final int? inicial;

  /// Bloco ainda não existe (juntar): começa pedindo os segundos.
  final bool novo;

  @override
  State<_SheetDescanso> createState() => _SheetDescansoState();
}

class _SheetDescansoState extends State<_SheetDescanso> {
  late final TextEditingController _segundos = TextEditingController(
      text: (widget.inicial ?? 0) > 0 ? widget.inicial.toString() : '');
  // Bloco que já existe sem descanso abre com a opção marcada; o novo, não.
  late bool _semDescanso = !widget.novo && (widget.inicial ?? 0) <= 0;
  String? _erro;

  @override
  void dispose() {
    _segundos.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_semDescanso) {
      Navigator.pop(context, (segundos: null));
      return;
    }
    final erro = validarDescansoBloco(_segundos.text);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    final v = int.parse(_segundos.text.trim());
    Navigator.pop(context, (segundos: v == 0 ? null : v));
  }

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.margemTela, 0, AppSpacing.margemTela,
          AppSpacing.margemTela + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Descanso depois de cada rodada', style: AppText.title),
          const SizedBox(height: AppSpacing.x6),
          Text('Um descanso só, depois do último exercício da rodada.',
              style: AppText.bodyS.copyWith(color: cores.textSecondary)),
          const SizedBox(height: AppSpacing.x16),
          TextField(
            controller: _segundos,
            enabled: !_semDescanso,
            autofocus: !_semDescanso,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppText.inputValue,
            decoration: InputDecoration(
              labelText: 'Segundos',
              suffixText: 's',
              errorText: _semDescanso ? null : _erro,
            ),
            onChanged: (_) => setState(() => _erro = null),
            onSubmitted: (_) => _confirmar(),
          ),
          const SizedBox(height: AppSpacing.x8),
          CheckboxListTile(
            value: _semDescanso,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Sem descanso', style: AppText.body),
            onChanged: (v) => setState(() {
              _semDescanso = v ?? false;
              _erro = null;
            }),
          ),
          const SizedBox(height: AppSpacing.x12),
          SizedBox(
            height: AppSizes.botaoPrincipal,
            child: FilledButton(
              onPressed: _confirmar,
              child: Text(widget.rotuloConfirmar.toUpperCase(), style: AppText.button),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmação de "Desfazer bloco". Não apaga nada, então não usa o vermelho
/// de perigo.
Future<bool> confirmarDesfazerBloco(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Desfazer o bloco?'),
      content: const Text('Os exercícios continuam na ficha, separados, cada um '
          'com o descanso que o bloco tinha.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desfazer')),
      ],
    ),
  );
  return ok ?? false;
}

/// O que o atleta escolheu no sheet "Juntar … com…".
sealed class EscolhaJuntar {
  const EscolhaJuntar();
}

/// Bloco novo com os exercícios escolhidos (além do de origem).
class JuntarEmBlocoNovo extends EscolhaJuntar {
  const JuntarEmBlocoNovo(this.treinoExercicioIds, this.descansoSeg);
  final List<String> treinoExercicioIds;
  final int? descansoSeg;
}

/// Entrar num bloco que já existe (vale o descanso dele).
class EntrarNoBloco extends EscolhaJuntar {
  const EntrarNoBloco(this.bloco);
  final BlocoFicha bloco;
}

/// Exercícios escolhidos para entrar no bloco (pelo "Adicionar exercício").
class AdicionarAoBloco extends EscolhaJuntar {
  const AdicionarAoBloco(this.treinoExercicioIds);
  final List<String> treinoExercicioIds;
}

/// Sheet "Juntar {origem} com…" (a partir de um exercício avulso): marque de 1
/// a 3 exercícios para um bloco novo, ou escolha um bloco que já existe. Os
/// que já estão noutro bloco aparecem desabilitados. Bloco novo pede o
/// descanso depois de cada rodada.
Future<EscolhaJuntar?> escolherJuntar(
  BuildContext context, {
  required TreinoExercicioResumo origem,
  required List<ItemFicha> itens,
}) =>
    showModalBottomSheet<EscolhaJuntar>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SheetJuntar(origem: origem, itens: itens, bloco: null),
    );

/// Sheet "Adicionar ao bloco": marque os avulsos que entram no [bloco] (até
/// completar 4).
Future<EscolhaJuntar?> escolherAdicionarAoBloco(
  BuildContext context, {
  required ItemBloco bloco,
  required List<ItemFicha> itens,
}) =>
    showModalBottomSheet<EscolhaJuntar>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SheetJuntar(origem: null, itens: itens, bloco: bloco),
    );

class _SheetJuntar extends StatefulWidget {
  const _SheetJuntar({required this.origem, required this.itens, required this.bloco});

  /// Exercício avulso que abriu o sheet (modo "juntar"), ou nulo.
  final TreinoExercicioResumo? origem;

  /// Bloco que recebe exercícios (modo "adicionar ao bloco"), ou nulo.
  final ItemBloco? bloco;
  final List<ItemFicha> itens;

  @override
  State<_SheetJuntar> createState() => _SheetJuntarState();
}

class _SheetJuntarState extends State<_SheetJuntar> {
  final _marcados = <String>{};
  ItemBloco? _blocoEscolhido;
  final _segundos = TextEditingController();
  bool _semDescanso = false;
  String? _erroDescanso;

  bool get _adicionando => widget.bloco != null;

  /// Quantos exercícios ainda cabem: 3 além da origem num bloco novo; o que
  /// falta para 4 no bloco existente.
  int get _limite => _adicionando
      ? BlocoFicha.maximoMembros - widget.bloco!.membros.length
      : BlocoFicha.maximoMembros - 1;

  @override
  void dispose() {
    _segundos.dispose();
    super.dispose();
  }

  void _alternar(String id) => setState(() {
        _blocoEscolhido = null;
        if (!_marcados.remove(id) && _marcados.length < _limite) _marcados.add(id);
      });

  void _escolherBloco(ItemBloco b) => setState(() {
        _marcados.clear();
        _blocoEscolhido = _blocoEscolhido?.bloco.id == b.bloco.id ? null : b;
      });

  void _confirmar() {
    if (_adicionando) {
      Navigator.pop(context, AdicionarAoBloco(_ordenados()));
      return;
    }
    if (_blocoEscolhido != null) {
      Navigator.pop(context, EntrarNoBloco(_blocoEscolhido!.bloco));
      return;
    }
    int? descanso;
    if (!_semDescanso) {
      final erro = validarDescansoBloco(_segundos.text);
      if (erro != null) {
        setState(() => _erroDescanso = erro);
        return;
      }
      final v = int.parse(_segundos.text.trim());
      descanso = v == 0 ? null : v;
    }
    Navigator.pop(context, JuntarEmBlocoNovo([widget.origem!.id, ..._ordenados()], descanso));
  }

  /// Marcados na ordem da ficha.
  List<String> _ordenados() => [
        for (final item in widget.itens)
          if (item case ItemAvulso(:final exercicio) when _marcados.contains(exercicio.id))
            exercicio.id,
      ];

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final avulsos = [
      for (final item in widget.itens)
        if (item case ItemAvulso(:final exercicio) when exercicio.id != widget.origem?.id)
          exercicio,
    ];
    final blocos = [
      if (!_adicionando)
        for (final item in widget.itens)
          if (item is ItemBloco) item,
    ];
    // Membros de outros blocos: aparecem desabilitados ("Já está num bloco").
    final emOutroBloco = [
      for (final item in widget.itens)
        if (item is ItemBloco && item.bloco.id != widget.bloco?.bloco.id) ...item.membros,
    ];
    final cheio = _marcados.length >= _limite;
    final pronto = _marcados.isNotEmpty || _blocoEscolhido != null;
    final titulo = _adicionando
        ? 'Adicionar ao bloco'
        : 'Juntar ${widget.origem!.nome} com…';
    final pedeDescanso = !_adicionando && _blocoEscolhido == null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.margemTela, 0, AppSpacing.margemTela,
              AppSpacing.margemTela + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(titulo, style: AppText.title)),
              const SizedBox(height: AppSpacing.x6),
              Text(
                _adicionando
                    ? 'Escolha até $_limite ${_limite == 1 ? 'exercício' : 'exercícios'}. '
                        'Eles são feitos alternando, com o descanso do bloco.'
                    : 'Escolha até 3 exercícios para fazer alternando, ou entre num '
                        'bloco que já existe.',
                style: AppText.bodyS.copyWith(color: cores.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final b in blocos)
                      _OpcaoJuntar(
                        titulo: 'Bloco: ${b.membros.map((m) => m.nome).join(' + ')}',
                        subtitulo: b.membros.length >= BlocoFicha.maximoMembros
                            ? 'Já tem 4 exercícios'
                            : textoCabecalhoBloco(b.bloco),
                        marcado: _blocoEscolhido?.bloco.id == b.bloco.id,
                        habilitado: b.membros.length < BlocoFicha.maximoMembros,
                        unico: true,
                        aoTocar: () => _escolherBloco(b),
                      ),
                    for (final e in avulsos)
                      _OpcaoJuntar(
                        titulo: e.nome,
                        subtitulo: !_marcados.contains(e.id) && cheio
                            ? 'Máximo de 4 por bloco'
                            : null,
                        marcado: _marcados.contains(e.id),
                        habilitado: _marcados.contains(e.id) || !cheio,
                        aoTocar: () => _alternar(e.id),
                      ),
                    for (final e in emOutroBloco)
                      _OpcaoJuntar(
                        titulo: e.nome,
                        subtitulo: 'Já está num bloco',
                        marcado: false,
                        habilitado: false,
                        aoTocar: () {},
                      ),
                    if (avulsos.isEmpty && blocos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x12),
                        child: Text('Não há outro exercício livre nesta ficha.',
                            style: AppText.bodyS.copyWith(color: cores.textSecondary)),
                      ),
                  ],
                ),
              ),
              if (pedeDescanso) ...[
                const SizedBox(height: AppSpacing.x12),
                Text('Descanso depois de cada rodada', style: AppText.label),
                const SizedBox(height: AppSpacing.x6),
                TextField(
                  controller: _segundos,
                  enabled: !_semDescanso,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppText.inputValue,
                  decoration: InputDecoration(
                    labelText: 'Segundos',
                    suffixText: 's',
                    errorText: _semDescanso ? null : _erroDescanso,
                  ),
                  onChanged: (_) => setState(() => _erroDescanso = null),
                ),
                CheckboxListTile(
                  value: _semDescanso,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('Sem descanso', style: AppText.body),
                  onChanged: (v) => setState(() {
                    _semDescanso = v ?? false;
                    _erroDescanso = null;
                  }),
                ),
              ],
              const SizedBox(height: AppSpacing.x12),
              SizedBox(
                height: AppSizes.botaoPrincipal,
                child: FilledButton(
                  onPressed: pronto ? _confirmar : null,
                  child: Text(_adicionando ? 'ADICIONAR' : 'JUNTAR', style: AppText.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma linha do sheet: caixa de marcar (ou escolha única, para bloco), com o
/// alvo de toque da linha inteira (≥ 44 px).
class _OpcaoJuntar extends StatelessWidget {
  const _OpcaoJuntar({
    required this.titulo,
    required this.subtitulo,
    required this.marcado,
    required this.habilitado,
    required this.aoTocar,
    this.unico = false,
  });

  final String titulo;
  final String? subtitulo;
  final bool marcado;
  final bool habilitado;
  final VoidCallback aoTocar;
  final bool unico;

  @override
  Widget build(BuildContext context) {
    final cores = AppColors.of(context);
    final controle = unico
        ? Icon(marcado ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: habilitado ? Theme.of(context).colorScheme.primary : cores.iconMuted)
        : Checkbox(value: marcado, onChanged: habilitado ? (_) => aoTocar() : null);
    return MergeSemantics(
      child: ListTile(
        minTileHeight: AppSizes.touchMin,
        contentPadding: EdgeInsets.zero,
        enabled: habilitado,
        leading: controle,
        title: Text(titulo, style: AppText.body),
        subtitle: subtitulo == null
            ? null
            : Text(subtitulo!, style: AppText.caption.copyWith(color: cores.textSecondary)),
        selected: marcado,
        onTap: habilitado ? aoTocar : null,
      ),
    );
  }
}
