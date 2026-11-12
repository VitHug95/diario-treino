import 'package:diario_treino/shared/campo_data.dart';
import 'package:diario_treino/shared/formato_data.dart';
import 'package:diario_treino/shared/mascara_data.dart';
import 'package:diario_treino/shared/seletor_data.dart';
import 'package:diario_treino/theme/app_colors.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// PBI-97: campo de data (alvo de toque, rótulo falado, vazio), máscara
/// dd/mm/aaaa e o seletor próprio (calendário + digitação).

// ---- Simulação de digitação na máscara ----

const _mascara = MascaraDataFormatter();

/// O texto depois de digitar [tecla] no fim de [atual].
String _digitar(String atual, String tecla) => _mascara
    .formatEditUpdate(
      TextEditingValue(text: atual, selection: TextSelection.collapsed(offset: atual.length)),
      TextEditingValue(
        text: atual + tecla,
        selection: TextSelection.collapsed(offset: atual.length + tecla.length),
      ),
    )
    .text;

/// Digita cada caractere de [teclas] em sequência, como o teclado faz.
String _digitarTudo(String teclas) {
  var texto = '';
  for (final t in teclas.split('')) {
    texto = _digitar(texto, t);
  }
  return texto;
}

/// Apaga um caractere com o cursor em [posicao] (backspace).
TextEditingValue _backspace(String atual, {int? posicao}) {
  final p = posicao ?? atual.length;
  final novoTexto = atual.substring(0, p - 1) + atual.substring(p);
  return _mascara.formatEditUpdate(
    TextEditingValue(text: atual, selection: TextSelection.collapsed(offset: p)),
    TextEditingValue(text: novoTexto, selection: TextSelection.collapsed(offset: p - 1)),
  );
}

/// Cola [colado] num campo [atual] (vazio por padrão), com o cursor no fim.
String _colar(String colado, {String atual = ''}) {
  final novo = atual + colado;
  return _mascara
      .formatEditUpdate(
        TextEditingValue(text: atual, selection: TextSelection.collapsed(offset: atual.length)),
        TextEditingValue(text: novo, selection: TextSelection.collapsed(offset: novo.length)),
      )
      .text;
}

void main() {
  // ================= Máscara =================

  group('MascaraDataFormatter: digitar', () {
    test('26051995 vira 26/05/1995 sem digitar barra', () {
      expect(_digitarTudo('26051995'), '26/05/1995');
    });

    test('a barra entra sozinha ao completar o dia e o mês', () {
      expect(_digitar('', '2'), '2');
      expect(_digitarTudo('26'), '26/');
      expect(_digitarTudo('260'), '26/0');
      expect(_digitarTudo('2605'), '26/05/');
      expect(_digitarTudo('26051'), '26/05/1');
    });

    test('com o ano completo para sozinho: o 9º dígito é cortado', () {
      expect(_digitar('26/05/1995', '7'), '26/05/1995');
      expect(_digitarTudo('260519951234'), '26/05/1995');
    });

    test('26/05/1995 digitado com as barras dá o mesmo resultado', () {
      expect(_digitarTudo('26/05/1995'), '26/05/1995');
    });

    test('a barra digitada onde ela já está é ignorada', () {
      expect(_digitar('26/', '/'), '26/');
      expect(_digitar('26/05/', '/'), '26/05/');
    });

    test('só dígitos entram: letras e símbolos são descartados', () {
      expect(_digitarTudo('2a6-0.5'), '26/05/');
      expect(_digitar('', 'x'), '');
    });
  });

  group('MascaraDataFormatter: colar', () {
    test('com e sem barras dá o mesmo resultado', () {
      expect(_colar('26/05/1995'), '26/05/1995');
      expect(_colar('26051995'), '26/05/1995');
    });

    test('2605 colado vira 26/05, sem a barra de sobra de quem digita', () {
      expect(_colar('2605'), '26/05');
      expect(_colar('26'), '26');
    });

    test('mais de 8 dígitos é cortado', () {
      expect(_colar('26/05/1995123'), '26/05/1995');
      expect(_colar('260519951234'), '26/05/1995');
    });

    test('colar por cima de uma data inteira troca tudo (não é apagar a barra)', () {
      final r = _mascara.formatEditUpdate(
        const TextEditingValue(
            text: '31/02/1995', selection: TextSelection.collapsed(offset: 10)),
        const TextEditingValue(
            text: '15131995', selection: TextSelection.collapsed(offset: 8)),
      );
      expect(r.text, '15/13/1995');
    });

    test('colar lixo no meio deixa só os dígitos', () {
      expect(_colar(' 26 . 05 . 1995 '), '26/05/1995');
    });
  });

  group('MascaraDataFormatter: apagar', () {
    test('apagar a barra leva o dígito anterior junto e não trava', () {
      // "26/" -> backspace tira a barra -> "2" (não volta a "26/").
      expect(_backspace('26/').text, '2');
      // "26/05/" -> "26/0".
      expect(_backspace('26/05/').text, '26/0');
    });

    test('apagar um dígito não recoloca a barra', () {
      expect(_backspace('26/0').text, '26');
      expect(_backspace('26').text, '2');
      expect(_backspace('2').text, '');
      expect(_backspace('26/05/1995').text, '26/05/199');
    });

    test('dá para apagar tudo, passo a passo, sem travar', () {
      var texto = '26/05/1995';
      var passos = 0;
      while (texto.isNotEmpty && passos < 30) {
        texto = _backspace(texto).text;
        passos++;
      }
      expect(texto, isEmpty);
      expect(passos, lessThanOrEqualTo(10));
    });

    test('apagar no meio refaz a máscara e o cursor fica dentro do texto', () {
      // Cursor depois do "0" do mês: "26/0|5/1995" -> apaga o 0.
      final r = _backspace('26/05/1995', posicao: 5);
      expect(r.text, matches(RegExp(r'^[\d/]{0,10}$')));
      expect(r.selection.baseOffset, inInclusiveRange(0, r.text.length));
      expect(r.text.replaceAll('/', '').length, 7);
    });

    test('corrigir no meio e seguir digitando funciona', () {
      var texto = '26/05/1995';
      texto = _backspace(texto, posicao: 4).text; // tira o 0 do mês
      expect(texto.replaceAll('/', ''), '2651995');
      // Digitando de novo no fim, o 8º dígito completa o ano.
      texto = _digitar(texto, '0');
      expect(texto.replaceAll('/', '').length, 8);
    });
  });

  group('lerDataCompleta', () {
    test('lê datas válidas', () {
      expect(lerDataCompleta('26/05/1995'), DateTime(1995, 5, 26));
      expect(lerDataCompleta('29/02/2024'), DateTime(2024, 2, 29));
    });

    test('recusa incompleta, impossível e fora do formato', () {
      expect(lerDataCompleta(''), isNull);
      expect(lerDataCompleta('26/05'), isNull);
      expect(lerDataCompleta('26/05/199'), isNull);
      expect(lerDataCompleta('31/02/1995'), isNull); // não existe
      expect(lerDataCompleta('29/02/2025'), isNull); // 2025 não é bissexto
      expect(lerDataCompleta('00/05/1995'), isNull);
      expect(lerDataCompleta('15/13/1995'), isNull); // mês 13
      expect(lerDataCompleta('1995-05-26'), isNull);
    });

    test('formatarDataCompleta é o caminho de volta', () {
      expect(formatarDataCompleta(DateTime(1995, 5, 6)), '06/05/1995');
      expect(lerDataCompleta(formatarDataCompleta(DateTime(2026, 11, 9))), DateTime(2026, 11, 9));
    });
  });

  // ================= CampoData =================

  Widget campo({String? texto = '26/05/1995', VoidCallback? aoTocar, ThemeData? tema}) =>
      MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: CampoData(rotulo: 'Data de nascimento', texto: texto, aoTocar: aoTocar),
            ),
          ),
        ),
      );

  group('CampoData', () {
    testWidgets('tocar na borda, no rótulo, no texto e no ícone abre o seletor', (tester) async {
      var toques = 0;
      await tester.pumpWidget(campo(aoTocar: () => toques++));
      final canto = tester.getTopLeft(find.byType(CampoData));
      final fim = tester.getBottomRight(find.byType(CampoData));

      await tester.tapAt(canto + const Offset(3, 3)); // borda
      await tester.tapAt(fim - const Offset(3, 3)); // borda oposta
      await tester.tap(find.text('Data de nascimento')); // rótulo
      await tester.tap(find.text('26/05/1995')); // texto
      await tester.tap(find.byIcon(LucideIcons.calendar)); // ícone
      await tester.tapAt(Offset(fim.dx - 40, canto.dy + 24)); // meio-direita, sem texto

      expect(toques, 6);
    });

    testWidgets('a ação de tocar da semântica também abre (caminho da web/leitor de tela)',
        (tester) async {
      // Sem `onTap` no nó de semântica, o nó existia mas a ação "tocar" não tinha
      // para onde ir: o toque que chega pela semântica (Safari, VoiceOver) se perdia.
      final handle = tester.ensureSemantics();
      var toques = 0;
      await tester.pumpWidget(campo(aoTocar: () => toques++));

      tester.semantics.tap(find.semantics.byLabel(RegExp('Data de nascimento: 26/05/1995')));
      await tester.pump();

      expect(toques, 1);
      handle.dispose();
    });

    testWidgets('um toque dispara uma vez só (ponteiro e semântica não duplicam)', (tester) async {
      final handle = tester.ensureSemantics();
      var toques = 0;
      await tester.pumpWidget(campo(aoTocar: () => toques++));

      await tester.tap(find.byType(CampoData));
      await tester.pump();

      expect(toques, 1);
      handle.dispose();
    });

    testWidgets('altura mínima de 44 px', (tester) async {
      await tester.pumpWidget(campo(aoTocar: () {}));
      expect(tester.getSize(find.byType(CampoData)).height, greaterThanOrEqualTo(44));
    });

    testWidgets('vazio mostra dd/mm/aaaa em cor de dica', (tester) async {
      await tester.pumpWidget(campo(texto: null, aoTocar: () {}));

      expect(find.text('dd/mm/aaaa'), findsOneWidget);
      expect(find.text('Toque para escolher'), findsNothing);
      final cores = AppTheme.claro.extension<AppColors>()!;
      expect(tester.widget<Text>(find.text('dd/mm/aaaa')).style?.color, cores.textSecondary);

      // Preenchido, o texto volta à cor de valor (não de dica).
      await tester.pumpWidget(campo(aoTocar: () {}));
      expect(tester.widget<Text>(find.text('26/05/1995')).style?.color, isNot(cores.textSecondary));
    });

    testWidgets('texto vazio ("") também é tratado como sem data', (tester) async {
      await tester.pumpWidget(campo(texto: '', aoTocar: () {}));
      expect(find.text('dd/mm/aaaa'), findsOneWidget);
    });

    testWidgets('rótulo falado: valor e que dá para trocar', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(campo(aoTocar: () {}));
      expect(find.bySemanticsLabel('Data de nascimento: 26/05/1995. Toque para trocar'),
          findsOneWidget);

      await tester.pumpWidget(campo(texto: null, aoTocar: () {}));
      expect(find.bySemanticsLabel('Data de nascimento: sem data. Toque para escolher'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('só leitura (aoTocar nulo): não é botão, não anuncia "toque" e não reage',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(campo());

      expect(find.bySemanticsLabel('Data de nascimento: 26/05/1995'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Toque para')), findsNothing);
      await tester.tap(find.byType(CampoData)); // não deve lançar
      handle.dispose();
    });

    for (final escuro in [false, true]) {
      testWidgets('360 px e fonte 1,3x sem estourar (${escuro ? 'escuro' : 'claro'})',
          (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: escuro ? AppTheme.escuro : AppTheme.claro,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CampoData(rotulo: 'Data de nascimento', texto: null, aoTocar: () {}),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(CampoData)).height, greaterThanOrEqualTo(44));
      });
    }
  });

  // ================= Seletor =================

  /// Abre o seletor por um botão e guarda o que ele devolveu.
  Widget host({
    required void Function(DateTime?) aoFechar,
    bool abrirDigitando = false,
    DateTime? inicial,
  }) =>
      MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => aoFechar(await escolherData(
                context,
                titulo: 'Data de nascimento',
                primeira: DateTime(1926, 11, 9),
                ultima: DateTime(2016, 11, 9),
                inicial: inicial,
                sugestao: DateTime(1996, 11, 9),
                abrirDigitando: abrirDigitando,
              )),
              child: const Text('abrir'),
            ),
          ),
        ),
      );

  Future<void> abrir(WidgetTester tester) async {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder campoTexto() => find.byType(TextField);

  setUp(reiniciarSeletorDeData);

  group('escolherData', () {
    testWidgets('abre no calendário por padrão, com o botão de digitar à vista', (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}));
      await abrir(tester);

      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(campoTexto(), findsNothing);
      expect(find.byTooltip('Digitar a data'), findsOneWidget);
      final cal = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(cal.firstDate, DateTime(1926, 11, 9));
      expect(cal.lastDate, DateTime(2016, 11, 9));
      expect(cal.initialDate, DateTime(1996, 11, 9)); // a sugestão, sem data ainda
    });

    testWidgets('com abrirDigitando abre no campo de texto, com o botão do calendário à vista',
        (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}, abrirDigitando: true));
      await abrir(tester);

      expect(campoTexto(), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(find.byTooltip('Escolher no calendário'), findsOneWidget);
      final campo = tester.widget<TextField>(campoTexto());
      expect(campo.keyboardType, TextInputType.number); // teclado de dígitos
      expect(campo.autofocus, isTrue);
      expect(campo.inputFormatters!.single, isA<MascaraDataFormatter>());
      expect(find.text('dd/mm/aaaa'), findsOneWidget); // dica do campo vazio
    });

    testWidgets('digitar 26051995 sem barras e confirmar devolve a data', (tester) async {
      DateTime? r;
      await tester.pumpWidget(host(aoFechar: (d) => r = d, abrirDigitando: true));
      await abrir(tester);

      await tester.enterText(campoTexto(), '26051995');
      await tester.pump();
      expect(tester.widget<TextField>(campoTexto()).controller!.text, '26/05/1995');

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(r, DateTime(1995, 5, 26));
    });

    testWidgets('digitar com as barras continua funcionando', (tester) async {
      DateTime? r;
      await tester.pumpWidget(host(aoFechar: (d) => r = d, abrirDigitando: true));
      await abrir(tester);

      await tester.enterText(campoTexto(), '26/05/1995');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(r, DateTime(1995, 5, 26));
    });

    testWidgets('data que já existe vem preenchida na digitação', (tester) async {
      await tester.pumpWidget(
          host(aoFechar: (_) {}, abrirDigitando: true, inicial: DateTime(1990, 3, 4)));
      await abrir(tester);

      expect(tester.widget<TextField>(campoTexto()).controller!.text, '04/03/1990');
    });

    testWidgets('data inexistente mostra o erro e não fecha nem devolve', (tester) async {
      var fechou = false;
      await tester.pumpWidget(host(aoFechar: (_) => fechou = true, abrirDigitando: true));
      await abrir(tester);

      await tester.enterText(campoTexto(), '31021995');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Essa data não existe.'), findsOneWidget);
      expect(campoTexto(), findsOneWidget); // o seletor continua aberto
      expect(fechou, isFalse);

      // Mês 13 também.
      await tester.enterText(campoTexto(), '15131995');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Essa data não existe.'), findsOneWidget);
      expect(fechou, isFalse);
    });

    testWidgets('data incompleta pede a data inteira', (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}, abrirDigitando: true));
      await abrir(tester);

      await tester.enterText(campoTexto(), '2605');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Digite a data inteira: dd/mm/aaaa.'), findsOneWidget);
    });

    testWidgets('fora da faixa mostra o intervalo e não devolve', (tester) async {
      var fechou = false;
      await tester.pumpWidget(host(aoFechar: (_) => fechou = true, abrirDigitando: true));
      await abrir(tester);

      for (final fora in ['26052020', '26051920', '10112016', '08111926']) {
        await tester.enterText(campoTexto(), fora);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Use uma data entre 09/11/1926 e 09/11/2016.'), findsOneWidget,
            reason: fora);
      }
      expect(fechou, isFalse);
    });

    testWidgets('os limites da faixa são aceitos (inclusive)', (tester) async {
      DateTime? r;
      await tester.pumpWidget(host(aoFechar: (d) => r = d, abrirDigitando: true));
      await abrir(tester);

      await tester.enterText(campoTexto(), '09112016');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(r, DateTime(2016, 11, 9));

      r = null;
      await abrir(tester);
      await tester.enterText(campoTexto(), '09111926');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(r, DateTime(1926, 11, 9));
    });

    testWidgets('corrigir o campo limpa o erro', (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}, abrirDigitando: true));
      await abrir(tester);
      await tester.enterText(campoTexto(), '31021995');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Essa data não existe.'), findsOneWidget);

      await tester.enterText(campoTexto(), '28021995');
      await tester.pumpAndSettle();

      expect(find.text('Essa data não existe.'), findsNothing);
    });

    testWidgets('alternar para o calendário leva a data digitada; e de volta, a escolhida lá',
        (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}, abrirDigitando: true));
      await abrir(tester);

      await tester.enterText(campoTexto(), '26051995');
      await tester.tap(find.byTooltip('Escolher no calendário'));
      await tester.pumpAndSettle();

      var cal = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(cal.initialDate, DateTime(1995, 5, 26));

      // Escolhe outro dia no calendário e volta a digitar: o campo mostra esse dia.
      await tester.tap(find.text('10'));
      await tester.pump();
      await tester.tap(find.byTooltip('Digitar a data'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(campoTexto()).controller!.text, '10/05/1995');
    });

    testWidgets('no calendário, OK devolve o dia escolhido; Cancelar devolve nulo', (tester) async {
      DateTime? r = DateTime(2000);
      await tester.pumpWidget(host(aoFechar: (d) => r = d));
      await abrir(tester);
      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(r, DateTime(1996, 11, 15));

      await abrir(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(r, isNull);
    });

    testWidgets('um toque que chega duas vezes não empilha dois seletores', (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}));

      await tester.tap(find.text('abrir'));
      await tester.tap(find.text('abrir'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('o botão de alternar tem alvo de pelo menos 44 px', (tester) async {
      await tester.pumpWidget(host(aoFechar: (_) {}));
      await abrir(tester);

      final tamanho = tester.getSize(find.widgetWithIcon(IconButton, LucideIcons.pencil));
      expect(tamanho.width, greaterThanOrEqualTo(44));
      expect(tamanho.height, greaterThanOrEqualTo(44));
    });

    testWidgets('abrir o diálogo em 360 px e fonte 1,3x não estoura', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.escuro,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => escolherData(
                context,
                titulo: 'Data de nascimento',
                primeira: DateTime(1926, 11, 9),
                ultima: DateTime(2016, 11, 9),
                abrirDigitando: true,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Escolher no calendário'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
