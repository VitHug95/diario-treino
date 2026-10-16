import 'package:dio/dio.dart';
import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/resumo_treino_screen.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('PBI-63: com dados, salvar salva direto, sem diálogo', (tester) async {
    final repo = _RepoSessao();
    final c = await _comTreino(repo, [_serie(feita: true)]);
    await _abrirResumo(tester, c);

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar treino vazio?'), findsNothing);
    expect(repo.salvou, isTrue);
    expect(find.text('Treino registrado'), findsOneWidget);
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

  testWidgets('PBI-63: "Salvar mesmo assim" salva sem dados e abre "Treino registrado"',
      (tester) async {
    final repo = _RepoSessao();
    final c = await _comTreino(repo, [_serie(feita: false)]);
    await _abrirResumo(tester, c);

    await tester.tap(find.text('SALVAR TREINO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar mesmo assim'));
    await tester.pumpAndSettle();

    expect(repo.salvou, isTrue);
    expect(find.text('Treino registrado'), findsOneWidget);
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

/// Abre o Resumo empilhado sobre uma tela que mostra o que ele devolveu.
Future<void> _abrirResumo(WidgetTester tester, ProviderContainer c) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: AppTheme.claro, home: const _Abridor()),
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
            Text('Resultado: $_resultado'),
            TextButton(
              onPressed: () async {
                final r = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ResumoTreinoScreen()),
                );
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

  @override
  Future<String> criarSessao({
    required String? treinoId,
    required DateTime data,
    int? duracaoMin,
    String? observacao,
    required List<ExercicioEdicao> exercicios,
  }) async {
    salvou = true;
    return 's1';
  }
}
