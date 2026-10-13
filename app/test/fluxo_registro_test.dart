// Teste de FLUXO de UI (E2E leve, Opção C do PBI-26). Exercita as telas reais
// e os providers reais (incluindo a invalidação e a navegação do go_router),
// fakeando só as BORDAS: autenticação (sem Firebase) e os repositórios (sem
// API/rede). Um store em memória guarda as sessões, então registrar um treino
// muda de verdade a recomendação da tela inicial — justamente o caminho do bug
// PBI-23A (sugestão não atualizava ao voltar do registro).
//
// Roda com `flutter test` (headless, sem browser nem rede), então entra no CI
// atual sem job novo. Um E2E de navegador completo (Robot + Browser contra a
// stack real) fica como PBI-26 "completo" para o futuro.

import 'package:diario_treino/app.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUser extends Fake implements User {
  @override
  String? get displayName => 'Vitor';
  @override
  String get uid => 'uid-e2e';
}

/// Store em memória compartilhado entre os fakes: é o "banco" do teste.
class _Store {
  _Store(this.plano);
  final PlanoAtivo plano;
  final List<SessaoResumo> sessoes = [];
}

/// Fake do repositório de fichas: devolve o plano fixo do store.
class _FakeFichasRepo extends FichasRepository {
  _FakeFichasRepo(this._store) : super(Dio());
  final _Store _store;

  @override
  Future<PlanoAtivo?> obterPlanoAtivo() async => _store.plano;
}

/// Fake do repositório de sessões: lê/grava no store em memória. Isso faz a
/// invalidação do sessoesRecentesProvider refletir o novo registro.
class _FakeSessaoRepo extends SessaoRepository {
  _FakeSessaoRepo(this._store) : super(Dio());
  final _Store _store;

  @override
  Future<RascunhoSessao> obterRascunho(String treinoId) async {
    final ficha = _store.plano.treinos.firstWhere((t) => t.id == treinoId);
    // Rascunho com um exercício e uma série em branco (como o back faz quando
    // não há alvos nem histórico — fix do PBI-33).
    return RascunhoSessao(
      treinoId: ficha.id,
      treinoNome: ficha.nome,
      data: DateTime.now(),
      exercicios: const [
        RascunhoExercicio(
          treinoExercicioId: 'te1',
          exercicioId: 'ex1',
          nome: 'Supino reto',
          grupoMuscular: 'peito',
          modalidade: 'FORCA',
          ordem: 1,
          origemPreenchimento: null,
          series: [
            SerieRascunho(
              rodada: 1,
              ordem: 1,
              tipo: 'ESFORCO',
              intensidadeMetricaId: 1,
              intensidadeMetricaCodigo: 'CARGA_KG',
              intensidadeMetricaNome: 'Carga',
              intensidade: null,
              volumeMetricaId: 10,
              volumeMetricaCodigo: 'REPETICOES',
              volumeMetricaNome: 'Repetições',
              volume: null,
              descansoSeg: null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<String> criarSessao({
    required String? treinoId,
    required DateTime data,
    int? duracaoMin,
    String? observacao,
    required List<ExercicioEdicao> exercicios,
  }) async {
    final id = 's${_store.sessoes.length + 1}';
    final ficha = treinoId == null
        ? null
        : _store.plano.treinos.firstWhere((t) => t.id == treinoId);
    _store.sessoes.add(SessaoResumo(
      id: id,
      data: data,
      treinoId: treinoId,
      treinoNome: ficha?.nome,
      quantidadeExercicios: exercicios.where((e) => e.temSerieFeita).length,
      duracaoMin: duracaoMin,
      temObservacao: observacao != null && observacao.isNotEmpty,
    ));
    return id;
  }

  @override
  Future<List<SessaoResumo>> listarSessoes({DateTime? de, DateTime? ate}) async {
    // Mais recentes primeiro, como o back.
    final lista = [..._store.sessoes]..sort((a, b) => b.data.compareTo(a.data));
    return lista;
  }
}

ProviderScope _appComFakes(_Store store, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Autenticação: usuário fixo logado, sem Firebase.
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
      // Repositórios: fakes em memória, sem API/rede.
      fichasRepositoryProvider.overrideWithValue(_FakeFichasRepo(store)),
      sessaoRepositoryProvider.overrideWithValue(_FakeSessaoRepo(store)),
      // Métricas (usadas ao adicionar exercício fora da ficha) — mapa fixo.
      metricasPorCodigoProvider.overrideWith((ref) async => const {
            'CARGA_KG': Metrica(
                id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE'),
            'REPETICOES': Metrica(
                id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: 'rep', eixo: 'VOLUME'),
          }),
    ],
    child: const DiarioTreinoApp(),
  );
}

/// Bombeia frames com duração fixa para dar tempo aos futures (fakes) e à
/// navegação, sem esperar animações contínuas (ex.: CircularProgressIndicator),
/// que travariam o pumpAndSettle.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'Registrar o Treino A faz a tela inicial passar a sugerir o Treino B',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _Store(PlanoAtivo(
        id: 'p1',
        nome: 'Plano',
        treinos: const [
          TreinoResumo(id: 'A', nome: 'A', descricao: 'Peito', ordem: 1),
          TreinoResumo(id: 'B', nome: 'B', descricao: 'Costas', ordem: 2),
        ],
      ));

      await tester.pumpWidget(_appComFakes(store, prefs));
      await tester.pumpAndSettle();

      // Estado inicial: sem histórico, sugere o A.
      expect(find.text('A · Peito'), findsOneWidget);

      // Abre o registro pelo cartão de sugestão.
      await tester.tap(find.text('REGISTRAR TREINO'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar A'), findsOneWidget);

      // Preenche a série em branco (carga e reps) do exercício sugerido.
      final campos = find.byType(TextField);
      // Os dois primeiros campos editáveis da série são intensidade e volume.
      await tester.enterText(campos.at(2), '30'); // após data/duração
      await tester.enterText(campos.at(3), '10');
      await tester.pumpAndSettle();

      // Salva o treino. Não usamos pumpAndSettle aqui: ao salvar, a Início
      // (ainda viva no IndexedStack) é invalidada e exibe um
      // CircularProgressIndicator momentâneo — uma animação contínua que faria
      // o pumpAndSettle expirar. Bombeamos frames fixos para os futures
      // (fakes) resolverem.
      await tester.tap(find.text('SALVAR TREINO'));
      await _assentar(tester);

      // Confirmação: volta ao Início.
      expect(find.text('Treino registrado'), findsOneWidget);
      await tester.tap(find.text('Ir para o Início'));
      await _assentar(tester);

      // AQUI está o coração do bug PBI-23A: ao voltar, a Início deve refletir
      // a nova sessão e recomendar o PRÓXIMO da sequência (B), não mais o A.
      expect(find.text('B · Costas'), findsOneWidget);
      expect(find.text('A · Peito'), findsNothing);
    },
  );
}
