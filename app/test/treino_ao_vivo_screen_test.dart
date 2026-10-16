import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/progresso/progresso_repository.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_screen.dart';
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

SerieEdicao _serie({required bool feita}) => SerieEdicao(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      intensidadeTexto: '30',
      volumeMetricaId: 10,
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      volumeTexto: '10',
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

/// Container com um treino ao vivo em andamento com as [series] de um
/// exercício (ou os [exercicios] dados). Histórico e Evolução sem rede: falham
/// e mostram a mensagem de erro, o que basta para trocar de aba.
Future<ProviderContainer> _container(List<SerieEdicao> series,
    {List<ExercicioEdicao>? exercicios}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15, 20, 0))),
    historicoExercicioProvider.overrideWith((ref, id) => Future.error('sem rede')),
    progressoPorExercicioProvider.overrideWith((ref, id) => Future.error('sem rede')),
  ]);
  c.read(treinoAoVivoControllerProvider.notifier).iniciar(
        treinoId: 'A',
        treinoNome: 'Treino A',
        treinoLivre: false,
        data: DateTime(2026, 10, 15),
        inicio: DateTime(2026, 10, 15, 19, 0),
        exercicios: exercicios ?? [_ex('Supino', series)],
      );
  return c;
}

/// Três exercícios, para andar com as setas.
List<ExercicioEdicao> _tres() => [
      _ex('Supino', [_serie(feita: false)]),
      _ex('Remada', [_serie(feita: false)]),
      _ex('Agachamento', [_serie(feita: false)]),
    ];

/// Índice da aba selecionada na tela do exercício.
int _abaAtual(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

/// Tela 24 empilhada sobre o "plano" (que fica sobre a Início), como quando o
/// treino começa pelo play da PBI-61.
Future<void> _abrir(WidgetTester tester, ProviderContainer c) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: Rotas.inicio,
        builder: (_, __) => const Scaffold(body: Text('Tela inicial')),
      ),
      GoRoute(
        path: Rotas.planoDetalhe,
        builder: (_, __) => const Scaffold(body: Text('Tela do plano')),
      ),
      GoRoute(
        path: Rotas.treinoAoVivo,
        builder: (_, __) => const TreinoAoVivoScreen(),
      ),
      GoRoute(
        path: Rotas.exercicioAoVivo,
        builder: (_, s) => ExercicioAoVivoScreen(indice: (s.extra as int?) ?? 0),
      ),
      // Resumo de mentira: volta sem nada ou devolve "descartou" (true).
      GoRoute(
        path: Rotas.resumoTreino,
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('Resumo'),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar do resumo'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Descartou no resumo'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
  ));
  router.push(Rotas.planoDetalhe);
  await tester.pumpAndSettle();
  router.push(Rotas.treinoAoVivo);
  await tester.pumpAndSettle();
}

const _rotuloSeta = 'Voltar para a Início. O treino continua em andamento';

void main() {
  testWidgets('PBI-63: seta com rótulo; barra com Finalizar e Descartar de 48 px',
      (tester) async {
    final c = await _container([_serie(feita: false)]);
    await _abrir(tester, c);

    final seta = find.byTooltip(_rotuloSeta);
    expect(seta, findsOneWidget);
    expect(tester.getSize(seta).height, greaterThanOrEqualTo(44));
    expect(find.textContaining('Pode voltar para a Início sem perder nada'), findsOneWidget);

    final finalizar = find.text('FINALIZAR TREINO');
    final descartar = find.text('Descartar treino');
    expect(finalizar, findsOneWidget);
    expect(descartar, findsOneWidget);
    expect(tester.getSize(find.ancestor(of: finalizar, matching: find.byType(Material)).first)
        .height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.ancestor(of: descartar, matching: find.byType(Material)).first)
        .height, greaterThanOrEqualTo(48));
    c.dispose();
  });

  testWidgets('PBI-63: a seta vai à Início sem diálogo e o treino continua',
      (tester) async {
    final c = await _container([_serie(feita: true), _serie(feita: false)]);
    await _abrir(tester, c);

    await tester.tap(find.byTooltip(_rotuloSeta));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tela inicial'), findsOneWidget);
    // Nada salvo nem descartado: o treino e as séries marcadas continuam.
    final estado = c.read(treinoAoVivoControllerProvider);
    expect(estado, isNotNull);
    expect(estado!.seriesFeitas, 1);
    expect(estado.inicio, DateTime(2026, 10, 15, 19, 0));
    c.dispose();
  });

  testWidgets('PBI-66: próximo e anterior mantêm a aba; abrir pelo treino volta a Séries',
      (tester) async {
    final c = await _container(const [], exercicios: _tres());
    await _abrir(tester, c);

    // Abre o exercício 1 pela tela do treino: começa em Séries.
    await tester.tap(find.text('Supino'));
    await tester.pumpAndSettle();
    expect(_abaAtual(tester), 0);

    // Histórico, depois próximo: o exercício 2 abre ainda em Histórico.
    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Próximo exercício'));
    await tester.pumpAndSettle();
    expect(find.text('Exercício 2 de 3'), findsOneWidget);
    expect(_abaAtual(tester), 1);

    // Evolução, depois anterior: o exercício 1 abre em Evolução.
    await tester.tap(find.text('Evolução'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Exercício anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Exercício 1 de 3'), findsOneWidget);
    expect(_abaAtual(tester), 2);

    // Volta à tela do treino e abre outro exercício: nasce em Séries.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agachamento'));
    await tester.pumpAndSettle();
    expect(find.text('Exercício 3 de 3'), findsOneWidget);
    expect(_abaAtual(tester), 0);
    c.dispose();
  });

  testWidgets('PBI-63: voltar do sistema faz o mesmo que a seta', (tester) async {
    final c = await _container([_serie(feita: false)]);
    await _abrir(tester, c);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Tela inicial'), findsOneWidget);
    expect(c.read(treinoAoVivoControllerProvider), isNotNull);
    c.dispose();
  });

  for (final (caso, series) in [
    ('vazio', [_serie(feita: false)]),
    ('parcial', [_serie(feita: true), _serie(feita: false)]),
    ('completo', [_serie(feita: true)]),
  ]) {
    testWidgets('PBI-63: finalizar ($caso) vai direto ao Resumo, sem diálogo',
        (tester) async {
      final c = await _container(series);
      await _abrir(tester, c);

      await tester.tap(find.text('FINALIZAR TREINO'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Resumo'), findsOneWidget);
      c.dispose();
    });
  }

  testWidgets('PBI-63: voltar do Resumo mantém o treino como estava', (tester) async {
    final c = await _container([_serie(feita: true), _serie(feita: false)]);
    await _abrir(tester, c);

    await tester.tap(find.text('FINALIZAR TREINO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar do resumo'));
    await tester.pumpAndSettle();

    expect(find.text('FINALIZAR TREINO'), findsOneWidget);
    expect(c.read(treinoAoVivoControllerProvider)!.seriesFeitas, 1);
    c.dispose();
  });

  testWidgets('PBI-63: descartar pelo Resumo também sai do treino', (tester) async {
    final c = await _container([_serie(feita: false)]);
    await _abrir(tester, c);

    await tester.tap(find.text('FINALIZAR TREINO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartou no resumo'));
    await tester.pumpAndSettle();

    expect(find.text('Tela do plano'), findsOneWidget);
    c.dispose();
  });

  testWidgets('PBI-63: cabeçalho escuro com nome, cronômetro e séries feitas',
      (tester) async {
    final c = await _container([_serie(feita: true), _serie(feita: false)]);
    await _abrir(tester, c);

    expect(find.text('TREINO EM ANDAMENTO'), findsOneWidget);
    expect(find.text('TREINO A'), findsOneWidget);
    expect(find.text('Começou às 19:00'), findsOneWidget);
    expect(find.bySemanticsLabel('1 de 2 séries feitas'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Tempo de treino')), findsOneWidget);
    expect(find.text('Adicionar exercício fora da ficha'), findsOneWidget);
    // Barra empilhada: Finalizar acima de Descartar.
    expect(tester.getTopLeft(find.text('FINALIZAR TREINO')).dy,
        lessThan(tester.getTopLeft(find.text('Descartar treino')).dy));
    c.dispose();
  });

  testWidgets('PBI-63: descartar pela barra confirma e volta ao plano sem sessão',
      (tester) async {
    final c = await _container([_serie(feita: true), _serie(feita: false)]);
    await _abrir(tester, c);

    await tester.tap(find.text('Descartar treino'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar treino?'), findsOneWidget);
    expect(find.text('O que você fez neste treino será perdido.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar treino'));
    await tester.pumpAndSettle();

    expect(find.text('Tela do plano'), findsOneWidget);
    expect(c.read(treinoAoVivoControllerProvider), isNull);
    c.dispose();
  });

  testWidgets('PBI-63: "Voltar ao treino" no descartar mantém o treino',
      (tester) async {
    final c = await _container([_serie(feita: false)]);
    await _abrir(tester, c);

    await tester.tap(find.text('Descartar treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Voltar ao treino'));
    await tester.pumpAndSettle();

    expect(find.text('FINALIZAR TREINO'), findsOneWidget);
    expect(c.read(treinoAoVivoControllerProvider), isNotNull);
    c.dispose();
  });

}
