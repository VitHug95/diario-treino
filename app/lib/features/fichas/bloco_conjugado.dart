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
