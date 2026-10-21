import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/manter_na_ficha.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PBI-72: regras do "Manter na ficha?" que valem para o Resumo e para o
/// registro de treino já feito (os dois chamam [perguntarManterNaFicha]).

SerieEdicao _serie(String carga, String reps,
        {String volumeCodigo = 'REPETICOES', bool pesoCorporal = false}) =>
    SerieEdicao(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: pesoCorporal ? 2 : 1,
      intensidadeMetricaCodigo: pesoCorporal ? 'PESO_CORPORAL' : 'CARGA_KG',
      intensidadeMetricaNome: pesoCorporal ? 'Peso corporal' : 'Carga',
      intensidadeTexto: carga,
      volumeMetricaId: volumeCodigo == 'TEMPO_SEG' ? 11 : 10,
      volumeMetricaCodigo: volumeCodigo,
      volumeMetricaNome: volumeCodigo == 'TEMPO_SEG' ? 'Tempo' : 'Repetições',
      volumeTexto: reps,
      descansoTexto: '',
    );

ExercicioEdicao _ex(String id, String nome, List<SerieEdicao> series,
        {bool foraDaFicha = true, bool realizado = true}) =>
    ExercicioEdicao(
      treinoExercicioId: foraDaFicha ? null : 'te-$id',
      exercicioId: id,
      nome: nome,
      grupoMuscular: null,
      modalidade: 'FORCA',
      origemPreenchimento: null,
      realizado: realizado,
      foraDaFicha: foraDaFicha,
      series: series,
    );

TreinoExercicioResumo _naFicha(String exercicioId) => TreinoExercicioResumo(
      id: 'te-$exercicioId',
      exercicioId: exercicioId,
      nome: exercicioId,
      grupoMuscular: null,
      modalidade: 'FORCA',
      ordem: 1,
      rodadas: 3,
      descansoSeg: null,
      instrucao: null,
      alvo: null,
    );

/// Tela com um botão que chama a pergunta e mostra o que ela devolveu.
Future<void> _abrir(
  WidgetTester tester, {
  required String? treinoId,
  required List<ExercicioEdicao> exercicios,
  Future<TreinoDetalhe> Function()? ficha,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      fichaDetalheProvider.overrideWith((ref, id) => ficha != null
          ? ficha()
          : Future.value(TreinoDetalhe(
              id: id, nome: 'B', descricao: null, ordem: 1, exercicios: const []))),
    ],
    child: MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          return _Botao(onTap: () => perguntarManterNaFicha(
                context,
                ref,
                treinoId: treinoId,
                treinoNome: 'Treino B',
                exercicios: exercicios,
                rotuloVoltar: 'Voltar ao registro',
              ));
        }),
      ),
    ),
  ));
  await tester.tap(find.text('salvar'));
  await tester.pumpAndSettle();
}

class _Botao extends StatefulWidget {
  const _Botao({required this.onTap});
  final Future<ResultadoManterNaFicha> Function() onTap;

  @override
  State<_Botao> createState() => _BotaoState();
}

class _BotaoState extends State<_Botao> {
  String _resultado = '-';

  @override
  Widget build(BuildContext context) => Column(children: [
        TextButton(
          onPressed: () async {
            final r = await widget.onTap();
            setState(() {
              final base = r.ids == null ? 'voltou' : r.ids!.join(',');
              _resultado = r.leituraFalhou ? '$base (ficha não lida)' : base;
            });
          },
          child: const Text('salvar'),
        ),
        Text('resultado: $_resultado'),
      ]);
}

void main() {
  final coice = _ex('coice', 'Tríceps coice', [_serie('20', '10'), _serie('20', '10')]);
  final prancha = _ex('prancha', 'Prancha',
      [_serie('', '45', volumeCodigo: 'TEMPO_SEG', pesoCorporal: true)]);

  testWidgets('vários exercícios: lista nomes/resumos e todos começam em "manter"',
      (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice, prancha]);

    expect(find.text('Manter na ficha?'), findsOneWidget);
    expect(find.textContaining('Escolha o que fica na ficha'), findsOneWidget);
    expect(find.text('Tríceps coice'), findsOneWidget);
    expect(find.text('Prancha'), findsOneWidget);
    expect(find.text('2 séries de 20 × 10'), findsOneWidget);
    expect(find.text('1 série de 45 s'), findsOneWidget);

    // PBI-81: padrão é manter todos; "Salvar" sem mexer devolve os dois.
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();
    expect(find.text('resultado: coice,prancha'), findsOneWidget);
  });

  testWidgets('PBI-81: manter um e deixar o outro só neste treino',
      (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice, prancha]);

    // Na linha da Prancha, troca para "Só neste treino". O SegmentedButton da
    // prancha é o 2º; mira pelo rótulo acessível da linha para não confundir.
    final soNesteDaPrancha = find.descendant(
      of: find.ancestor(
          of: find.text('Prancha'), matching: find.byType(Column)),
      matching: find.text('Só neste treino'),
    );
    await tester.tap(soNesteDaPrancha.first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();
    // Só o coice fica na ficha; os dois seguem na sessão (isso é no back).
    expect(find.text('resultado: coice'), findsOneWidget);
  });

  testWidgets('voltar devolve nulo (não salva) com o rótulo do registro', (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice]);

    await tester.tap(find.text('Voltar ao registro'));
    await tester.pumpAndSettle();
    expect(find.text('resultado: voltou'), findsOneWidget);
  });

  testWidgets('treino livre não pergunta', (tester) async {
    await _abrir(tester, treinoId: null, exercicios: [coice]);

    expect(find.text('Manter na ficha?'), findsNothing);
    expect(find.text('resultado: '), findsOneWidget);
  });

  testWidgets('exercício fora da ficha sem série salva não conta', (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [
      _ex('coice', 'Tríceps coice', [_serie('20', '')]), // sem volume
      _ex('remada', 'Remada', [_serie('20', '10')], realizado: false),
      _ex('supino', 'Supino', [_serie('30', '10')], foraDaFicha: false),
    ]);

    expect(find.text('Manter na ficha?'), findsNothing);
    expect(find.text('resultado: '), findsOneWidget);
  });

  testWidgets('ficha do professor não pergunta', (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice],
        ficha: () async => const TreinoDetalhe(
            id: 'B', nome: 'B', descricao: null, ordem: 1, exercicios: [],
            somenteLeitura: true));

    expect(find.text('Manter na ficha?'), findsNothing);
  });

  testWidgets('exercício que já está na ficha não entra na pergunta', (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice],
        ficha: () async => TreinoDetalhe(
            id: 'B', nome: 'B', descricao: null, ordem: 1, exercicios: [_naFicha('coice')]));

    expect(find.text('Manter na ficha?'), findsNothing);
  });

  testWidgets('sem conseguir ler a ficha, salva mas sinaliza (PBI-76)', (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice],
        ficha: () async => throw Exception('sem rede'));

    // Não pergunta (não dá para conferir), salva só neste treino, mas agora
    // sinaliza que a ficha não foi lida — o chamador avisa o atleta.
    expect(find.text('Manter na ficha?'), findsNothing);
    expect(find.text('resultado:  (ficha não lida)'), findsOneWidget);
  });

  testWidgets('PBI-76: os três botões aparecem e são tocáveis em 360 px e fonte 1,3x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        fichaDetalheProvider.overrideWith((ref, id) => Future.value(TreinoDetalhe(
            id: id, nome: 'B', descricao: null, ordem: 1, exercicios: const []))),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Consumer(builder: (context, ref, _) {
              return _Botao(onTap: () => perguntarManterNaFicha(
                    context, ref,
                    treinoId: 'B', treinoNome: 'Treino B',
                    exercicios: [coice], rotuloVoltar: 'Voltar ao registro',
                  ));
            }),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('salvar'));
    await tester.pumpAndSettle();

    // Os três botões visíveis e com alvo de toque adequado.
    final manter = find.widgetWithText(FilledButton, 'MANTER NA FICHA');
    final soNeste = find.widgetWithText(OutlinedButton, 'Só neste treino');
    final voltar = find.widgetWithText(TextButton, 'Voltar ao registro');
    expect(manter, findsOneWidget);
    expect(soNeste, findsOneWidget);
    expect(voltar, findsOneWidget);
    expect(tester.getSize(manter).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(soNeste).height, greaterThanOrEqualTo(44));
    // Empilhados: cada um começa abaixo do anterior (coluna, não linha).
    expect(tester.getTopLeft(soNeste).dy, greaterThan(tester.getTopLeft(manter).dy));
    expect(tester.getTopLeft(voltar).dy, greaterThan(tester.getTopLeft(soNeste).dy));
  });
}
