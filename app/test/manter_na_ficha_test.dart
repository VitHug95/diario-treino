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
  final Future<List<String>?> Function() onTap;

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
            setState(() => _resultado = r == null ? 'voltou' : r.join(','));
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

  testWidgets('vários exercícios: lista os nomes e uma decisão vale para todos',
      (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice, prancha]);

    expect(find.text('Manter na ficha?'), findsOneWidget);
    expect(find.textContaining('Você adicionou exercícios', findRichText: true), findsOneWidget);
    expect(find.textContaining('2 séries de 20 × 10', findRichText: true), findsOneWidget);
    expect(find.textContaining('1 série de 45 s', findRichText: true), findsOneWidget);

    await tester.tap(find.text('MANTER NA FICHA'));
    await tester.pumpAndSettle();
    expect(find.text('resultado: coice,prancha'), findsOneWidget);
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

  testWidgets('sem conseguir ler a ficha, salva só neste treino', (tester) async {
    await _abrir(tester, treinoId: 'B', exercicios: [coice],
        ficha: () async => throw Exception('sem rede'));

    expect(find.text('Manter na ficha?'), findsNothing);
    expect(find.text('resultado: '), findsOneWidget);
  });
}
