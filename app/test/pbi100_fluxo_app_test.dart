import 'package:diario_treino/app.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PBI-100 no app inteiro (go_router de verdade): Planos → detalhe do plano →
/// ficha → alvos → salvar → ficha. Só as bordas são falsas (login e repositório).

class _FakeUser extends Fake implements User {
  @override
  String? get displayName => 'Vitor';
  @override
  String get uid => 'uid';
}

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

class _Repo extends FichasRepository {
  _Repo() : super(Dio());

  int rodadas = 1;
  final log = <String>[];

  static const _treinos = [TreinoResumo(id: 'f1', nome: 'A', descricao: null, ordem: 1)];

  Future<void> _rede() => Future<void>.delayed(const Duration(milliseconds: 150));

  @override
  Future<PlanoAtivo?> obterPlanoAtivo() async =>
      const PlanoAtivo(id: 'p1', nome: 'Hipertrofia', treinos: _treinos);

  @override
  Future<PlanoAtivo> obterPlano(String planoId) async =>
      const PlanoAtivo(id: 'p1', nome: 'Hipertrofia', treinos: _treinos);

  @override
  Future<List<PlanoDaLista>> listarPlanos({String? atletaId}) async => [
        PlanoDaLista(
          id: 'p1',
          nome: 'Hipertrofia',
          inicio: DateTime(2026, 10, 1),
          emUso: true,
          autor: 'Vitor',
          somenteLeitura: false,
          quantidadeFichas: 1,
          quantidadeExercicios: 1,
        ),
      ];

  @override
  Future<PlanoDetalhe> obterDetalhePlano(String planoId, {String? atletaId}) async => PlanoDetalhe(
        id: 'p1',
        nome: 'Hipertrofia',
        inicio: DateTime(2026, 10, 1),
        emUso: true,
        autor: 'Vitor',
        somenteLeitura: false,
        treinos: _treinos,
      );

  @override
  Future<TreinoDetalhe> obterFicha(String treinoId) async {
    final r = rodadas; // o servidor lê no início
    log.add('GET ficha (rodadas=$r)');
    await _rede();
    return TreinoDetalhe(id: 'f1', nome: 'A', descricao: null, ordem: 1, exercicios: [
      TreinoExercicioResumo(
        id: 'te1',
        exercicioId: 'e1',
        nome: 'Supino reto',
        grupoMuscular: 'peito',
        modalidade: 'FORCA',
        ordem: 1,
        rodadas: r,
        descansoSeg: null,
        instrucao: null,
        alvo: _alvo,
      ),
    ]);
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
    log.add('PUT alvos ($series)');
    await _rede();
    rodadas = series;
  }
}

void main() {
  testWidgets('no app inteiro, salvar 4 séries e voltar à ficha mostra "4 séries"', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
        fichasRepositoryProvider.overrideWithValue(repo),
        sessoesRecentesProvider.overrideWith((ref) async => []),
        fichaTemSessoesProvider.overrideWith((ref, id) async => false),
        metricasProvider.overrideWith((ref) async => _metricas),
      ],
      child: const DiarioTreinoApp(),
    ));
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(tester.element(find.byType(DiarioTreinoApp)))
        .read(routerProvider);
    router.go(Rotas.fichas);
    await tester.pumpAndSettle();
    router.push('${Rotas.planoDetalhe}?id=p1');
    await tester.pumpAndSettle();
    router.push('${Rotas.fichaDoPlano}?plano=p1&ficha=f1');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 série'), findsOneWidget);

    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Mais uma série'));
      await tester.pump();
    }
    repo.log.clear();
    await tester.tap(find.text('SALVAR'));
    await tester.pumpAndSettle();

    // O PUT termina antes da releitura, e a releitura já traz o valor novo.
    expect(repo.log.first, 'PUT alvos (4)');
    expect(repo.log, contains('GET ficha (rodadas=4)'));
    expect(repo.log, isNot(contains('GET ficha (rodadas=1)')));

    expect(repo.rodadas, 4);
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.textContaining('4 séries'), findsOneWidget);
  });
}
