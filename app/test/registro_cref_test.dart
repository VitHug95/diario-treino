import 'dart:async';

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
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PBI-106: a tela "Registro profissional (CREF)", a máscara do CPF e o Perfil
/// com a verificação exigida.

const _cpf = '52998224725';
const _cpfFormatado = '529.982.247-25';

/// "Servidor" do CREF em memória.
class _RepoCref extends EducadorRepository {
  _RepoCref({this.resposta = const ResultadoVerificacaoCref(resultado: 'NAO_ENCONTRADO'), this.educador = false})
      : super(Dio());

  ResultadoVerificacaoCref resposta;
  bool educador;
  RegistroCref? registro;
  Completer<void>? segurar;
  EducadorException? erro;
  final pedidos = <(String, String, String)>[];

  @override
  Future<SituacaoCref> obterSituacaoCref() async =>
      SituacaoCref(verificacaoExigida: true, registro: registro);

  @override
  Future<ResultadoVerificacaoCref> verificarCref({
    required String uf,
    required String numero,
    required String cpf,
  }) async {
    pedidos.add((uf, numero, cpf));
    await segurar?.future;
    if (erro != null) throw erro!;
    if (resposta.habilitado) {
      educador = true;
      registro = RegistroCref(
        uf: uf, numero: numero, situacao: 'ATIVO', categoria: 'BACHAREL', origem: 'AUTOMATICA',
        consultadoEm: DateTime(2026, 11, 26),
      );
    }
    return resposta;
  }
}

Future<void> _preencher(WidgetTester tester, {String uf = 'MG', String numero = '1234', String cpf = _cpf}) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(uf).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Número do CREF'), numero);
  await tester.enterText(find.widgetWithText(TextFormField, 'CPF'), cpf);
}

Future<void> _verificar(WidgetTester tester) async {
  await tester.tap(find.text('VERIFICAR REGISTRO'));
  await tester.pumpAndSettle();
}

void _tela(WidgetTester tester, {double largura = 400}) {
  tester.view.physicalSize = Size(largura, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrir(WidgetTester tester, _RepoCref repo,
    {bool travado = false, bool escuro = false, double largura = 400}) async {
  _tela(tester, largura: largura);
  await tester.pumpWidget(ProviderScope(
    overrides: [educadorRepositoryProvider.overrideWithValue(repo)],
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
  tester.view.physicalSize = const Size(800, 2000);
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
  // ---- Máscara e CPF ----

  group('máscara do CPF', () {
    test('digitar só números preenche pontos e traço', () {
      expect(_digitar('529').text, '529');
      expect(_digitar('5299').text, '529.9');
      expect(_digitar(_cpf).text, _cpfFormatado);
      expect(_digitar('${_cpf}99').text, _cpfFormatado); // para nos 11 dígitos
    });

    test('colar com ou sem pontuação dá o mesmo', () {
      const f = MascaraCpfFormatter();
      for (final colado in [_cpf, _cpfFormatado, '529 982 247 25']) {
        final r = f.formatEditUpdate(TextEditingValue.empty,
            TextEditingValue(text: colado, selection: TextSelection.collapsed(offset: colado.length)));
        expect(r.text, _cpfFormatado);
      }
    });

    test('apagar do fim tira um dígito; apagar o separador leva o dígito anterior', () {
      const f = MascaraCpfFormatter();
      const cheio = TextEditingValue(text: '529.9', selection: TextSelection.collapsed(offset: 5));
      expect(f.formatEditUpdate(cheio, const TextEditingValue(text: '529.', selection: TextSelection.collapsed(offset: 4))).text, '529');
      // Cursor logo depois do ponto, apagando o ponto.
      const antes = TextEditingValue(text: '529.98', selection: TextSelection.collapsed(offset: 4));
      final r = f.formatEditUpdate(antes, const TextEditingValue(text: '52998', selection: TextSelection.collapsed(offset: 3)));
      expect(r.text, '529.8');
      expect(r.selection.baseOffset, 2);
    });

    test('dígito verificador conferido no app', () {
      expect(cpfValido(_cpfFormatado), isTrue);
      expect(cpfValido('529.982.247-26'), isFalse);
      expect(cpfValido('111.111.111-11'), isFalse);
      expect(cpfValido('529.982'), isFalse);
    });
  });

  // ---- A tela ----

  testWidgets('campos, texto do CPF e CPF inválido não consulta', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);

    expect(find.text('UF do CREF'), findsOneWidget);
    expect(find.text('Usamos seu CPF só para consultar o seu registro no CREF. Não guardamos o CPF.'), findsOneWidget);
    final campo = tester.widget<TextField>(find.descendant(
        of: find.widgetWithText(TextFormField, 'CPF'), matching: find.byType(TextField)));
    expect(campo.keyboardType, TextInputType.number);
    expect(campo.autofillHints, isEmpty);
    expect(campo.enableSuggestions, isFalse);

    await _preencher(tester, cpf: '52998224726');
    await _verificar(tester);
    expect(find.text('Confira o CPF.'), findsOneWidget);
    expect(repo.pedidos, isEmpty);
  });

  testWidgets('a tela manda os dados e mostra a máscara no campo', (tester) async {
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester);
    expect(find.text(_cpfFormatado), findsOneWidget);

    await _verificar(tester);
    expect(repo.pedidos, [('MG', '1234', _cpfFormatado)]);
  });

  for (final (resposta, mensagem) in [
    (const ResultadoVerificacaoCref(resultado: 'RECUSADO', motivo: 'SITUACAO_NAO_ATIVA', situacao: 'CANCELADO'),
        'Seu registro consta como CANCELADO no CREF. Regularize e tente de novo.'),
    (const ResultadoVerificacaoCref(resultado: 'RECUSADO', motivo: 'NUMERO_NAO_CONFERE'),
        'O CPF tem registro no CREF dessa UF, mas com outro número. Confira o número.'),
    (const ResultadoVerificacaoCref(resultado: 'NAO_ENCONTRADO'),
        'Não encontramos esse CPF no CREF dessa UF. Confira a UF e o número.'),
    (const ResultadoVerificacaoCref(resultado: 'INDISPONIVEL'),
        'A consulta do CREF está fora do ar agora, tente em alguns minutos.'),
    (const ResultadoVerificacaoCref(resultado: 'INDISPONIVEL', motivo: 'UF_SEM_CONSULTA'),
        'Ainda não conseguimos consultar o CREF dessa UF automaticamente.'),
  ]) {
    testWidgets('mensagem: ${resposta.resultado} ${resposta.motivo ?? ''}', (tester) async {
      final repo = _RepoCref(resposta: resposta);
      await _abrir(tester, repo);
      await _preencher(tester);
      await _verificar(tester);

      expect(find.text(mensagem), findsOneWidget);
      expect(find.textContaining(_cpf), findsNothing);
      // Pode tentar de novo: o botão volta e o CPF continua no campo.
      expect(find.text('VERIFICAR REGISTRO'), findsOneWidget);
      expect(find.text(_cpfFormatado), findsOneWidget);
    });
  }

  testWidgets('limite de tentativas', (tester) async {
    final repo = _RepoCref()..erro = const EducadorException('Você já tentou 5 vezes hoje. Tente amanhã.');
    await _abrir(tester, repo);
    await _preencher(tester);
    await _verificar(tester);

    expect(find.text('Você já tentou 5 vezes hoje. Tente amanhã.'), findsOneWidget);
  });

  testWidgets('enquanto consulta, mostra progresso e não deixa tocar de novo', (tester) async {
    final repo = _RepoCref()..segurar = Completer<void>();
    await _abrir(tester, repo);
    await _preencher(tester);

    await tester.tap(find.text('VERIFICAR REGISTRO'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Consultando o CREF'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.byType(FilledButton));
    expect(repo.pedidos, hasLength(1));

    repo.segurar!.complete();
    await tester.pumpAndSettle();
    expect(find.text('VERIFICAR REGISTRO'), findsOneWidget);
  });

  testWidgets('habilitado: avisa e troca para o registro confirmado, sem o CPF na tela', (tester) async {
    final repo = _RepoCref(resposta: const ResultadoVerificacaoCref(resultado: 'HABILITADO', situacao: 'ATIVO'));
    await _abrir(tester, repo);
    await _preencher(tester);
    await _verificar(tester);

    expect(find.text('Registro ativo confirmado. Modo educador liberado.'), findsOneWidget);
    expect(find.text('Registro confirmado'), findsOneWidget);
    expect(find.text('MG'), findsOneWidget);
    expect(find.text('26/11/2026'), findsOneWidget);
    expect(find.text(_cpfFormatado), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
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

  testWidgets('sair e voltar: o CPF não fica guardado (nem no aparelho)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _RepoCref();
    await _abrir(tester, repo);
    await _preencher(tester);

    await tester.pumpWidget(const SizedBox());
    await _abrir(tester, repo);

    expect(find.text(_cpfFormatado), findsNothing);
    expect(prefs.getKeys(), isEmpty);
  });

  for (final escuro in [false, true]) {
    testWidgets('360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'}), com mensagem', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _abrir(tester, _RepoCref(), travado: true, escuro: escuro, largura: 360);
      await _preencher(tester);
      await _verificar(tester);
      expect(find.textContaining('Não encontramos esse CPF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // ---- O Perfil ----

  testWidgets('Perfil: ativar abre o CREF e, habilitado, mostra os alunos sem F5', (tester) async {
    final repo = _RepoCref(resposta: const ResultadoVerificacaoCref(resultado: 'HABILITADO', situacao: 'ATIVO'));
    final router = await _abrirPerfil(tester, repo);
    expect(find.text('Meus alunos'), findsNothing);

    await tester.tap(find.text('Ativar modo educador'));
    await tester.pumpAndSettle();
    expect(find.byType(RegistroCrefScreen), findsOneWidget);

    await _preencher(tester);
    await _verificar(tester);
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
