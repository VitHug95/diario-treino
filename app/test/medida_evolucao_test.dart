import 'package:dio/dio.dart';
import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/features/medidas/medida_evolucao_screen.dart';
import 'package:diario_treino/features/medidas/medidas_comandos.dart';
import 'package:diario_treino/features/medidas/medidas_formato.dart';
import 'package:diario_treino/features/medidas/medidas_models.dart';
import 'package:diario_treino/features/medidas/medidas_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PBI-94 (E12): gráfico de evolução da medida. Filtros de período, primeira,
/// última e variação, eixo que não parte do zero, ponto único sem linha, estado
/// vazio, toque no ponto, rótulo falado e atualização depois de salvar.

class _RelogioFixo implements Relogio {
  @override
  DateTime agora() => DateTime(2026, 11, 9, 10);
}

PontoMedida _p(int mes, int dia, double valor) =>
    PontoMedida(data: DateTime(2026, mes, dia), valor: valor);

/// Repositório em memória que filtra pelo `de` como a API (limite inclusive).
class _RepoEvolucao extends MedidasRepository {
  _RepoEvolucao(this.pontos) : super(Dio());

  final Map<TipoMedida, List<PontoMedida>> pontos;
  final consultas = <({TipoMedida tipo, DateTime? de})>[];
  bool falhar = false;

  @override
  Future<EvolucaoMedida> obterEvolucao(TipoMedida tipo,
      {DateTime? de, DateTime? ate}) async {
    consultas.add((tipo: tipo, de: de));
    if (falhar) throw Exception('rede');
    final lista = (pontos[tipo] ?? [])
        .where((p) => de == null || !p.data.isBefore(de))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    return EvolucaoMedida(
      tipo: tipo,
      pontos: lista,
      primeira: lista.isEmpty ? null : lista.first,
      ultima: lista.isEmpty ? null : lista.last,
      variacao: lista.length > 1 ? lista.last.valor - lista.first.valor : null,
    );
  }

  @override
  Future<void> salvarMedidas(DateTime data, Map<TipoMedida, double?> valores) async {
    for (final e in valores.entries) {
      final lista = pontos.putIfAbsent(e.key, () => []);
      lista.removeWhere((p) => p.data == data);
      if (e.value != null) lista.add(PontoMedida(data: data, valor: e.value!));
    }
  }
}

// Cintura: 10/08 (87,0), 25/09 (85,5), 05/11 (84,0) — 91 dias antes de 09/11
// é 10/08, então o primeiro ponto está FORA de 90 dias e dentro de 1 ano.
List<PontoMedida> _cintura() => [_p(8, 10, 87.0), _p(9, 25, 85.5), _p(11, 5, 84.0)];

Future<ProviderScope> _escopo(MedidasRepository repo, Widget filho) async =>
    ProviderScope(
      overrides: [
        medidasRepositoryProvider.overrideWithValue(repo),
        relogioProvider.overrideWithValue(_RelogioFixo()),
      ],
      child: filho,
    );

void _telaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _abrir(
  WidgetTester tester,
  MedidasRepository repo, {
  TipoMedida tipo = TipoMedida.cintura,
  ThemeData? tema,
}) async {
  _telaDeCelular(tester);
  await tester.pumpWidget(await _escopo(
    repo,
    MaterialApp(theme: tema ?? AppTheme.claro, home: MedidaEvolucaoScreen(tipo: tipo)),
  ));
  await tester.pumpAndSettle();
}

LineChartData _grafico(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data;

void main() {
  testWidgets('Abre no filtro de 90 dias com os pontos certos e os três cartões',
      (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    await _abrir(tester, repo);

    // Padrão 90 dias: 09/11 − 90 = 11/08, então o ponto de 10/08 não entra.
    expect(repo.consultas.last.de, DateTime(2026, 8, 11));
    expect(find.text('PRIMEIRA'), findsOneWidget);
    expect(find.text('ÚLTIMA'), findsOneWidget);
    expect(find.text('VARIAÇÃO'), findsOneWidget);
    expect(_grafico(tester).lineBarsData.first.spots.length, 2);
    expect(find.text('−1,5 cm'), findsOneWidget); // 84,0 − 85,5
  });

  testWidgets('Trocar o filtro muda os pontos e os cartões do período', (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    await _abrir(tester, repo);

    await tester.tap(find.text('1 ano'));
    await tester.pumpAndSettle();

    expect(repo.consultas.last.de, DateTime(2025, 11, 9)); // 365 dias
    expect(_grafico(tester).lineBarsData.first.spots.length, 3);
    expect(find.text('−3,0 cm'), findsOneWidget); // 84,0 − 87,0
    expect(find.text('87,0 cm'), findsWidgets); // primeira

    await tester.tap(find.text('30 dias'));
    await tester.pumpAndSettle();
    expect(repo.consultas.last.de, DateTime(2026, 10, 10));
    expect(_grafico(tester).lineBarsData.first.spots.length, 1);

    await tester.tap(find.text('Tudo'));
    await tester.pumpAndSettle();
    expect(repo.consultas.last.de, isNull); // sem limite
    expect(_grafico(tester).lineBarsData.first.spots.length, 3);
  });

  testWidgets('Um registro só mostra o ponto sem linha e a variação vazia', (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: [_p(11, 5, 84.0)]});
    await _abrir(tester, repo);

    final barra = _grafico(tester).lineBarsData.first;
    expect(barra.spots.length, 1); // um ponto: não há segmento para desenhar
    expect(barra.dotData.show, isTrue);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('1 registro'), findsOneWidget);
  });

  testWidgets('Sem registro no período: mensagem, sem gráfico quebrado', (tester) async {
    await _abrir(tester, _RepoEvolucao({}));

    expect(find.text('Sem registros neste período'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('REGISTROS DO PERÍODO'), findsNothing);
  });

  testWidgets('O eixo vertical não começa do zero', (tester) async {
    await _abrir(tester, _RepoEvolucao({TipoMedida.cintura: _cintura()}));
    await tester.tap(find.text('1 ano'));
    await tester.pumpAndSettle();

    final g = _grafico(tester);
    // Dados entre 84 e 87: o eixo fica em volta deles, nunca em 0.
    expect(g.minY, greaterThan(70));
    expect(g.minY, lessThan(84));
    expect(g.maxY, greaterThan(87));
    expect(g.maxY, lessThan(100));
  });

  testWidgets('Com valores iguais o eixo ainda tem folga (não colapsa)', (tester) async {
    final repo = _RepoEvolucao({
      TipoMedida.cintura: [_p(10, 1, 84.0), _p(11, 5, 84.0)],
    });
    await _abrir(tester, repo);

    final g = _grafico(tester);
    expect(g.maxY - g.minY, greaterThanOrEqualTo(2));
    expect(find.text('Igual'), findsOneWidget);
  });

  testWidgets('O peso usa a mesma tela, em kg', (tester) async {
    final repo = _RepoEvolucao({
      TipoMedida.peso: [_p(10, 1, 80.0), _p(11, 5, 78.5)],
    });
    await _abrir(tester, repo, tipo: TipoMedida.peso);

    expect(find.text('Peso'), findsWidgets); // título
    expect(find.text('78,5 kg'), findsWidgets);
    expect(find.text('−1,5 kg'), findsOneWidget);
  });

  testWidgets('Lista "Registros do período" em texto, do mais recente ao mais antigo',
      (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    await _abrir(tester, repo);
    await tester.tap(find.text('1 ano'));
    await tester.pumpAndSettle();

    expect(find.text('REGISTROS DO PERÍODO'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('05/11/2026'), lessThan(y('25/09/2026')));
    expect(y('25/09/2026'), lessThan(y('10/08/2026')));
  });

  testWidgets('Tocar num ponto seleciona e mostra a data e o valor dele', (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    await _abrir(tester, repo);
    await tester.tap(find.text('1 ano'));
    await tester.pumpAndSettle();

    // Começa no mais recente.
    expect(find.text('05/11/2026 · 84,0 cm'), findsOneWidget);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final barra = chart.data.lineBarsData.first;
    chart.data.lineTouchData.touchCallback!(
      FlTapDownEvent(TapDownDetails(kind: PointerDeviceKind.touch)),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        lineBarSpots: [TouchLineBarSpot(barra, 0, barra.spots.first, 0)],
      ),
    );
    await tester.pump();

    expect(find.text('10/08/2026 · 87,0 cm'), findsOneWidget);
    expect(find.text('05/11/2026 · 84,0 cm'), findsNothing);
    // O alvo de cada ponto tem 44 px (22 de raio).
    expect(chart.data.lineTouchData.touchSpotThreshold, 22);
  });

  testWidgets('Trocar o período volta a seleção para o ponto mais recente', (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    await _abrir(tester, repo);
    await tester.tap(find.text('1 ano'));
    await tester.pumpAndSettle();
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final barra = chart.data.lineBarsData.first;
    chart.data.lineTouchData.touchCallback!(
      FlTapDownEvent(TapDownDetails(kind: PointerDeviceKind.touch)),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        lineBarSpots: [TouchLineBarSpot(barra, 0, barra.spots.first, 0)],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tudo'));
    await tester.pumpAndSettle();

    expect(find.text('05/11/2026 · 84,0 cm'), findsOneWidget);
  });

  testWidgets('Rótulo falado do gráfico: início, fim e variação', (tester) async {
    final handle = tester.ensureSemantics();
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    await _abrir(tester, repo);
    await tester.tap(find.text('1 ano'));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel(
            'Cintura de 87,0 centímetros em 10/08 para 84,0 centímetros em 05/11, queda de 3,0 centímetros'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Variação: queda de 3,0 centímetros'), findsOneWidget);
    expect(find.bySemanticsLabel('05/11/2026: 84,0 centímetros'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Rótulo falado com um registro só', (tester) async {
    final handle = tester.ensureSemantics();
    await _abrir(tester, _RepoEvolucao({TipoMedida.cintura: [_p(11, 5, 84.0)]}));

    expect(find.bySemanticsLabel('Cintura: 84,0 centímetros em 05/11, um registro no período'),
        findsOneWidget);
    handle.dispose();
  });

  testWidgets('Erro de rede com "Tentar de novo" (ref.refresh do próprio provider)',
      (tester) async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()})..falhar = true;
    await _abrir(tester, repo);

    expect(find.text('Não foi possível carregar a evolução.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);

    repo.falhar = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
  });

  for (final escuro in [false, true]) {
    testWidgets('Funciona em 360 px e fonte 1,3x (${escuro ? 'escuro' : 'claro'})',
        (tester) async {
      _telaDeCelular(tester);
      final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
      await tester.pumpWidget(await _escopo(
        repo,
        MaterialApp(
          theme: escuro ? AppTheme.escuro : AppTheme.claro,
          home: const MedidaEvolucaoScreen(tipo: TipoMedida.cintura),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 ano'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // sem overflow
      expect(find.byType(LineChart), findsOneWidget);
    });
  }

  // ---- Atualização depois de salvar ou excluir ----

  test('Salvar uma medida atualiza o gráfico aberto (Mudanca.medidas)', () async {
    final repo = _RepoEvolucao({TipoMedida.cintura: _cintura()});
    final c = ProviderContainer(overrides: [
      medidasRepositoryProvider.overrideWithValue(repo),
      relogioProvider.overrideWithValue(_RelogioFixo()),
    ]);
    addTearDown(c.dispose);
    final chave = (tipo: TipoMedida.cintura, periodo: PeriodoMedida.tudo);
    c.listen(evolucaoMedidaProvider(chave), (_, __) {});
    await c.read(evolucaoMedidaProvider(chave).future);
    final antes = repo.consultas.length;

    await c.read(medidasComandosProvider).salvar(DateTime(2026, 11, 9), {TipoMedida.cintura: 83.0});

    final depois = await c.read(evolucaoMedidaProvider(chave).future);
    expect(repo.consultas.length, greaterThan(antes));
    expect(depois.pontos.length, 4); // o ponto novo de 09/11 entrou
    expect(depois.ultima!.valor, 83.0);
  });

  test('Excluir um dia também atualiza o gráfico aberto', () async {
    final repo = _RepoEvolucaoComExclusao({TipoMedida.cintura: _cintura()});
    final c = ProviderContainer(overrides: [
      medidasRepositoryProvider.overrideWithValue(repo),
      relogioProvider.overrideWithValue(_RelogioFixo()),
    ]);
    addTearDown(c.dispose);
    final chave = (tipo: TipoMedida.cintura, periodo: PeriodoMedida.tudo);
    c.listen(evolucaoMedidaProvider(chave), (_, __) {});
    expect((await c.read(evolucaoMedidaProvider(chave).future)).pontos.length, 3);

    await c.read(medidasComandosProvider).excluir(DateTime(2026, 11, 5));

    expect((await c.read(evolucaoMedidaProvider(chave).future)).pontos.length, 2);
  });

  test('A mesma escolha de tipo e período reaproveita o provider (chave por valor)', () {
    final a = (tipo: TipoMedida.cintura, periodo: PeriodoMedida.dias90);
    final b = (tipo: TipoMedida.cintura, periodo: PeriodoMedida.dias90);
    expect(evolucaoMedidaProvider(a), evolucaoMedidaProvider(b));
    expect(evolucaoMedidaProvider(a),
        isNot(evolucaoMedidaProvider((tipo: TipoMedida.peso, periodo: PeriodoMedida.dias90))));
  });

  test('falarTendencia e formatarVariacao', () {
    expect(falarTendencia(-3.0, TipoMedida.cintura), 'queda de 3,0 centímetros');
    expect(falarTendencia(1.0, TipoMedida.cintura), 'alta de 1,0 centímetro');
    expect(falarTendencia(0.5, TipoMedida.peso), 'alta de 0,5 quilos');
    expect(falarTendencia(0, TipoMedida.peso), 'sem variação');
  });
}

class _RepoEvolucaoComExclusao extends _RepoEvolucao {
  _RepoEvolucaoComExclusao(super.pontos);

  @override
  Future<void> excluirMedidas(DateTime data) async {
    for (final lista in pontos.values) {
      lista.removeWhere((p) => p.data == data);
    }
  }
}
