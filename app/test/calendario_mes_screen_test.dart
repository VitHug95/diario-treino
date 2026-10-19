import 'package:diario_treino/core/localizacao/material_pt.dart';
import 'package:diario_treino/core/relogio.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/inicio/calendario_mes_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelogioFixo implements Relogio {
  _RelogioFixo(this.valor);
  final DateTime valor;
  @override
  DateTime agora() => valor;
}

SessaoResumo _sessao(DateTime data) => SessaoResumo(
      id: 's-${data.toIso8601String()}',
      data: data,
      treinoId: null,
      treinoNome: null,
      quantidadeExercicios: 2,
      duracaoMin: 40,
      temObservacao: false,
    );

PlanoAtivo _plano() => PlanoAtivo(id: 'p1', nome: 'Hipertrofia', treinos: const []);

/// Monta a tela com hoje fixo (19/10/2026, quinta) e as sessões por mês.
/// [sessoesPorMes] mapeia (ano, mes) → lista; meses ausentes vêm vazios.
/// [erro] força o provider do mês a falhar.
Widget _tela({
  Map<(int, int), List<SessaoResumo>> sessoesPorMes = const {},
  bool erro = false,
}) =>
    ProviderScope(
      overrides: [
        relogioProvider.overrideWithValue(_RelogioFixo(DateTime(2026, 10, 19))),
        planoAtivoProvider.overrideWith((ref) async => _plano()),
        sessoesDoMesProvider.overrideWith((ref, mes) async {
          if (erro) throw Exception('sem rede');
          return sessoesPorMes[(mes.year, mes.month)] ?? const [];
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        localizationsDelegates: LocalizacoesPt.delegates,
        home: const CalendarioMesScreen(),
      ),
    );

void main() {
  testWidgets('abre no mês atual com título e dias treinados', (tester) async {
    await tester.pumpWidget(_tela(sessoesPorMes: {
      (2026, 10): [_sessao(DateTime(2026, 10, 1)), _sessao(DateTime(2026, 10, 17))],
    }));
    await tester.pumpAndSettle();

    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('2 dias treinados'), findsOneWidget);
    // Cabeçalho de colunas e alguns números de dia.
    expect(find.text('1'), findsWidgets);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('seta de mês seguinte desabilitada no mês atual; sem "Hoje"',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    final seguinte = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Mês seguinte'), matching: find.byType(IconButton)),
    );
    expect(seguinte.onPressed, isNull); // desabilitada
    expect(find.text('Hoje'), findsNothing); // só fora do mês atual
  });

  testWidgets('voltar um mês mostra o mês anterior, o "Hoje" e habilita o seguinte',
      (tester) async {
    await tester.pumpWidget(_tela(sessoesPorMes: {
      (2026, 9): [_sessao(DateTime(2026, 9, 5))],
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();

    expect(find.text('Setembro de 2026'), findsOneWidget);
    expect(find.text('1 dia treinado'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);

    final seguinte = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Mês seguinte'), matching: find.byType(IconButton)),
    );
    expect(seguinte.onPressed, isNotNull); // habilitada fora do mês atual

    // "Hoje" volta ao mês atual.
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    expect(find.text('Outubro de 2026'), findsOneWidget);
  });

  testWidgets('erro de rede mostra aviso e "Tentar de novo", nunca mês vazio falso',
      (tester) async {
    await tester.pumpWidget(_tela(erro: true));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar seu histórico.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('0 dias treinados'), findsNothing);
  });

  testWidgets('mês sem treino mostra "0 dias treinados" e a grade', (tester) async {
    await tester.pumpWidget(_tela(sessoesPorMes: const {(2026, 10): []}));
    await tester.pumpAndSettle();

    expect(find.text('0 dias treinados'), findsOneWidget);
    expect(find.text('15'), findsOneWidget); // a grade existe
  });

  testWidgets('rótulos falados dos estados do dia', (tester) async {
    await tester.pumpWidget(_tela(sessoesPorMes: {
      (2026, 10): [_sessao(DateTime(2026, 10, 1))],
    }));
    await tester.pumpAndSettle();

    // Dia com treino, dia passado sem treino, hoje e futuro.
    expect(find.bySemanticsLabel('Dia 01/10, treino registrado'), findsOneWidget);
    expect(find.bySemanticsLabel('Dia 02/10, sem treino. Toque para registrar'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Dia 20/10, ainda não chegou'), findsOneWidget);
  });

  testWidgets('tocar num dia passado abre a folha do dia; dia futuro não abre',
      (tester) async {
    await tester.pumpWidget(_tela(sessoesPorMes: {
      (2026, 10): [_sessao(DateTime(2026, 10, 1))],
    }));
    await tester.pumpAndSettle();

    // Dia futuro: botão desabilitado (sem toque), a folha não abre.
    await tester.tap(find.bySemanticsLabel('Dia 20/10, ainda não chegou'),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('REGISTRAR TREINO NESTE DIA'), findsNothing);

    // Dia passado: abre a folha do dia (PBI-59) com a opção de registrar.
    await tester.tap(find.bySemanticsLabel('Dia 02/10, sem treino. Toque para registrar'));
    await tester.pumpAndSettle();
    expect(find.text('REGISTRAR TREINO NESTE DIA'), findsOneWidget);
    expect(find.text('Sem ficha'), findsOneWidget);
  });
}
