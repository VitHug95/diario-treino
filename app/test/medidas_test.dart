import 'package:dio/dio.dart';
import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/perfil_api.dart';
import 'package:diario_treino/features/auth/perfil_screen.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/medidas/medidas_comandos.dart';
import 'package:diario_treino/features/medidas/medidas_corporais_screen.dart';
import 'package:diario_treino/features/medidas/medidas_formato.dart';
import 'package:diario_treino/features/medidas/medidas_models.dart';
import 'package:diario_treino/features/medidas/medidas_repository.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_models.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_repository.dart';
import 'package:diario_treino/features/medidas/registrar_medidas_screen.dart';
import 'package:diario_treino/shared/seletor_data.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PBI-92 (E12): medidas corporais no app. Perfil com o bloco "Corpo", lista com
/// variação e histórico, registro parcial, edição/exclusão de um dia e a
/// invalidação por `Mudanca.medidas`.

final _hoje = DateTime(2026, 11, 9);
final _dia = DateTime(2026, 11, 5);

class _RelogioFixo implements Relogio {
  @override
  DateTime agora() => DateTime(2026, 11, 9, 10);
}

/// Repositório em memória: mesmo contrato da API (upsert por tipo, nulo remove).
class _RepoFake extends MedidasRepository {
  _RepoFake() : super(Dio());

  final dias = <DateTime, Map<TipoMedida, double>>{};
  final salvos = <(DateTime, Map<TipoMedida, double?>)>[];
  final excluidos = <DateTime>[];
  bool falharResumo = false;

  @override
  Future<ResumoMedidas> obterResumo() async {
    if (falharResumo) throw Exception('rede');
    final ultimas = <UltimaMedida>[];
    for (final tipo in TipoMedida.values) {
      final datas = dias.keys.where((d) => dias[d]!.containsKey(tipo)).toList()
        ..sort((a, b) => b.compareTo(a));
      if (datas.isEmpty) continue;
      final valor = dias[datas.first]![tipo]!;
      final variacao =
          datas.length > 1 ? valor - dias[datas[1]]![tipo]! : null;
      ultimas.add(UltimaMedida(
          tipo: tipo, valor: valor, data: datas.first, variacao: variacao));
    }
    final historico = (dias.keys.toList()..sort((a, b) => b.compareTo(a)))
        .map((d) => DiaHistoricoMedidas(data: d, quantidade: dias[d]!.length))
        .toList();
    return ResumoMedidas(ultimas: ultimas, historico: historico);
  }

  @override
  Future<DiaMedidas> obterDia(DateTime data) async =>
      DiaMedidas(Map.of(dias[data] ?? {}));

  @override
  Future<void> salvarMedidas(
      DateTime data, Map<TipoMedida, double?> valores) async {
    salvos.add((data, valores));
    final dia = dias.putIfAbsent(data, () => {});
    for (final e in valores.entries) {
      if (e.value == null) {
        dia.remove(e.key);
      } else {
        dia[e.key] = e.value!;
      }
    }
    if (dia.isEmpty) dias.remove(data);
  }

  @override
  Future<void> excluirMedidas(DateTime data) async {
    excluidos.add(data);
    dias.remove(data);
  }
}

Future<ProviderScope> _escopo(_RepoFake repo, Widget filho) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      medidasRepositoryProvider.overrideWithValue(repo),
      relogioProvider.overrideWithValue(_RelogioFixo()),
      perfilProvider.overrideWith((ref) async => const Perfil(
          id: 'u1', nome: 'Vitor', email: 'v@teste.local', papeis: ['ATLETA'])),
      convitesPendentesProvider.overrideWith((ref) async => []),
      // O Perfil também lê os dados corporais; aqui, sem eles.
      perfilCorporalProvider.overrideWith((ref) async => const PerfilCorporal()),
    ],
    child: filho,
  );
}

/// Tela alta e estreita (360 px): todos os campos ficam visíveis e o layout é
/// o do celular pequeno.
void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Abre [tela] empilhada sobre uma "home", para o `context.pop()` ter para onde voltar.
Future<GoRouter> _abrir(
  WidgetTester tester,
  _RepoFake repo,
  Widget tela, {
  ThemeData? tema,
}) async {
  _telaDeCelular(tester);
  final router = GoRouter(
    routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/tela', builder: (_, __) => tela),
      GoRoute(
          path: '/perfil/medidas/evolucao',
          builder: (_, state) => Scaffold(
              body: Text('evolucao ${(state.extra as TipoMedida).codigo}'))),
      GoRoute(
          path: '/perfil/medidas/registrar',
          builder: (_, state) => Scaffold(
              body: Text('registrar ${(state.extra as DateTime?)?.day ?? 'hoje'}'))),
    ],
  );
  await tester.pumpWidget(await _escopo(
    repo,
    MaterialApp.router(theme: tema ?? AppTheme.claro, routerConfig: router),
  ));
  router.push('/tela');
  await tester.pumpAndSettle();
  return router;
}

Finder _campo(String rotulo) => find.widgetWithText(TextField, rotulo);

String _texto(WidgetTester tester, String rotulo) =>
    tester.widget<TextField>(_campo(rotulo)).controller!.text;

ResumoMedidas _resumoExemplo() => ResumoMedidas(
      ultimas: [
        UltimaMedida(tipo: TipoMedida.peso, valor: 78.0, data: _dia, variacao: 0.5),
        UltimaMedida(tipo: TipoMedida.peito, valor: 100.0, data: _dia, variacao: 0.0),
        UltimaMedida(tipo: TipoMedida.cintura, valor: 84.0, data: _dia, variacao: -1.5),
        UltimaMedida(tipo: TipoMedida.coxaD, valor: 60.0, data: DateTime(2026, 10, 20)),
      ],
      historico: [
        DiaHistoricoMedidas(data: _dia, quantidade: 3),
        DiaHistoricoMedidas(data: DateTime(2026, 10, 20), quantidade: 1),
      ],
    );

class _RepoComResumo extends _RepoFake {
  _RepoComResumo(this._resumo);
  final ResumoMedidas _resumo;

  @override
  Future<ResumoMedidas> obterResumo() async => _resumo;
}

void main() {
  setUp(reiniciarSeletorDeData);

  // ---- Formatação ----

  group('formatação pt-BR', () {
    test('valor com vírgula e variação com sinal explícito', () {
      expect(formatarValor(84), '84,0');
      expect(formatarComUnidade(78.5, TipoMedida.peso), '78,5 kg');
      expect(formatarVariacao(-1.5, TipoMedida.cintura), '−1,5 cm');
      expect(formatarVariacao(0.5, TipoMedida.peso), '+0,5 kg');
      expect(formatarVariacao(0, TipoMedida.peso), 'Igual');
    });

    test('fala a variação por extenso, no singular quando é 1', () {
      expect(falarVariacao(-1.5, TipoMedida.cintura), 'caiu 1,5 centímetros');
      expect(falarVariacao(-1.0, TipoMedida.cintura), 'caiu 1,0 centímetro');
      expect(falarVariacao(2.0, TipoMedida.peso), 'subiu 2,0 quilos');
      expect(falarVariacao(0, TipoMedida.peso), 'sem variação');
    });

    test('resumo do Perfil', () {
      expect(resumoParaPerfil(const ResumoMedidas(ultimas: [], historico: [])),
          'Nenhuma medida ainda');
      expect(resumoParaPerfil(_resumoExemplo()),
          'Última em 05/11 · peso 78,0 kg');
    });

    test('são 12 tipos, só o peso em kg, com as faixas do back', () {
      expect(TipoMedida.values.length, 12);
      expect(TipoMedida.values.where((t) => t.unidade == 'kg'), [TipoMedida.peso]);
      expect((TipoMedida.peso.minimo, TipoMedida.peso.maximo), (30.0, 300.0));
      expect((TipoMedida.cintura.minimo, TipoMedida.cintura.maximo), (5.0, 250.0));
    });
  });

  // ---- Perfil ----

  testWidgets('Perfil mostra o bloco Corpo sem campos e "Nenhuma medida ainda"',
      (tester) async {
    await tester.pumpWidget(
        await _escopo(_RepoFake(), MaterialApp(theme: AppTheme.claro, home: const PerfilScreen())));
    await tester.pumpAndSettle();

    expect(find.text('CORPO'), findsOneWidget);
    expect(find.text('Medidas corporais'), findsOneWidget);
    expect(find.text('Nenhuma medida ainda'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // o Perfil não ganha campos
  });

  testWidgets('Perfil resume a última medição', (tester) async {
    final repo = _RepoFake()..dias[_dia] = {TipoMedida.cintura: 84.0};
    await tester.pumpWidget(
        await _escopo(repo, MaterialApp(theme: AppTheme.claro, home: const PerfilScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Última em 05/11 · cintura 84,0 cm'), findsOneWidget);
  });

  testWidgets('Linha do Perfil fala o resumo, não só o título', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = _RepoFake()..dias[_dia] = {TipoMedida.cintura: 84.0};
    await tester.pumpWidget(
        await _escopo(repo, MaterialApp(theme: AppTheme.claro, home: const PerfilScreen())));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel('Medidas corporais. Última em 05/11 · cintura 84,0 cm'),
        findsOneWidget);
    handle.dispose();
  });

  // ---- Lista ----

  testWidgets('Lista: últimas medidas com os três estados de variação e "Sem registro"',
      (tester) async {
    await _abrir(tester, _RepoComResumo(_resumoExemplo()), const MedidasCorporaisScreen());

    expect(find.text('Registrar medidas'), findsOneWidget);
    expect(find.text('84,0 cm'), findsOneWidget);
    expect(find.text('−1,5 cm'), findsOneWidget); // caiu
    expect(find.text('+0,5 kg'), findsOneWidget); // subiu
    expect(find.text('Igual'), findsOneWidget); // igual
    expect(find.text('Sem registro'), findsNWidgets(8)); // 12 tipos − 4 com registro
    expect(
        find.text('A variação compara com a medição anterior de cada medida.'),
        findsOneWidget);
    // Histórico por dia.
    expect(find.text('05/11/2026'), findsOneWidget);
    expect(find.text('3 medidas'), findsOneWidget);
    expect(find.text('1 medida'), findsOneWidget);
  });

  testWidgets('Lista: rótulos falados com a variação por extenso', (tester) async {
    final handle = tester.ensureSemantics();
    await _abrir(tester, _RepoComResumo(_resumoExemplo()), const MedidasCorporaisScreen());

    expect(
        find.bySemanticsLabel(RegExp(
            r'Cintura: 84,0 centímetros, caiu 1,5 centímetros desde a medição anterior')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Pescoço: sem registro'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Peito: 100,0 centímetros, sem variação desde a medição anterior')),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('Lista: a linha com registro abre a evolução daquela medida', (tester) async {
    await _abrir(tester, _RepoComResumo(_resumoExemplo()), const MedidasCorporaisScreen());

    await tester.tap(find.text('Cintura'));
    await tester.pumpAndSettle();

    expect(find.text('evolucao CINTURA'), findsOneWidget);
  });

  testWidgets('Lista: a linha sem registro não abre nada e não tem seta', (tester) async {
    final handle = tester.ensureSemantics();
    await _abrir(tester, _RepoComResumo(_resumoExemplo()), const MedidasCorporaisScreen());

    await tester.tap(find.text('Pescoço'));
    await tester.pumpAndSettle();

    expect(find.textContaining('evolucao'), findsNothing);
    expect(find.byType(MedidasCorporaisScreen), findsOneWidget);
    // Só as 4 linhas com registro anunciam o toque para ver a evolução.
    expect(find.bySemanticsLabel(RegExp('Toque para ver a evolução')), findsNWidgets(4));
    handle.dispose();
  });

  testWidgets('Lista sem medidas: texto de vazio e o botão de registrar', (tester) async {
    await _abrir(tester, _RepoFake(), const MedidasCorporaisScreen());

    expect(find.text('Nenhuma medida ainda'), findsOneWidget);
    expect(find.text('Registrar medidas'), findsOneWidget);
    expect(find.text('ÚLTIMAS MEDIDAS'), findsNothing);
  });

  testWidgets('Lista: erro de rede com "Tentar de novo" (ref.refresh)', (tester) async {
    final repo = _RepoFake()..falharResumo = true;
    await _abrir(tester, repo, const MedidasCorporaisScreen());

    expect(find.text('Não foi possível carregar suas medidas.'), findsOneWidget);

    repo
      ..falharResumo = false
      ..dias[_dia] = {TipoMedida.peso: 78.0};
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('78,0 kg'), findsOneWidget);
  });

  testWidgets('Lista: tocar num dia do histórico abre o registro daquele dia',
      (tester) async {
    await _abrir(tester, _RepoComResumo(_resumoExemplo()), const MedidasCorporaisScreen());
    // A rota de teste do registro mostra o dia recebido em `extra`.
    await tester.tap(find.text('05/11/2026'));
    await tester.pumpAndSettle();
    // Sem rota registrada para o caminho de produção neste router de teste, a
    // própria navegação já falharia; aqui basta a rota de teste responder.
    expect(find.text('registrar 5'), findsOneWidget);
  });

  // ---- Registro ----

  testWidgets('Registrar: os campos abrem vazios, com a ajuda da última medida',
      (tester) async {
    final repo = _RepoFake()..dias[_dia] = {TipoMedida.cintura: 84.0};
    await _abrir(tester, repo, const RegistrarMedidasScreen());

    expect(_texto(tester, 'Cintura'), isEmpty);
    expect(_texto(tester, 'Peso'), isEmpty);
    expect(find.text('última: 84,0'), findsOneWidget); // só ajuda, não é valor
    expect(find.text('Dia da medição'), findsOneWidget);
    expect(find.text('09/11/2026'), findsOneWidget); // hoje
    for (final grupo in ['CORPO TODO', 'TRONCO', 'BRAÇOS', 'PERNAS']) {
      expect(find.text(grupo), findsOneWidget);
    }
  });

  testWidgets('Registrar cintura e peito grava só esses dois, vírgula ou ponto',
      (tester) async {
    final repo = _RepoFake();
    await _abrir(tester, repo, const RegistrarMedidasScreen());

    await tester.enterText(_campo('Cintura'), '83,5');
    await tester.enterText(_campo('Peito'), '102.5');
    await tester.tap(find.text('Salvar medidas'));
    await tester.pumpAndSettle();

    expect(repo.salvos, hasLength(1));
    final (data, valores) = repo.salvos.single;
    expect(data, _hoje);
    expect(valores, {TipoMedida.cintura: 83.5, TipoMedida.peito: 102.5});
    expect(find.text('home'), findsOneWidget); // voltou
    expect(find.text('Medidas salvas'), findsOneWidget); // pílula de confirmação

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Salvar tudo vazio avisa e não grava nada', (tester) async {
    final repo = _RepoFake();
    await _abrir(tester, repo, const RegistrarMedidasScreen());

    await tester.tap(find.text('Salvar medidas'));
    await tester.pump();

    expect(find.text('Preencha ao menos uma medida'), findsOneWidget);
    expect(repo.salvos, isEmpty);
    expect(find.text('home'), findsNothing); // continua na tela

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Valor fora da faixa e casa decimal a mais: erro no campo, nada gravado',
      (tester) async {
    final repo = _RepoFake();
    await _abrir(tester, repo, const RegistrarMedidasScreen());

    await tester.enterText(_campo('Peso'), '20');
    await tester.enterText(_campo('Cintura'), '83,25');
    await tester.enterText(_campo('Peito'), '300');
    await tester.tap(find.text('Salvar medidas'));
    await tester.pumpAndSettle();

    expect(find.text('Use um valor entre 30 e 300 kg.'), findsOneWidget);
    expect(find.text('Use no máximo uma casa decimal.'), findsOneWidget);
    expect(find.text('Use um valor entre 5 e 250 cm.'), findsOneWidget);
    expect(repo.salvos, isEmpty);

    // Corrigir o campo limpa o erro dele.
    await tester.enterText(_campo('Peso'), '78');
    await tester.pump();
    expect(find.text('Use um valor entre 30 e 300 kg.'), findsNothing);
  });

  testWidgets('PBI-97: dia da medição aceita digitar sem barras e recusa o futuro', (tester) async {
    reiniciarSeletorDeData();
    final repo = _RepoFake();
    await _abrir(tester, repo, const RegistrarMedidasScreen());

    // Abre no calendário; o botão leva à digitação.
    await tester.tap(find.text('09/11/2026'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.tap(find.byTooltip('Digitar a data'));
    await tester.pumpAndSettle();
    final digitar =
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

    // Amanhã: recusado e o seletor segue aberto.
    await tester.enterText(digitar, '10112026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Use uma data entre'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    // Um dia que passou: aceito, sem digitar barra.
    await tester.enterText(digitar, '05112026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('05/11/2026'), findsOneWidget);

    await tester.enterText(_campo('Cintura'), '83');
    await tester.tap(find.text('Salvar medidas'));
    await tester.pumpAndSettle();
    expect(repo.salvos.single.$1, DateTime(2026, 11, 5));

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Registrar não deixa escolher dia futuro (limite é hoje)', (tester) async {    await _abrir(tester, _RepoFake(), const RegistrarMedidasScreen());

    await tester.tap(find.text('09/11/2026'));
    await tester.pumpAndSettle();

    // O seletor abre com hoje e o dia seguinte não pode ser escolhido.
    final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(picker.lastDate, _hoje);
    expect(picker.initialDate, _hoje);
  });

  // ---- Edição pelo histórico ----

  testWidgets('Abrir um dia: vem preenchido; editar e esvaziar muda o dia',
      (tester) async {
    final repo = _RepoFake()
      ..dias[_dia] = {TipoMedida.cintura: 84.0, TipoMedida.peito: 100.0};
    await _abrir(tester, repo, RegistrarMedidasScreen(dia: _dia));

    expect(find.text('Editar medidas'), findsOneWidget);
    expect(_texto(tester, 'Cintura'), '84,0');
    expect(_texto(tester, 'Peito'), '100,0');
    expect(find.text('05/11/2026'), findsOneWidget);

    await tester.enterText(_campo('Cintura'), '83');
    await tester.enterText(_campo('Peito'), ''); // esvaziar remove só o peito
    await tester.tap(find.text('Salvar medidas'));
    await tester.pumpAndSettle();

    final (data, valores) = repo.salvos.single;
    expect(data, _dia);
    expect(valores, {TipoMedida.cintura: 83.0, TipoMedida.peito: null});
    expect(repo.dias[_dia], {TipoMedida.cintura: 83.0});

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Esvaziar todos os campos de um dia não grava (use Excluir medição)',
      (tester) async {
    final repo = _RepoFake()..dias[_dia] = {TipoMedida.cintura: 84.0};
    await _abrir(tester, repo, RegistrarMedidasScreen(dia: _dia));

    await tester.enterText(_campo('Cintura'), '');
    await tester.tap(find.text('Salvar medidas'));
    await tester.pump();

    expect(find.text('Preencha ao menos uma medida'), findsOneWidget);
    expect(repo.salvos, isEmpty);

    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Excluir medição pede confirmação e apaga o dia', (tester) async {
    final repo = _RepoFake()..dias[_dia] = {TipoMedida.cintura: 84.0};
    await _abrir(tester, repo, RegistrarMedidasScreen(dia: _dia));

    await tester.tap(find.widgetWithText(TextButton, 'Excluir medição'));
    await tester.pumpAndSettle();

    // Cancelar não apaga.
    expect(find.text('Excluir medição?'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar').last);
    await tester.pumpAndSettle();
    expect(repo.excluidos, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Excluir medição'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir medição'));
    await tester.pumpAndSettle();

    expect(repo.excluidos, [_dia]);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Medição excluída'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Registro novo não oferece "Excluir medição"', (tester) async {
    await _abrir(tester, _RepoFake(), const RegistrarMedidasScreen());
    expect(find.text('Excluir medição'), findsNothing);
  });

  testWidgets('Dia que não carrega mostra erro com "Tentar de novo"', (tester) async {
    final repo = _RepoQueFalhaNoDia()..dias[_dia] = {TipoMedida.cintura: 84.0};
    await _abrir(tester, repo, RegistrarMedidasScreen(dia: _dia));

    expect(find.text('Não foi possível carregar essa medição.'), findsOneWidget);

    repo.falhar = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(_texto(tester, 'Cintura'), '84,0');
  });

  // ---- Acessibilidade e tema ----

  for (final escuro in [false, true]) {
    testWidgets(
        'Funciona em 360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'})',
        (tester) async {
      final repo = _RepoComResumo(_resumoExemplo());
      _telaDeCelular(tester);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const MedidasCorporaisScreen()),
      ]);
      await tester.pumpWidget(await _escopo(
        repo,
        MaterialApp.router(
          theme: escuro ? AppTheme.escuro : AppTheme.claro,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // sem overflow
      expect(find.text('Cintura'), findsOneWidget);
    });
  }

  // ---- Invalidação (Mudanca.medidas) ----

  test('Salvar e excluir atualizam o resumo sem F5 (Mudanca.medidas)', () async {
    final repo = _RepoFake();
    final c = ProviderContainer(overrides: [
      medidasRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    c.listen(resumoMedidasProvider, (_, __) {}); // mantém vivo (autoDispose)

    expect((await c.read(resumoMedidasProvider.future)).vazio, isTrue);

    await c.read(medidasComandosProvider).salvar(_dia, {TipoMedida.cintura: 84.0});
    final depoisDeSalvar = await c.read(resumoMedidasProvider.future);
    expect(depoisDeSalvar.ultimaDe(TipoMedida.cintura)!.valor, 84.0);
    expect(depoisDeSalvar.historico, hasLength(1));

    await c.read(medidasComandosProvider).excluir(_dia);
    expect((await c.read(resumoMedidasProvider.future)).vazio, isTrue);
  });

  test('O dia aberto para edição também é atualizado ao salvar', () async {
    final repo = _RepoFake()..dias[_dia] = {TipoMedida.cintura: 84.0};
    final c = ProviderContainer(overrides: [
      medidasRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    c.listen(diaMedidasProvider(_dia), (_, __) {});

    expect((await c.read(diaMedidasProvider(_dia).future)).valores[TipoMedida.cintura], 84.0);

    await c.read(medidasComandosProvider).salvar(_dia, {TipoMedida.cintura: 83.0});
    expect((await c.read(diaMedidasProvider(_dia).future)).valores[TipoMedida.cintura], 83.0);
  });

  test('Mesmo quando a escrita falha, os derivados são invalidados (finally)', () async {
    final repo = _RepoQueFalhaAoSalvar();
    final c = ProviderContainer(overrides: [
      medidasRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    c.listen(resumoMedidasProvider, (_, __) {});
    await c.read(resumoMedidasProvider.future);
    final antes = repo.leituras;

    await expectLater(
      c.read(medidasComandosProvider).salvar(_dia, {TipoMedida.peso: 78.0}),
      throwsA(isA<MedidasException>()),
    );
    await c.read(resumoMedidasProvider.future);
    expect(repo.leituras, greaterThan(antes));
  });
}

class _RepoQueFalhaNoDia extends _RepoFake {
  bool falhar = true;

  @override
  Future<DiaMedidas> obterDia(DateTime data) async {
    if (falhar) throw Exception('rede');
    return super.obterDia(data);
  }
}

class _RepoQueFalhaAoSalvar extends _RepoFake {
  int leituras = 0;

  @override
  Future<ResumoMedidas> obterResumo() async {
    leituras++;
    return super.obterResumo();
  }

  @override
  Future<void> salvarMedidas(DateTime data, Map<TipoMedida, double?> valores) async =>
      throw const MedidasException('Sem conexão.');
}
