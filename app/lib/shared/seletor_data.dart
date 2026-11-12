import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_typography.dart';
import '../theme/theme_tokens.dart';
import 'formato_data.dart';
import 'mascara_data.dart';

/// Impede abrir dois seletores de uma vez (um toque que chega por dois caminhos,
/// ponteiro e semântica, não pode empilhar dois diálogos).
bool _seletorAberto = false;

/// Só para testes: um seletor deixado aberto ao fim de um teste não pode travar o seguinte.
@visibleForTesting
void reiniciarSeletorDeData() => _seletorAberto = false;

/// Seletor de data do app (PBI-97): calendário e digitação no mesmo diálogo.
///
/// Existe porque o `showDatePicker` do SDK não serve aqui: o campo de digitação
/// dele segue o idioma do sistema (sem o locale pt-BR, lê mm/dd/aaaa, então
/// `26/05/1995` é "mês 26") e não aceita máscara. Este lê dd/mm/aaaa, completa as
/// barras sozinho ([MascaraDataFormatter]) e abre o teclado de dígitos.
///
/// [inicial] é a data já escolhida (nula = nenhuma ainda). [sugestao] é onde o
/// calendário abre quando não há [inicial] (padrão: [ultima]). Com
/// [abrirDigitando] o diálogo abre no campo de texto; o botão de alternar para o
/// calendário (e de volta) está sempre à vista. Devolve o dia escolhido à
/// meia-noite local, ou nulo se cancelar.
Future<DateTime?> escolherData(
  BuildContext context, {
  required String titulo,
  required DateTime primeira,
  required DateTime ultima,
  DateTime? inicial,
  DateTime? sugestao,
  bool abrirDigitando = false,
}) async {
  if (_seletorAberto) return null;
  _seletorAberto = true;
  try {
    return await showDialog<DateTime>(
      context: context,
      builder:
          (_) => SeletorDataDialog(
            titulo: titulo,
            primeira: soDia(primeira),
            ultima: soDia(ultima),
            inicial: inicial == null ? null : soDia(inicial),
            sugestao: sugestao == null ? null : soDia(sugestao),
            abrirDigitando: abrirDigitando,
          ),
    );
  } finally {
    _seletorAberto = false;
  }
}

@visibleForTesting
class SeletorDataDialog extends StatefulWidget {
  const SeletorDataDialog({
    super.key,
    required this.titulo,
    required this.primeira,
    required this.ultima,
    this.inicial,
    this.sugestao,
    this.abrirDigitando = false,
  });

  final String titulo;
  final DateTime primeira;
  final DateTime ultima;
  final DateTime? inicial;
  final DateTime? sugestao;
  final bool abrirDigitando;

  @override
  State<SeletorDataDialog> createState() => _SeletorDataDialogState();
}

class _SeletorDataDialogState extends State<SeletorDataDialog> {
  final _texto = TextEditingController();

  late bool _digitando;
  late DateTime _atual;

  /// O usuário mexeu no calendário: ao voltar para a digitação, o campo mostra
  /// o dia que ele escolheu lá.
  bool _mexeuNoCalendario = false;

  String? _erro;

  @override
  void initState() {
    super.initState();
    _digitando = widget.abrirDigitando;
    _atual = _dentroDaFaixa(widget.inicial ?? widget.sugestao ?? widget.ultima);
    if (widget.inicial != null) {
      _texto.text = formatarDataCompleta(widget.inicial!);
    }
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  DateTime _dentroDaFaixa(DateTime d) {
    if (d.isBefore(widget.primeira)) {
      return widget.primeira;
    }
    if (d.isAfter(widget.ultima)) {
      return widget.ultima;
    }
    return d;
  }

  bool _naFaixa(DateTime d) =>
      !d.isBefore(widget.primeira) && !d.isAfter(widget.ultima);

  void _alternar() {
    setState(() {
      _erro = null;
      if (_digitando) {
        // Digitação -> calendário: leva a data digitada, se ela já é válida.
        final d = lerDataCompleta(_texto.text);
        if (d != null && _naFaixa(d)) _atual = d;
      } else if (_mexeuNoCalendario) {
        // Calendário -> digitação: mostra o dia escolhido lá.
        _texto.text = formatarDataCompleta(_atual);
      }
      _digitando = !_digitando;
    });
  }

  void _confirmar() {
    if (!_digitando) {
      Navigator.of(context).pop(_atual);
      return;
    }
    final texto = _texto.text;
    final d = lerDataCompleta(texto);
    if (d == null) {
      // Incompleta ou impossível (31/02, mês 13): o seletor continua aberto.
      setState(
        () =>
            _erro =
                texto.length < 10
                    ? 'Digite a data inteira: dd/mm/aaaa.'
                    : 'Essa data não existe.',
      );
      return;
    }
    if (!_naFaixa(d)) {
      setState(
        () =>
            _erro =
                'Use uma data entre ${formatarDataCompleta(widget.primeira)} '
                'e ${formatarDataCompleta(widget.ultima)}.',
      );
      return;
    }
    Navigator.of(context).pop(d);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.titulo, style: AppText.titleS)),
          IconButton(
            // O botão de alternar está sempre à vista, nos dois modos.
            tooltip: _digitando ? 'Escolher no calendário' : 'Digitar a data',
            onPressed: _alternar,
            icon: Icon(
              _digitando ? LucideIcons.calendar : LucideIcons.pencil,
              size: AppSizes.iconeSm,
            ),
          ),
        ],
      ),
      content: _digitando ? _campoDigitado() : _calendario(),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('OK')),
      ],
    );
  }

  Widget _calendario() => SizedBox(
    width: double.maxFinite,
    child: CalendarDatePicker(
      initialDate: _atual,
      firstDate: widget.primeira,
      lastDate: widget.ultima,
      onDateChanged:
          (d) => setState(() {
            _atual = soDia(d);
            _mexeuNoCalendario = true;
          }),
    ),
  );

  Widget _campoDigitado() => TextField(
    controller: _texto,
    autofocus: true,
    // Teclado de dígitos (no iPhone, o teclado numérico); a barra é da máscara.
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.done,
    inputFormatters: const [MascaraDataFormatter()],
    style: AppText.inputValue,
    onSubmitted: (_) => _confirmar(),
    onChanged: (_) {
      if (_erro != null) setState(() => _erro = null);
      final d = lerDataCompleta(_texto.text);
      if (d != null && _naFaixa(d)) _atual = d;
    },
    decoration: InputDecoration(
      labelText: 'Data',
      hintText: 'dd/mm/aaaa',
      helperText: 'Digite só os números',
      errorText: _erro,
      errorMaxLines: 2,
    ),
  );
}
