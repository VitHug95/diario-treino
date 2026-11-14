import 'package:diario_treino/core/localizacao/material_pt.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/features/educador/aluno_corpo_screen.dart';
import 'package:diario_treino/features/educador/corpo_do_aluno.dart';
import 'package:diario_treino/features/medidas/compartilhamento_repository.dart';
import 'package:diario_treino/features/medidas/compartilhar_corpo_screen.dart';
import 'package:diario_treino/features/medidas/medida_evolucao_screen.dart';
import 'package:diario_treino/features/medidas/medidas_models.dart';
import 'package:diario_treino/features/medidas/perfil_corporal_models.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// PBI-96: os cadeados do corpo (atleta) e o corpo do aluno (educador).

/// "Servidor" dos cadeados em memória.
class _RepoCadeados extends CompartilhamentoRepository {
  _RepoCadeados({this.dados = false, this.medidas = false, this.educadores = const ['Prof. Ana']})
      : super(Dio());

  bool dados;
  bool medidas;
  final List<String> educadores;
  final chamadas = <String>[];

  CompartilhamentoCorporal get _atual =>
      CompartilhamentoCorporal(dadosCorporais: dados, medidas: medidas, educadores: educadores);

  @override
  Future<CompartilhamentoCorporal> obter() async => _atual;

  @override
  Future<CompartilhamentoCorporal> definirCompartilhamentoCorporal({
    required bool dadosCorporais,
    required bool medidas,
  }) async {
    chamadas.add('$dadosCorporais/$medidas');
    dados = dadosCorporais;
    this.medidas = medidas;
    return _atual;
  }
}

class _RepoCorpo extends CorpoDoAlunoRepository {
  _RepoCorpo(this.corpo, {this.evolucaoTrancada = false}) : super(Dio());

  final CorpoDoAluno corpo;
  final bool evolucaoTrancada;

  @override
  Future<CorpoDoAluno> obter(String atletaId) async => corpo;

  @override
  Future<EvolucaoMedida> obterEvolucao(String atletaId, TipoMedida tipo, {DateTime? de}) async {
    if (evolucaoTrancada) throw const CorpoTrancadoException();
    return EvolucaoMedida.doJson({
      'tipo': tipo.codigo,
      'unidade': tipo.unidade,
      'pontos': [
        {'data': '2026-10-01', 'valor': 87.0},
        {'data': '2026-11-05', 'valor': 84.0},
      ],
      'primeira': {'data': '2026-10-01', 'valor': 87.0},
      'ultima': {'data': '2026-11-05', 'valor': 84.0},
      'variacao': -3.0,
    }, tipo);
  }
}

const _dados = PerfilCorporal(
  sexo: SexoBiologico.masculino,
  alturaCm: 180,
  pesoKg: 78.0,
  idade: 31,
  tmbKcal: 1800,
  tmbCalculadaKcal: 1755,
  tmbManual: true,
);

final _medidas = ResumoMedidas(
  ultimas: [UltimaMedida(tipo: TipoMedida.cintura, valor: 84.0, data: DateTime(2026, 11, 5), variacao: -3.0)],
  historico: [DiaHistoricoMedidas(data: DateTime(2026, 11, 5), quantidade: 1)],
);

void _tela(WidgetTester tester, {double largura = 400}) {
  tester.view.physicalSize = Size(largura, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrirCompartilhar(WidgetTester tester, _RepoCadeados repo) async {
  _tela(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [compartilhamentoRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.claro,
      localizationsDelegates: LocalizacoesPt.delegates,
      home: const CompartilharCorpoScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// O corpo do aluno com o go_router de verdade (para abrir a evolução).
Future<void> _abrirCorpoDoAluno(WidgetTester tester, _RepoCorpo repo,
    {bool escuro = false, double largura = 400}) async {
  _tela(tester, largura: largura);
  final router = GoRouter(
    initialLocation: Rotas.alunoCorpo,
    routes: [
      GoRoute(
        path: Rotas.alunoCorpo,
        builder: (_, __) => const AlunoCorpoScreen(atletaId: 'a1', alunoNome: 'João'),
      ),
      GoRoute(
        path: Rotas.alunoMedidaEvolucao,
        builder: (_, s) {
          final a = s.extra! as AlunoMedidaArgs;
          return MedidaEvolucaoScreen(tipo: a.tipo, atletaId: a.atletaId, alunoNome: a.alunoNome);
        },
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [corpoDoAlunoRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  // ---- O atleta: "Compartilhar com o educador" ----

  testWidgets('começa tudo privado e mostra quem veria', (tester) async {
    await _abrirCompartilhar(tester, _RepoCadeados());

    expect(find.text('Sexo, idade, altura, peso e TMB · Privado'), findsOneWidget);
    expect(find.text('Medidas, histórico e evolução · Privado'), findsOneWidget);
    expect(find.text('Prof. Ana'), findsOneWidget);
    expect(find.text('Com tudo privado, eles não veem nada do seu corpo.'), findsOneWidget);
  });

  testWidgets('destrancar pede confirmação; confirmar grava só aquele cadeado', (tester) async {
    final repo = _RepoCadeados();
    await _abrirCompartilhar(tester, repo);

    await tester.tap(find.text('Medidas corporais'));
    await tester.pumpAndSettle();
    expect(find.text('Compartilhar medidas?'), findsOneWidget);
    expect(find.textContaining('Hoje quem vê: Prof. Ana.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Compartilhar'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, ['false/true']);
    expect(find.text('Medidas compartilhadas'), findsOneWidget); // aviso
    expect(find.text('Medidas, histórico e evolução · Compartilhado'), findsOneWidget);
    expect(find.text('Sexo, idade, altura, peso e TMB · Privado'), findsOneWidget);
  });

  testWidgets('cancelar a confirmação não grava nada', (tester) async {
    final repo = _RepoCadeados();
    await _abrirCompartilhar(tester, repo);

    await tester.tap(find.text('Dados corporais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.chamadas, isEmpty);
    expect(find.text('Sexo, idade, altura, peso e TMB · Privado'), findsOneWidget);
  });

  testWidgets('trancar não pede confirmação', (tester) async {
    final repo = _RepoCadeados(dados: true, medidas: true);
    await _abrirCompartilhar(tester, repo);

    await tester.tap(find.text('Dados corporais'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.chamadas, ['false/true']);
    expect(find.text('Dados corporais privados'), findsOneWidget);
  });

  testWidgets('sem educador com vínculo ativo, avisa que ninguém vê', (tester) async {
    await _abrirCompartilhar(tester, _RepoCadeados(educadores: const []));

    expect(find.textContaining('Ninguém vê, mesmo o que estiver compartilhado'), findsOneWidget);
  });

  testWidgets('selo de privacidade nas telas do corpo', (tester) async {
    for (final (repo, texto) in [
      (_RepoCadeados(), 'Privado: só você vê'),
      (_RepoCadeados(medidas: true), 'Compartilhado com o educador'),
    ]) {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [compartilhamentoRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.claro,
          home: const Scaffold(body: SeloCompartilhamento(parte: ParteDoCorpo.medidas)),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(texto), findsOneWidget);
    }
  });

  test('resumo para o Perfil', () {
    CompartilhamentoCorporal c(bool d, bool m) =>
        CompartilhamentoCorporal(dadosCorporais: d, medidas: m, educadores: const []);
    expect(resumoCompartilhamento(c(false, false)), 'Tudo privado');
    expect(resumoCompartilhamento(c(true, false)), 'Dados corporais compartilhados');
    expect(resumoCompartilhamento(c(false, true)), 'Medidas compartilhadas');
    expect(resumoCompartilhamento(c(true, true)), 'Dados e medidas compartilhados');
  });

  // ---- O educador: corpo do aluno ----

  testWidgets('tudo trancado: duas seções "Privado", sem nenhum valor', (tester) async {
    await _abrirCorpoDoAluno(
        tester,
        _RepoCorpo(const CorpoDoAluno(
            dadosCorporaisCompartilhados: false,
            dadosCorporais: null,
            medidasCompartilhadas: false,
            medidas: null)));

    expect(find.text('Privado'), findsNWidgets(2));
    expect(find.text('O aluno não compartilhou os dados corporais.'), findsOneWidget);
    expect(find.text('O aluno não compartilhou as medidas.'), findsOneWidget);
    expect(find.textContaining('kg'), findsNothing);
  });

  testWidgets('dados liberados: mostra os dados e a TMB informada pelo aluno', (tester) async {
    await _abrirCorpoDoAluno(
        tester,
        _RepoCorpo(const CorpoDoAluno(
            dadosCorporaisCompartilhados: true,
            dadosCorporais: _dados,
            medidasCompartilhadas: false,
            medidas: null)));

    expect(find.text('Masculino'), findsOneWidget);
    expect(find.text('31 anos'), findsOneWidget);
    expect(find.text('180 cm'), findsOneWidget);
    expect(find.text('78 kg'), findsOneWidget);
    expect(find.text('1.800 kcal por dia'), findsOneWidget);
    expect(find.text('Informada pelo aluno'), findsOneWidget);
    expect(find.text('O aluno não compartilhou as medidas.'), findsOneWidget);
    // Só leitura: nada de editar.
    expect(find.text('Editar'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('medidas liberadas: lista e abre a evolução só leitura', (tester) async {
    await _abrirCorpoDoAluno(
        tester,
        _RepoCorpo(CorpoDoAluno(
            dadosCorporaisCompartilhados: false,
            dadosCorporais: null,
            medidasCompartilhadas: true,
            medidas: _medidas)));

    expect(find.text('84,0 cm'), findsOneWidget);
    await tester.tap(find.text('Cintura'));
    await tester.pumpAndSettle();

    expect(find.byType(MedidaEvolucaoScreen), findsOneWidget);
    expect(find.text('Cintura · João'), findsOneWidget);
    expect(find.text('REGISTROS DO PERÍODO'), findsOneWidget);
  });

  testWidgets('evolução trancada no meio do caminho mostra o cadeado', (tester) async {
    await _abrirCorpoDoAluno(
        tester,
        _RepoCorpo(
            CorpoDoAluno(
                dadosCorporaisCompartilhados: false,
                dadosCorporais: null,
                medidasCompartilhadas: true,
                medidas: _medidas),
            evolucaoTrancada: true));

    await tester.tap(find.text('Cintura'));
    await tester.pumpAndSettle();
    expect(find.text('O aluno não compartilhou as medidas.'), findsOneWidget);
  });

  for (final escuro in [false, true]) {
    testWidgets('corpo do aluno em 360 px com fonte 1,3x (${escuro ? 'escuro' : 'claro'})',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _abrirCorpoDoAluno(
          tester,
          _RepoCorpo(CorpoDoAluno(
              dadosCorporaisCompartilhados: true,
              dadosCorporais: _dados,
              medidasCompartilhadas: true,
              medidas: _medidas)),
          escuro: escuro,
          largura: 360);

      expect(find.text('Informada pelo aluno'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Compartilhar" em 360 px com fonte 1,3x (${escuro ? 'escuro' : 'claro'})',
        (tester) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(ProviderScope(
        overrides: [compartilhamentoRepositoryProvider.overrideWithValue(_RepoCadeados())],
        child: MaterialApp(
          theme: AppTheme.claro,
          darkTheme: AppTheme.escuro,
          themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
          home: const CompartilharCorpoScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Dados corporais'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rótulos falados: o cadeado do aluno e a medida', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrirCorpoDoAluno(
        tester,
        _RepoCorpo(CorpoDoAluno(
            dadosCorporaisCompartilhados: false,
            dadosCorporais: null,
            medidasCompartilhadas: true,
            medidas: _medidas)));

    expect(find.bySemanticsLabel('Privado. O aluno não compartilhou os dados corporais.'),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Cintura: 84,0 centímetros em 05/11')), findsOneWidget);
    semantica.dispose();
  });
}
