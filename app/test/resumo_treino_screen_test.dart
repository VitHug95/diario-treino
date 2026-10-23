import 'package:dio/dio.dart';
import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/manter_na_ficha.dart';
import 'package:diario_treino/features/sessao/resumo_treino_screen.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RelogioFixo implements Relogio {
  _RelogioFixo(this.valor);
  final DateTime valor;
  @override
  DateTime agora() => valor;
}

SerieEdicao _serie({required bool feita, String carga = '30', String reps = '10'}) =>
    SerieEdicao(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      intensidadeTexto: carga,
      volumeMetricaId: 10,
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      volumeTexto: reps,
      descansoTexto: '',
      feita: feita,
    );

ExercicioEdicao _ex(String nome, List<SerieEdicao> series) => ExercicioEdicao(
      treinoExercicioId: 'te-$nome',
      exercicioId: 'ex-$nome',
      nome: nome,
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: series.any((s) => s.feita),
      series: series,
    );

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15, 20, 0))),
  ]);
}

void main() {
  testWidgets('status por exercício e volume total (TV-6)', (tester) async {
    final c = await _container();
    c.read(treinoAoVivoControllerProvider.notifier).iniciar(
      treinoId: 'A',
      treinoNome: 'Treino A',
      treinoLivre: false,
      data: DateTime(2026, 10, 15),
      inicio: DateTime(2026, 10, 15, 19, 0),
      exercicios: [
        // Completo: 2 séries feitas (2×30×10 = 600).
        _ex('Supino', [_serie(feita: true), _serie(feita: true)]),
        // Incompleto: 1 de 2 (mais 30×10 = 300 → volume 900 no total).
        _ex('Remada', [_serie(feita: true), _serie(feita: false)]),
        // Não realizado: nenhuma feita.
        _ex('Agachamento', [_serie(feita: false)]),
      ],
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.claro, home: const ResumoTreinoScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Treino A'), findsOneWidget);
    expect(find.text('Completo'), findsOneWidget);
    expect(find.text('Incompleto 1/2'), findsOneWidget);
    // Volume: 600 (Supino) + 300 (Remada feita) = 900 kg.
    expect(find.text('900 kg'), findsOneWidget);
    // Ações da tela.
    expect(find.text('SALVAR TREINO'), findsOneWidget);
    expect(find.text('Voltar ao treino'), findsOneWidget);

    // Agachamento fica abaixo da dobra: rola até ele aparecer.
    await tester.scrollUntilVisible(find.text('Não realizado'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Não realizado'), findsOneWidget);

    c.dispose();
  });

  testWidgets('PBI-64: com dados, salvar vai à Início com o aviso, sem diálogo', (tester) async {
    final repo = _RepoSessao();
    final c = await _comTreino(repo, [_serie(feita: true)]);
    await _abrirResumo(tester, c);

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar treino vazio?'), findsNothing);
    expect(repo.salvou, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tela inicial'), findsOneWidget);
    expect(find.text('Treino salvo'), findsOneWidget);

    // PBI-75: o aviso é um pop sem ação — não há "Ver treino", e ficamos na
    // Início (não abre o detalhe da sessão).
    expect(find.text('Ver treino'), findsNothing);
    expect(find.text('Detalhe s1'), findsNothing);
    c.dispose();
  });

  testWidgets('PBI-63: vazio pergunta; "Voltar ao resumo" não salva', (tester) async {
    final repo = _RepoSessao();
    final c = await _comTreino(repo, [_serie(feita: false)]);
    await _abrirResumo(tester, c);

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar treino vazio?'), findsOneWidget);
    expect(find.text('Você irá salvar sem inserir nenhum dado, tem certeza?'), findsOneWidget);
    expect(find.text('Salvar mesmo assim'), findsOneWidget);
    expect(find.text('Descartar treino'), findsOneWidget);

    await tester.tap(find.text('Voltar ao resumo'));
    await tester.pumpAndSettle();
    expect(find.text('SALVAR TREINO'), findsOneWidget);
    expect(repo.salvou, isFalse);
    expect(c.read(treinoAoVivoControllerProvider), isNotNull);
    c.dispose();
  });

  testWidgets('PBI-63: "Salvar mesmo assim" salva sem dados e vai à Início com o aviso',
      (tester) async {
    final repo = _RepoSessao();
    final c = await _comTreino(repo, [_serie(feita: false)]);
    await _abrirResumo(tester, c);

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar mesmo assim'));
    await tester.pumpAndSettle();

    expect(repo.salvou, isTrue);
    expect(find.text('Treino salvo'), findsOneWidget);
    expect(c.read(treinoAoVivoControllerProvider), isNull);
    c.dispose();
  });

  testWidgets('PBI-63: descartar no diálogo confirma e fecha o Resumo sem sessão',
      (tester) async {
    final repo = _RepoSessao();
    final c = await _comTreino(repo, [_serie(feita: false)]);
    await _abrirResumo(tester, c);

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar treino'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar treino?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar treino'));
    await tester.pumpAndSettle();

    // O Resumo devolveu "descartou" para a tela do treino sair também.
    expect(find.text('Resultado: true'), findsOneWidget);
    expect(repo.salvou, isFalse);
    expect(c.read(treinoAoVivoControllerProvider), isNull);
    c.dispose();
  });

  _testesManterNaFicha();
}

/// Container com um treino ao vivo de um exercício com as [series].
Future<ProviderContainer> _comTreino(_RepoSessao repo, List<SerieEdicao> series) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15, 20, 0))),
    sessaoRepositoryProvider.overrideWithValue(repo),
  ]);
  c.read(treinoAoVivoControllerProvider.notifier).iniciar(
        treinoId: 'A',
        treinoNome: 'Treino A',
        treinoLivre: false,
        data: DateTime(2026, 10, 15),
        inicio: DateTime(2026, 10, 15, 19, 0),
        exercicios: [_ex('Supino', series)],
      );
  return c;
}

/// Abre o Resumo empilhado sobre a "Início" (que mostra o que ele devolveu),
/// com rotas de verdade: salvar faz go para a Início (PBI-64).
Future<void> _abrirResumo(WidgetTester tester, ProviderContainer c) async {
  final router = GoRouter(routes: [
    GoRoute(path: Rotas.inicio, builder: (_, __) => const _Abridor()),
    GoRoute(path: Rotas.resumoTreino, builder: (_, __) => const ResumoTreinoScreen()),
    GoRoute(
      path: Rotas.detalheSessao,
      builder: (_, s) =>
          Scaffold(body: Text('Detalhe ${(s.extra! as DetalheSessaoArgs).sessaoId}')),
    ),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

class _Abridor extends StatefulWidget {
  const _Abridor();

  @override
  State<_Abridor> createState() => _AbridorState();
}

class _AbridorState extends State<_Abridor> {
  String _resultado = 'nada';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            const Text('Tela inicial'),
            Text('Resultado: $_resultado'),
            TextButton(
              onPressed: () async {
                final r = await context.push<bool>(Rotas.resumoTreino);
                setState(() => _resultado = '$r');
              },
              child: const Text('Abrir'),
            ),
          ],
        ),
      );
}

/// Repositório que só registra que a sessão foi gravada.
class _RepoSessao extends SessaoRepository {
  _RepoSessao() : super(Dio());

  bool salvou = false;
  List<String>? mantidos;
  List<ExercicioEdicao>? salvas;

  @override
  Future<String> criarSessao({
    required String? treinoId,
    required DateTime data,
    int? duracaoMin,
    String? observacao,
    required List<ExercicioEdicao> exercicios,
    List<String> manterNaFicha = const [],
  }) async {
    salvou = true;
    mantidos = manterNaFicha;
    salvas = exercicios;
    return 's1';
  }
}

// ---------- PBI-72: "Manter na ficha?" ----------

/// Tríceps coice adicionado fora da ficha, com [feitas] séries feitas de 20 × 10.
ExercicioEdicao _coice({int feitas = 2}) => ExercicioEdicao(
      treinoExercicioId: null,
      exercicioId: 'ex-Coice',
      nome: 'Tríceps coice',
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: feitas > 0,
      foraDaFicha: true,
      series: [
        for (var i = 0; i < 2; i++) _serie(feita: i < feitas, carga: '20', reps: '10'),
      ],
    );

/// Treino ao vivo da ficha "A" com o supino (da ficha) e o [extra]. A ficha
/// lida pelo diálogo vem do override (sem rede).
Future<ProviderContainer> _comForaDaFicha(
  _RepoSessao repo,
  ExercicioEdicao extra, {
  bool somenteLeitura = false,
  bool treinoLivre = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15, 20, 0))),
    sessaoRepositoryProvider.overrideWithValue(repo),
    fichaDetalheProvider.overrideWith((ref, id) async => TreinoDetalhe(
          id: id,
          nome: 'Treino B',
          descricao: null,
          ordem: 1,
          exercicios: const [],
          somenteLeitura: somenteLeitura,
        )),
  ]);
  c.read(treinoAoVivoControllerProvider.notifier).iniciar(
        treinoId: treinoLivre ? null : 'B',
        treinoNome: treinoLivre ? 'Treino livre' : 'Treino B',
        treinoLivre: treinoLivre,
        data: DateTime(2026, 10, 15),
        inicio: DateTime(2026, 10, 15, 19, 0),
        exercicios: [_ex('Supino', [_serie(feita: true)]), extra],
      );
  return c;
}

void _testesManterNaFicha() {
  group('PBI-72: "Manter na ficha?"', () {
    testWidgets('etiqueta "Fora da ficha" no Resumo', (tester) async {
      final c = await _comForaDaFicha(_RepoSessao(), _coice());
      await _abrirResumo(tester, c);

      expect(find.text('FORA DA FICHA'), findsOneWidget);
      c.dispose();
    });

    testWidgets('pergunta com o nome e o alvo; "Manter na ficha" envia o id',
        (tester) async {
      final repo = _RepoSessao();
      final c = await _comForaDaFicha(repo, _coice());
      await _abrirResumo(tester, c);

      await tester.tap(find.text('SALVAR TREINO'));
      await tester.pumpAndSettle();
      expect(find.text('Manter na ficha?'), findsOneWidget);
      // Dentro do diálogo (o Resumo atrás também mostra o nome).
      Finder noDialogo(String s) => find.descendant(
          of: find.byType(AlertDialog), matching: find.textContaining(s, findRichText: true));
      expect(noDialogo('Tríceps coice'), findsOneWidget);
      expect(noDialogo('2 séries de 20 × 10'), findsOneWidget);
      expect(find.text('Só neste treino'), findsOneWidget);
      expect(find.text('Voltar ao resumo'), findsOneWidget);

      await tester.tap(find.text('MANTER NA FICHA'));
      await tester.pumpAndSettle();
      expect(repo.salvou, isTrue);
      expect(repo.mantidos, ['ex-Coice']);
      expect(find.text('Treino salvo'), findsOneWidget);
      c.dispose();
    });

    testWidgets('"Só neste treino" salva e não mexe na ficha', (tester) async {
      final repo = _RepoSessao();
      final c = await _comForaDaFicha(repo, _coice());
      await _abrirResumo(tester, c);

      await tester.tap(find.text('SALVAR TREINO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Só neste treino'));
      await tester.pumpAndSettle();

      expect(repo.salvou, isTrue);
      expect(repo.mantidos, isEmpty);
      c.dispose();
    });

    testWidgets('"Voltar ao resumo" não salva nada', (tester) async {
      final repo = _RepoSessao();
      final c = await _comForaDaFicha(repo, _coice());
      await _abrirResumo(tester, c);

      await tester.tap(find.text('SALVAR TREINO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar ao resumo'));
      await tester.pumpAndSettle();

      expect(repo.salvou, isFalse);
      expect(find.text('SALVAR TREINO'), findsOneWidget);
      expect(c.read(treinoAoVivoControllerProvider), isNotNull);
      c.dispose();
    });

    for (final (caso, extra, professor, livre) in [
      ('sem série marcada', _coice(feitas: 0), false, false),
      ('ficha do professor', _coice(), true, false),
      ('treino livre', _coice(), false, true),
    ]) {
      testWidgets('não pergunta: $caso', (tester) async {
        final repo = _RepoSessao();
        final c = await _comForaDaFicha(repo, extra,
            somenteLeitura: professor, treinoLivre: livre);
        await _abrirResumo(tester, c);

        await tester.tap(find.text('SALVAR TREINO'));
        await tester.pumpAndSettle();

        expect(find.text('Manter na ficha?'), findsNothing);
        expect(repo.salvou, isTrue);
        expect(repo.mantidos, isEmpty);
        c.dispose();
      });
    }

    testWidgets('diálogo no tema escuro, com alvos de toque', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.escuro,
        home: Scaffold(
          body: DialogoManterNaFicha(treinoNome: 'Treino B', exercicios: [_coice()]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Manter na ficha?'), findsOneWidget);
      final manter = find.ancestor(
          of: find.text('MANTER NA FICHA'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(tester.getSize(manter).height, greaterThanOrEqualTo(44));
    });

    test('resumoParaFicha: carga × reps, só reps e tempo', () {
      expect(resumoParaFicha(_coice()), '2 séries de 20 × 10');
      final uma = _coice()..series.removeLast();
      expect(resumoParaFicha(uma), '1 série de 20 × 10');
    });
  });
}
