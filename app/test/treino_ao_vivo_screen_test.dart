import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
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
/// exercício só.
Future<ProviderContainer> _container(List<SerieEdicao> series) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 15, 20, 0))),
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

/// Tela 24 empilhada sobre o "plano", com o resumo mostrando o que recebeu.
Future<void> _abrir(WidgetTester tester, ProviderContainer c) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('Tela do plano')),
      ),
      GoRoute(
        path: Rotas.treinoAoVivo,
        builder: (_, __) => const TreinoAoVivoScreen(),
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
  router.push(Rotas.treinoAoVivo);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('PBI-63: sem seta de voltar; barra com Finalizar e Descartar de 48 px',
      (tester) async {
    final c = await _container([_serie(feita: false)]);
    await _abrir(tester, c);

    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);

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

  testWidgets('PBI-63: voltar do sistema avisa e fica no treino', (tester) async {
    final c = await _container([_serie(feita: false)]);
    await _abrir(tester, c);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Para sair, finalize ou descarte o treino.'), findsOneWidget);
    expect(find.text('FINALIZAR TREINO'), findsOneWidget);
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
