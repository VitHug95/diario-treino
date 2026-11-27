import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/perfil_api.dart';
import 'package:diario_treino/features/auth/perfil_screen.dart';
import 'package:diario_treino/features/educador/cref_models.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/educador/registro_cref_screen.dart';
import 'package:diario_treino/features/medidas/compartilhamento_repository.dart';
import 'package:diario_treino/features/medidas/medidas_models.dart';
import 'package:diario_treino/features/medidas/medidas_repository.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_models.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_repository.dart';
import 'package:diario_treino/shared/mascara_cpf.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PBI-106: a tela "Registro profissional (CREF)" com o envio de número, UF e
/// foto da carteira (decisão do PO, 27/11), o Perfil com a validação exigida, e
/// a máscara e a conta do CPF (guardadas para a consulta futura).

const _cpf = '52998224725';
const _cpfFormatado = '529.982.247-25';

/// PNG de 1×1 de verdade, para a prévia decodificar sem erro.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// "Servidor" do CREF em memória.
class _RepoCref extends EducadorRepository {
  _RepoCref({this.educador = false}) : super(Dio());

  bool educador;
  RegistroCref? registro;
  Completer<void>? segurar;
  EducadorException? erro;
  final pedidos = <(String, String, int, String)>[];

  @override
  Future<SituacaoCref> obterSituacaoCref() async =>
      SituacaoCref(verificacaoExigida: true, registro: registro);

  @override
  Future<ResultadoVerificacaoCref> declararCref({
    required String uf,
    required String numero,
    required Uint8List foto,
    required String tipoFoto,
  }) async {
    pedidos.add((uf, numero, foto.length, tipoFoto));
    await segurar?.future;
    if (erro != null) throw erro!;
    educador = true;
    registro = RegistroCref(uf: uf, numero: numero, origem: 'DECLARADA', declaradoEm: DateTime(2026, 11, 27));
    return const ResultadoVerificacaoCref(resultado: 'HABILITADO');
  }
}

/// Foto que o "seletor" devolve; nulo = desistiu.
Uint8List? _fotoDoSeletor;

Override _seletor() => escolherFotoCrefProvider.overrideWithValue(() async => _fotoDoSeletor);

Future<void> _preencher(WidgetTester tester,
    {String uf = 'MG', String numero = '1234', Uint8List? foto, bool comFoto = true, bool? permitir = true}) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(uf).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Número do CREF'), numero);
  if (comFoto) {
    _fotoDoSeletor = foto ?? _png;
    await tester.tap(find.text('Escolher foto da carteira'));
    await tester.pumpAndSettle();
  }
  if (permitir != null) {
    await tester.tap(find.text(permitir ? 'Eu permito' : 'Eu não permito'));
    await tester.pumpAndSettle();
  }
}

Future<void> _enviar(WidgetTester tester) async {
  await tester.tap(find.text('ENVIAR REGISTRO'));
  await tester.pumpAndSettle();
}

void _tela(WidgetTester tester, {double largura = 400}) {
  tester.view.physicalSize = Size(largura, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrir(WidgetTester tester, _RepoCref repo,
    {bool travado = false, bool escuro = false, double largura = 400}) async {
  _tela(tester, largura: largura);
  await tester.pumpWidget(ProviderScope(
    overrides: [educadorRepositoryProvider.overrideWithValue(repo), _seletor()],
    child: MaterialApp(
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      home: RegistroCrefScreen(travado: travado),
    ),
  ));
  await tester.pumpAndSettle();
}

/// O Perfil com o go_router, para abrir a tela do CREF e voltar.
Future<GoRouter> _abrirPerfil(WidgetTester tester, _RepoCref repo) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/perfil',
    routes: [
      GoRoute(path: '/perfil', builder: (_, __) => const PerfilScreen()),
      GoRoute(
        path: Rotas.registroCref,
        builder: (_, s) => RegistroCrefScreen(travado: s.extra == true),
      ),
      GoRoute(path: Rotas.alunos, builder: (_, __) => const Scaffold(body: Text('LISTA DE ALUNOS'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      educadorRepositoryProvider.overrideWithValue(repo),
      _seletor(),
      // O perfil segue o "servidor": habilitado, ganha o papel EDUCADOR.
      perfilProvider.overrideWith((ref) async => Perfil(
            id: 'u1', nome: 'Vitor', email: 'v@teste.local',
            papeis: ['ATLETA', if (repo.educador) 'EDUCADOR'],
          )),
      convitesPendentesProvider.overrideWith((ref) async => []),
      educadoresDoAlunoProvider.overrideWith((ref) async => []),
      resumoMedidasProvider.overrideWith((ref) async => const ResumoMedidas(ultimas: [], historico: [])),
      perfilCorporalProvider.overrideWith((ref) async => const PerfilCorporal()),
      compartilhamentoCorporalProvider.overrideWith(
          (ref) async => const CompartilhamentoCorporal(dadosCorporais: false, medidas: false)),
    ],
    child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

TextEditingValue _digitar(String texto) {
  var valor = TextEditingValue.empty;
  const f = MascaraCpfFormatter();
  for (final c in texto.split('')) {
    final novo = valor.text + c;
    valor = f.formatEditUpdate(valor, TextEditingValue(text: novo, selection: TextSelection.collapsed(offset: novo.length)));
  }
  return valor;
}

void main() {
  setUp(() => _fotoDoSeletor = null);

  // ---- Máscara e CPF (guardados para a consulta por CPF) ----

  group('máscara do CPF', () {
    test('digitar só números preenche pontos e traço', () {
      expect(_digitar('529').text, '529');
      expect(_digitar('5299').text, '529.9');
      expect(_digitar(_cpf).text, _cpfFormatado);
      expect(_digitar('${_cpf}99').text, _cpfFormatado);
    });

    test('colar com ou sem pontuação dá o mesmo', () {
      const f = MascaraCpfFormatter();
      for (final colado in [_cpf, _cpfFormatado, '529 982 247 25']) {
        final r = f.formatEditUpdate(TextEditingValue.empty,
            TextEditingValue(text: colado, selection: TextSelection.collapsed(offset: colado.length)));
        expect(r.text, _cpfFormatado);
      }
    });

    test('apagar o separador leva o dígito anterior', () {
      const f = MascaraCpfFormatter();
      const antes = TextEditingValue(text: '529.98', selection: TextSelection.collapsed(offset: 4));
      final r = f.formatEditUpdate(antes, const TextEditingValue(text: '52998', selection: TextSelection.collapsed(offset: 3)));
      expect(r.text, '529.8');
    });

    test('dígito verificador', () {
      expect(cpfValido(_cpfFormatado), isTrue);
      expect(cpfValido('529.982.247-26'), isFalse);
      expect(cpfValido('111.111.111-11'), isFalse);
    });
  });

  test('tipo da foto pelo conteúdo, como o servidor', () {
    expect(tipoDaFotoCref(_png), 'image/png');
    expect(tipoDaFotoCref([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
    expect(tipoDaFotoCref(utf8.encode('GIF89a')), isNull);
    expect(tipoDaFotoCref(const []), isNull);
  });

  // ---- A tela ----

  testWidgets('campos, texto da permissão e nenhum campo de CPF', (tester) async {
    await _abrir(tester, _RepoCref());

    expect(find.text('UF do CREF'), findsOneWidget);
    expect(find.text('Número do CREF'), findsOneWidget);
    expect(find.text('Escolher foto da carteira'), findsOneWidget);
    expect(find.text(textoPermissaoCref), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'CPF'), findsNothing);
  });

  testWidgets('sem marcar a permissão, o botão fica desligado', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester, permitir: null);

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await _enviar(tester);
    expect(repo.pedidos, isEmpty);
  });

  testWidgets('"Eu não permito": não envia, não habilita e tira a foto da tela', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester, permitir: false);

    expect(find.text('Sem a sua permissão, o registro não é guardado e o modo educador não é habilitado.'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Foto da carteira escolhida'), findsNothing);
    expect(find.text('Escolher foto da carteira'), findsOneWidget);
    await _enviar(tester);
    expect(repo.pedidos, isEmpty);
    expect(repo.educador, isFalse);
  });

  testWidgets('sem foto, avisa e não envia', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester, comFoto: false);
    await _enviar(tester);

    expect(find.text('Escolha a foto da carteira do CREF.'), findsOneWidget);
    expect(repo.pedidos, isEmpty);
  });

  testWidgets('arquivo que não é JPG nem PNG é recusado na hora', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester, foto: Uint8List.fromList(utf8.encode('GIF89a...')));

    expect(find.text('Escolha uma foto JPG ou PNG de até 5 MB.'), findsOneWidget);
    expect(find.text('Escolher foto da carteira'), findsOneWidget); // não ficou escolhida
    await _enviar(tester);
    expect(repo.pedidos, isEmpty);
  });

  testWidgets('desistir de escolher não muda nada', (tester) async {
    await _abrir(tester, _RepoCref());
    _fotoDoSeletor = null;
    await tester.tap(find.text('Escolher foto da carteira'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher foto da carteira'), findsOneWidget);
  });

  testWidgets('envio: manda UF, número e a foto, avisa e mostra o registro enviado', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester);
    expect(find.bySemanticsLabel('Foto da carteira escolhida'), findsOneWidget);
    expect(find.text('Trocar foto'), findsOneWidget);

    await _enviar(tester);

    expect(repo.pedidos, [('MG', '1234', _png.length, 'image/png')]);
    expect(find.text('Registro enviado. Modo educador liberado.'), findsOneWidget);
    expect(find.text('Registro enviado'), findsOneWidget);
    expect(find.text('27/11/2026'), findsOneWidget);
    expect(find.textContaining('O registro pode ser conferido'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('erro do servidor aparece na tela e deixa tentar de novo', (tester) async {
    final repo = _RepoCref()..erro = const EducadorException('Este registro do CREF já está ligado a outra conta.');
    await _abrir(tester, repo);
    await _preencher(tester);
    await _enviar(tester);

    expect(find.text('Este registro do CREF já está ligado a outra conta.'), findsOneWidget);
    expect(find.text('ENVIAR REGISTRO'), findsOneWidget);
  });

  testWidgets('enquanto envia, mostra progresso e não deixa tocar de novo', (tester) async {
    final repo = _RepoCref()..segurar = Completer<void>();
    await _abrir(tester, repo);
    await _preencher(tester);

    await tester.tap(find.text('ENVIAR REGISTRO'));
    await tester.pump();
    expect(find.bySemanticsLabel('Enviando o registro'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.byType(FilledButton));
    expect(repo.pedidos, hasLength(1));

    repo.segurar!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('educador travado vê o aviso para continuar acompanhando alunos', (tester) async {
    await _abrir(tester, _RepoCref(), travado: true);
    expect(find.text('Para continuar acompanhando alunos, confirme seu registro no CREF.'), findsOneWidget);
  });

  testWidgets('legado vê o registro confirmado sem UF nem número', (tester) async {
    final repo = _RepoCref()..registro = const RegistroCref(origem: 'LEGADO');
    await _abrir(tester, repo);
    expect(find.text('Registro confirmado'), findsOneWidget);
    expect(find.text('Modo educador liberado antes da verificação pelo CREF.'), findsOneWidget);
  });

  testWidgets('sair e voltar: a foto não fica guardada no aparelho', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester);

    await tester.pumpWidget(const SizedBox());
    await _abrir(tester, repo);

    expect(find.text('Escolher foto da carteira'), findsOneWidget);
    expect(prefs.getKeys(), isEmpty);
  });

  for (final escuro in [false, true]) {
    testWidgets('360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'}), com foto e erro', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = _RepoCref()..erro = const EducadorException('Confira a UF, o número e a foto.');
      await _abrir(tester, repo, travado: true, escuro: escuro, largura: 360);
      await _preencher(tester);
      await _enviar(tester);
      expect(find.text('Confira a UF, o número e a foto.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // ---- O Perfil ----

  testWidgets('Perfil: ativar abre o CREF e, enviado, mostra os alunos sem F5', (tester) async {
    final repo = _RepoCref();
    final router = await _abrirPerfil(tester, repo);
    expect(find.text('Meus alunos'), findsNothing);

    await tester.tap(find.text('Ativar modo educador'));
    await tester.pumpAndSettle();
    expect(find.byType(RegistroCrefScreen), findsOneWidget);

    await _preencher(tester);
    await _enviar(tester);
    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Meus alunos'), findsOneWidget);
    expect(find.text('Convidar aluno'), findsOneWidget);
    expect(find.text('Registro confirmado'), findsOneWidget);
  });

  testWidgets('Perfil: educador sem registro fica travado e "Meus alunos" abre o CREF', (tester) async {
    await _abrirPerfil(tester, _RepoCref(educador: true));

    expect(find.text('Confirme seu registro no CREF'), findsOneWidget);
    await tester.tap(find.text('Meus alunos'));
    await tester.pumpAndSettle();

    expect(find.byType(RegistroCrefScreen), findsOneWidget);
    expect(find.text('Para continuar acompanhando alunos, confirme seu registro no CREF.'), findsOneWidget);
    expect(find.text('LISTA DE ALUNOS'), findsNothing);
  });

  testWidgets('Perfil: educador habilitado segue para a lista de alunos', (tester) async {
    final repo = _RepoCref(educador: true)..registro = const RegistroCref(origem: 'LEGADO');
    await _abrirPerfil(tester, repo);

    expect(find.text('Confirme seu registro no CREF'), findsNothing);
    await tester.tap(find.text('Meus alunos'));
    await tester.pumpAndSettle();
    expect(find.text('LISTA DE ALUNOS'), findsOneWidget);
  });
}
