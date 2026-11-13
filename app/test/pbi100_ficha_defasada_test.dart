import 'package:dio/dio.dart';
import 'package:diario_treino/core/localizacao/material_pt.dart';
import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/fichas_screen.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PBI-100: depois de salvar os alvos, a ficha (já aberta, por baixo da tela de
/// alvos) tem de mostrar o valor novo na hora.

const _metricas = <Metrica>[
  Metrica(id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE'),
  Metrica(id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: 'rep', eixo: 'VOLUME'),
];

const _alvo = AlvoExercicio(
  intensidadeMetricaId: 1,
  intensidadeMetricaCodigo: 'CARGA_KG',
  intensidadeMetricaNome: 'Carga',
  intensidadeAlvo: null,
  volumeMetricaId: 10,
  volumeMetricaCodigo: 'REPETICOES',
  volumeMetricaNome: 'Repetições',
  volumeAlvo: null,
);

/// "Servidor" em memória: a ficha f1 com um exercício; o PUT dos alvos grava.
class _RepoFichas extends FichasRepository {
  _RepoFichas() : super(Dio());

  int rodadas = 1;
  int? descansoSeg;
  int leiturasFicha = 0;
  Duration atraso = Duration.zero;

  TreinoDetalhe _ficha() => TreinoDetalhe(
        id: 'f1',
        nome: 'A',
        descricao: null,
        ordem: 1,
        exercicios: [
          TreinoExercicioResumo(
            id: 'te1',
            exercicioId: 'e1',
            nome: 'Supino reto',
            grupoMuscular: 'peito',
            modalidade: 'FORCA',
            ordem: 1,
            rodadas: rodadas,
            descansoSeg: descansoSeg,
            instrucao: null,
            alvo: _alvo,
          ),
        ],
      );

  @override
  Future<TreinoDetalhe> obterFicha(String treinoId) async {
    leiturasFicha++;
    // Lê o estado no INÍCIO da requisição, como um servidor real.
    final resposta = _ficha();
    await Future<void>.delayed(atraso);
    return resposta;
  }

  @override
  Future<void> definirAlvos({
    required String treinoId,
    required String treinoExercicioId,
    required int series,
    required int intensidadeMetricaId,
    double? intensidadeAlvo,
    required int volumeMetricaId,
    double? volumeAlvo,
    double? volumeAlvoMax,
    int? descansoSeg,
    String? instrucao,
    List<MarcadorRodada> marcadores = const [],
  }) async {
    await Future<void>.delayed(atraso);
    rodadas = series;
    this.descansoSeg = descansoSeg;
  }
}

Widget _app(_RepoFichas repo, {bool comPlanoPorBaixo = false}) => ProviderScope(
      overrides: [
        fichasRepositoryProvider.overrideWithValue(repo),
        planoAtivoProvider.overrideWith((ref) async => const PlanoAtivo(
              id: 'p1',
              nome: 'Hipertrofia',
              treinos: [TreinoResumo(id: 'f1', nome: 'A', descricao: null, ordem: 1)],
            )),
        fichaTemSessoesProvider.overrideWith((ref, id) async => false),
        sessoesRecentesProvider.overrideWith((ref) async => []),
        metricasProvider.overrideWith((ref) async => _metricas),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        localizationsDelegates: LocalizacoesPt.delegates,
        home: comPlanoPorBaixo
            ? const _TelaPlano()
            : const FichasScreen(fichaInicialId: 'f1'),
      ),
    );

/// Como o detalhe do plano (tela 19): o cartão da ficha também observa
/// `fichaDetalheProvider('f1')` (o resumo de exercícios). A ficha é empilhada em cima.
class _TelaPlano extends ConsumerStatefulWidget {
  const _TelaPlano();

  @override
  ConsumerState<_TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends ConsumerState<_TelaPlano> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const FichasScreen(fichaInicialId: 'f1'),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final qtd = ref.watch(fichaDetalheProvider('f1')).maybeWhen(
        data: (f) => '${f.exercicios.first.rodadas} no plano', orElse: () => '...');
    return Scaffold(body: Center(child: Text(qtd)));
  }
}

void main() {
  testWidgets('salvar 4 séries e voltar à ficha mostra "4 séries" na hora', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _RepoFichas();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 série'), findsOneWidget);

    // Abre a tela de alvos pelo cartão e sobe para 4 séries.
    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Mais uma série'));
      await tester.pump();
    }
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(repo.rodadas, 4); // o "servidor" gravou
    expect(find.text('Supino reto'), findsOneWidget); // voltou à ficha
    expect(find.textContaining('4 séries'), findsOneWidget);
    expect(find.textContaining('1 série'), findsNothing);
  });

  testWidgets('com rede lenta (300 ms) a ficha também mostra "4 séries"', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _RepoFichas()..atraso = const Duration(milliseconds: 300);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 série'), findsOneWidget);

    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Mais uma série'));
      await tester.pump();
    }
    final antes = repo.leiturasFicha;
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(repo.rodadas, 4);
    expect(repo.leiturasFicha, greaterThan(antes)); // releu do servidor
    expect(find.textContaining('4 séries'), findsOneWidget);
  });

  testWidgets('com o plano por baixo também observando a ficha, mostra "4 séries"',
      (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _RepoFichas()..atraso = const Duration(milliseconds: 300);
    await tester.pumpWidget(_app(repo, comPlanoPorBaixo: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 série'), findsOneWidget);

    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Mais uma série'));
      await tester.pump();
    }
    final antes = repo.leiturasFicha;
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    expect(repo.rodadas, 4);
    expect(repo.leiturasFicha, greaterThan(antes));
    expect(find.textContaining('4 séries'), findsOneWidget);

    // E o plano, ao voltar, também. A ficha não tem botão voltar próprio
    // (no app quem volta é o go_router), então o teste desempilha direto.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('4 no plano'), findsOneWidget);
  });
}