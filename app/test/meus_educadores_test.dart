import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/features/educador/aluno_detalhe_screen.dart';
import 'package:diario_treino/features/educador/alunos_screen.dart';
import 'package:diario_treino/features/educador/convites_screen.dart';
import 'package:diario_treino/features/educador/educador_models.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/educador/meus_educadores_screen.dart';
import 'package:diario_treino/shared/formato_data.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// PBI-104: "Meus educadores" (quem acompanha o atleta) e encerrar o vínculo,
/// pelo atleta e pelo educador ("Meus alunos").

/// "Servidor" dos vínculos em memória: convites pendentes e vínculos ativos.
class _RepoVinculos extends EducadorRepository {
  _RepoVinculos({List<EducadorVinculado>? ativos, List<ConvitePendente>? pendentes, this.encerrarDa409 = false})
      : ativos = ativos ?? [],
        pendentes = pendentes ?? [],
        super(Dio());

  final List<EducadorVinculado> ativos;
  final List<ConvitePendente> pendentes;
  final bool encerrarDa409;
  final encerrados = <String>[];

  @override
  Future<List<EducadorVinculado>> listarEducadores() async => List.of(ativos);

  @override
  Future<List<ConvitePendente>> listarConvitesPendentes() async => List.of(pendentes);

  @override
  Future<void> aceitar(String vinculoId) async {
    final c = pendentes.firstWhere((p) => p.vinculoId == vinculoId);
    pendentes.remove(c);
    ativos.insert(
        0,
        EducadorVinculado(
            vinculoId: c.vinculoId,
            educadorId: c.educadorId,
            educadorNome: c.educadorNome,
            educadorEmail: c.educadorEmail,
            desde: DateTime(2026, 11, 25)));
  }

  @override
  Future<void> encerrar(String vinculoId) async {
    // 409: outro aparelho já encerrou; o vínculo some da lista mesmo assim.
    ativos.removeWhere((e) => e.vinculoId == vinculoId);
    if (encerrarDa409) throw const EducadorException('Este vínculo já não está ativo');
    encerrados.add(vinculoId);
  }
}

final _ana = EducadorVinculado(
  vinculoId: 'v1',
  educadorId: 'e1',
  educadorNome: 'Prof. Ana',
  educadorEmail: 'ana@x.dev',
  desde: DateTime(2026, 10, 12),
);
final _bia = EducadorVinculado(
  vinculoId: 'v2',
  educadorId: 'e2',
  educadorNome: 'Prof. Bia',
  educadorEmail: 'bia@x.dev',
  desde: DateTime(2026, 9, 1),
);

Future<GoRouter> _abrir(WidgetTester tester, _RepoVinculos repo,
    {bool escuro = false, double largura = 400}) async {
  tester.view.physicalSize = Size(largura, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Rotas.meusEducadores,
    routes: [
      GoRoute(path: Rotas.meusEducadores, builder: (_, __) => const MeusEducadoresScreen()),
      GoRoute(path: Rotas.convites, builder: (_, __) => const ConvitesScreen()),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [educadorRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('lista um educador com nome, e-mail, desde e Encerrar', (tester) async {
    await _abrir(tester, _RepoVinculos(ativos: [_ana]));

    expect(find.text('Prof. Ana'), findsOneWidget);
    expect(find.text('ana@x.dev'), findsOneWidget);
    expect(find.text('Acompanha você desde 12/10/2026'), findsOneWidget);
    expect(find.text('Encerrar'), findsOneWidget);
    expect(find.textContaining('Educadores só veem o que você libera.'), findsOneWidget);
  });

  testWidgets('lista dois educadores, cada um com o seu Encerrar', (tester) async {
    await _abrir(tester, _RepoVinculos(ativos: [_ana, _bia]));

    expect(find.text('Prof. Ana'), findsOneWidget);
    expect(find.text('Prof. Bia'), findsOneWidget);
    expect(find.text('Encerrar'), findsNWidgets(2));
  });

  testWidgets('vazio: mensagem e "Ver convites" leva aos convites', (tester) async {
    await _abrir(tester, _RepoVinculos());

    expect(find.text('Ninguém acompanha você agora'), findsOneWidget);
    expect(find.text('Quando você aceitar o convite de um educador, ele aparece aqui.'),
        findsOneWidget);
    expect(find.textContaining('Educadores só veem o que você libera.'), findsOneWidget);

    await tester.tap(find.text('Ver convites'));
    await tester.pumpAndSettle();
    expect(find.byType(ConvitesScreen), findsOneWidget);
  });

  testWidgets('encerrar pede confirmação com o nome; confirmar tira da lista', (tester) async {
    final repo = _RepoVinculos(ativos: [_ana, _bia]);
    await _abrir(tester, repo);

    await tester.tap(find.text('Encerrar').first);
    await tester.pumpAndSettle();
    expect(find.text('Encerrar acompanhamento?'), findsOneWidget);
    expect(
        find.text('Prof. Ana deixa de ver seus treinos e sua evolução agora. Seus dados '
            'continuam com você. Para voltar a ser acompanhado, o educador precisa '
            'convidar você de novo.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
    await tester.pumpAndSettle();

    expect(repo.encerrados, ['v1']);
    expect(find.text('Acompanhamento encerrado'), findsOneWidget);
    expect(find.text('Prof. Ana'), findsNothing);
    expect(find.text('Prof. Bia'), findsOneWidget);
  });

  testWidgets('cancelar não encerra nada', (tester) async {
    final repo = _RepoVinculos(ativos: [_ana]);
    await _abrir(tester, repo);

    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.encerrados, isEmpty);
    expect(find.text('Prof. Ana'), findsOneWidget);
  });

  testWidgets('409: avisa que já não está ativo e recarrega a lista', (tester) async {
    await _abrir(tester, _RepoVinculos(ativos: [_ana], encerrarDa409: true));

    await tester.tap(find.text('Encerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Este vínculo já não está ativo'), findsOneWidget);
    expect(find.text('Ninguém acompanha você agora'), findsOneWidget);
  });

  testWidgets('aceitar convite: aviso com o nome e o educador aparece sem recarregar',
      (tester) async {
    final repo = _RepoVinculos(pendentes: [
      const ConvitePendente(
          vinculoId: 'v9', educadorId: 'e9', educadorNome: 'Prof. Caio', educadorEmail: 'caio@x.dev'),
    ]);
    final router = await _abrir(tester, repo);
    expect(find.text('Ninguém acompanha você agora'), findsOneWidget);

    // A lista continua viva por baixo dos convites.
    router.push(Rotas.convites);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ACEITAR E ATIVAR'));
    await tester.pumpAndSettle();
    expect(find.text('Agora Prof. Caio acompanha você'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Prof. Caio'), findsOneWidget);
    expect(find.text('Acompanha você desde 25/11/2026'), findsOneWidget);
  });

  testWidgets('rótulo falado do cartão e do botão', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, _RepoVinculos(ativos: [_ana]));

    expect(find.bySemanticsLabel('Educador Prof. Ana, acompanha você desde 12 de outubro de 2026'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Encerrar acompanhamento de Prof. Ana'), findsOneWidget);
    semantica.dispose();
  });

  test('subtítulo da linha do Perfil e data por extenso', () {
    expect(resumoMeusEducadores(const []), 'Ninguém acompanha você agora');
    expect(resumoMeusEducadores([_ana]), '1 educador');
    expect(resumoMeusEducadores([_ana, _bia]), '2 educadores');
    expect(formatarDataPorExtenso(DateTime(2026, 3, 5)), '5 de março de 2026');
  });

  for (final escuro in [false, true]) {
    testWidgets('360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'}), com o diálogo',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _abrir(
          tester,
          _RepoVinculos(ativos: [
            EducadorVinculado(
                vinculoId: 'v1',
                educadorId: 'e1',
                educadorNome: 'Professora Maria Aparecida dos Santos',
                educadorEmail: 'maria.aparecida.dos.santos@academia.exemplo.dev',
                desde: DateTime(2026, 10, 12)),
          ]),
          escuro: escuro,
          largura: 360);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Encerrar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Professora Maria Aparecida dos Santos deixa de ver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // ---- O educador encerra pelo "Meus alunos" ----

  group('educador encerra em Meus alunos', () {
    for (final escuro in [false, true]) {
      testWidgets('360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'})', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _abrirAlunos(tester, _RepoAlunos(), escuro: escuro, largura: 360);
        expect(find.text('Encerrar'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('confirmar tira o aluno da lista e avisa', (tester) async {
      final repo = _RepoAlunos();
      await _abrirAlunos(tester, repo);

      await tester.tap(find.text('Encerrar').first);
      await tester.pumpAndSettle();
      expect(find.text('Encerrar acompanhamento?'), findsOneWidget);
      expect(find.textContaining('Você deixa de ver os treinos e a evolução de João agora.'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pumpAndSettle();

      expect(repo.encerrados, ['v1']);
      expect(find.text('Acompanhamento encerrado'), findsOneWidget);
      expect(find.text('João'), findsNothing);
      expect(find.text('Maria'), findsOneWidget);
    });

    testWidgets('cancelar não encerra', (tester) async {
      final repo = _RepoAlunos();
      await _abrirAlunos(tester, repo);

      await tester.tap(find.text('Encerrar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.encerrados, isEmpty);
      expect(find.text('João'), findsOneWidget);
    });

    testWidgets('409: o aluno já encerrou', (tester) async {
      await _abrirAlunos(tester, _RepoAlunos(encerrarDa409: true));

      await tester.tap(find.text('Encerrar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pumpAndSettle();

      expect(find.text('Este vínculo já não está ativo'), findsOneWidget);
      expect(find.text('João'), findsNothing);
    });

    testWidgets('o cartão continua abrindo o aluno; rótulos falados separados', (tester) async {
      final semantica = tester.ensureSemantics();
      await _abrirAlunos(tester, _RepoAlunos());

      expect(find.bySemanticsLabel('Abrir aluno João'), findsOneWidget);
      expect(find.bySemanticsLabel('Encerrar acompanhamento de João'), findsOneWidget);

      await tester.tap(find.text('João'));
      await tester.pumpAndSettle();
      expect(find.text('detalhe de João'), findsOneWidget);
      semantica.dispose();
    });
  });
}

/// "Servidor" dos alunos do educador.
class _RepoAlunos extends EducadorRepository {
  _RepoAlunos({this.encerrarDa409 = false}) : super(Dio());

  final bool encerrarDa409;
  final encerrados = <String>[];
  final alunos = [
    const AlunoVinculado(vinculoId: 'v1', alunoId: 'a1', alunoNome: 'João', alunoEmail: 'joao@x.dev'),
    const AlunoVinculado(vinculoId: 'v2', alunoId: 'a2', alunoNome: 'Maria', alunoEmail: 'maria@x.dev'),
  ];

  @override
  Future<List<AlunoVinculado>> listarAlunos() async => List.of(alunos);

  @override
  Future<void> encerrar(String vinculoId) async {
    alunos.removeWhere((a) => a.vinculoId == vinculoId);
    if (encerrarDa409) throw const EducadorException('Este vínculo já não está ativo');
    encerrados.add(vinculoId);
  }
}

Future<void> _abrirAlunos(WidgetTester tester, _RepoAlunos repo,
    {bool escuro = false, double largura = 400}) async {
  tester.view.physicalSize = Size(largura, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Rotas.alunos,
    routes: [
      GoRoute(path: Rotas.alunos, builder: (_, __) => const AlunosScreen()),
      GoRoute(
        path: Rotas.alunoDetalhe,
        builder: (_, s) => Scaffold(body: Text('detalhe de ${(s.extra! as AlunoDetalheArgs).alunoNome}')),
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [educadorRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: escuro ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}
