// PBI-70: telas atualizam pela origem da mudança. O app inteiro roda com UM
// ProviderScope do início ao fim (nunca recriado), e só as bordas são fakes:
// login e repositórios, sobre um "banco" em memória. Se uma escrita esquecer de
// avisar quem lê, a Início ou a lista continuam com o valor velho e o teste
// falha. Esse é o bug que o PO viu ("montei o plano e a Início continuou no
// Bem-vindo").

import 'package:diario_treino/app.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Usuario extends Fake implements User {
  @override
  String? get displayName => 'Vitor';
  @override
  String get uid => 'uid-pbi70';
}

class _Plano {
  _Plano(this.id, this.nome, {required this.emUso});
  final String id;
  String nome;
  bool emUso;
  final List<TreinoResumo> fichas = [];
}

/// "Banco" do teste, compartilhado pelos fakes.
class _Banco {
  final planos = <_Plano>[];
  final sessoes = <SessaoResumo>[];
  var _seq = 0;
  String novoId(String prefixo) => '$prefixo${++_seq}';

  _Plano? get emUso => planos.where((p) => p.emUso).firstOrNull;
  _Plano plano(String id) => planos.firstWhere((p) => p.id == id);
}

class _FichasFake extends FichasRepository {
  _FichasFake(this._b) : super(Dio());
  final _Banco _b;

  PlanoAtivo _ativo(_Plano p) =>
      PlanoAtivo(id: p.id, nome: p.nome, treinos: List.of(p.fichas));

  @override
  Future<PlanoAtivo?> obterPlanoAtivo() async {
    final p = _b.emUso;
    return p == null ? null : _ativo(p);
  }

  @override
  Future<List<PlanoDaLista>> listarPlanos() async => [
        for (final p in _b.planos)
          PlanoDaLista(
            id: p.id,
            nome: p.nome,
            inicio: DateTime(2026, 10, 1),
            emUso: p.emUso,
            autor: 'Vitor',
            somenteLeitura: false,
            quantidadeFichas: p.fichas.length,
            quantidadeExercicios: 0,
          ),
      ];

  @override
  Future<PlanoAtivo> obterPlano(String planoId) async => _ativo(_b.plano(planoId));

  @override
  Future<PlanoDetalhe> obterDetalhePlano(String planoId) async {
    final p = _b.plano(planoId);
    return PlanoDetalhe(
      id: p.id,
      nome: p.nome,
      inicio: DateTime(2026, 10, 1),
      emUso: p.emUso,
      autor: 'Vitor',
      somenteLeitura: false,
      treinos: List.of(p.fichas),
    );
  }

  @override
  Future<String> garantirPlano() async =>
      (_b.emUso ?? (_b.planos..add(_Plano(_b.novoId('p'), 'Meu plano', emUso: true))).last)
          .id;

  @override
  Future<String> criarPlano(String nome) async {
    final p = _Plano(_b.novoId('p'), nome, emUso: _b.emUso == null);
    _b.planos.add(p);
    return p.id;
  }

  @override
  Future<void> renomearPlano({required String planoId, required String nome}) async =>
      _b.plano(planoId).nome = nome;

  @override
  Future<void> excluirPlano(String planoId) async =>
      _b.planos.removeWhere((p) => p.id == planoId);

  @override
  Future<String> adicionarFicha({
    required String planoId,
    required String nome,
    String? descricao,
  }) async {
    final p = _b.plano(planoId);
    final id = _b.novoId('f');
    p.fichas.add(TreinoResumo(
        id: id, nome: nome, descricao: descricao, ordem: p.fichas.length + 1));
    return id;
  }

  @override
  Future<TreinoDetalhe> obterFicha(String treinoId) async {
    final f = _b.planos.expand((p) => p.fichas).firstWhere((f) => f.id == treinoId);
    return TreinoDetalhe(
        id: f.id, nome: f.nome, descricao: f.descricao, ordem: f.ordem, exercicios: const []);
  }
}

class _SessoesFake extends SessaoRepository {
  _SessoesFake(this._b) : super(Dio());
  final _Banco _b;

  @override
  Future<List<SessaoResumo>> listarSessoes({DateTime? de, DateTime? ate}) async =>
      List.of(_b.sessoes);

  @override
  Future<SessaoDetalhe> obterSessao(String sessaoId) async {
    final s = _b.sessoes.firstWhere((s) => s.id == sessaoId);
    return SessaoDetalhe(
      id: s.id,
      treinoId: s.treinoId,
      treinoNome: s.treinoNome,
      data: s.data,
      duracaoMin: s.duracaoMin,
      observacao: null,
      exercicios: const [],
    );
  }

  @override
  Future<void> excluirSessao(String sessaoId) async =>
      _b.sessoes.removeWhere((s) => s.id == sessaoId);
}

Future<void> _abrirApp(WidgetTester tester, _Banco banco) async {
  // Largura de celular (390) e altura folgada: a fonte de teste (Ahem) é mais
  // larga que a Barlow e quebra mais linhas.
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_Usuario())),
      fichasRepositoryProvider.overrideWithValue(_FichasFake(banco)),
      sessaoRepositoryProvider.overrideWithValue(_SessoesFake(banco)),
    ],
    child: const DiarioTreinoApp(),
  ));
  await _assentar(tester);
}

/// Frames de duração fixa: os fakes respondem na hora, mas um indicador de
/// carregando na aba de fundo travaria o pumpAndSettle.
Future<void> _assentar(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _aba(WidgetTester tester, String nome) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text(nome)));
  await _assentar(tester);
}

Finder _noDialogo(String texto) =>
    find.descendant(of: find.byType(Dialog), matching: find.text(texto));

_Banco _comPlano({bool comSessao = false}) {
  final b = _Banco();
  final p = _Plano('p1', 'Hipertrofia', emUso: true)
    ..fichas.add(const TreinoResumo(id: 'fA', nome: 'A', descricao: null, ordem: 1));
  b.planos.add(p);
  if (comSessao) {
    b.sessoes.add(SessaoResumo(
      id: 's1',
      data: DateTime.now(),
      treinoId: 'fA',
      treinoNome: 'A',
      quantidadeExercicios: 3,
      duracaoMin: 40,
      temObservacao: false,
    ));
  }
  return b;
}

void main() {
  testWidgets('Conta nova: criar a primeira ficha tira a Início do Bem-vindo',
      (tester) async {
    final banco = _Banco();
    await _abrirApp(tester, banco);
    expect(find.text('Seu diário de treino'), findsOneWidget);

    await tester.tap(find.text('MONTAR MINHAS FICHAS'));
    await _assentar(tester);
    await tester.tap(find.text('CRIAR FICHA'));
    await _assentar(tester);
    await tester.enterText(find.byType(TextFormField).first, 'A');
    await tester.tap(_noDialogo('Salvar'));
    await _assentar(tester);

    // Volta pela aba, com a Início viva desde o começo (mesmo scope).
    await _aba(tester, 'Início');
    expect(find.text('Seu diário de treino'), findsNothing);
    expect(find.text('BORA, VITOR'), findsOneWidget);
  });

  testWidgets('Excluir o plano em uso atualiza a Início e a lista na hora',
      (tester) async {
    await _abrirApp(tester, _comPlano());
    expect(find.text('BORA, VITOR'), findsOneWidget);

    await _aba(tester, 'Planos');
    await tester.tap(find.text('HIPERTROFIA'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Excluir plano'));
    await _assentar(tester);
    await tester.tap(_noDialogo('Excluir plano'));
    await _assentar(tester);

    // A lista não mostra mais o plano.
    expect(find.text('HIPERTROFIA'), findsNothing);
    // A Início, que já estava montada, também vê que não há plano.
    await _aba(tester, 'Início');
    expect(find.text('BORA, VITOR'), findsNothing);
    expect(find.text('Seu diário de treino'), findsOneWidget);
  });

  testWidgets('Renomear o plano muda o detalhe e a lista', (tester) async {
    await _abrirApp(tester, _comPlano());

    await _aba(tester, 'Planos');
    await tester.tap(find.text('HIPERTROFIA'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Renomear plano'));
    await _assentar(tester);
    await tester.enterText(find.byType(TextFormField), 'Força');
    await tester.tap(_noDialogo('Salvar'));
    await _assentar(tester);

    expect(find.text('FORÇA'), findsOneWidget); // cabeçalho do detalhe
    await tester.tap(find.byTooltip('Voltar para os planos'));
    await _assentar(tester);
    expect(find.text('FORÇA'), findsOneWidget); // cartão da lista
    expect(find.text('HIPERTROFIA'), findsNothing);
  });

  testWidgets('Excluir a sessão tira o último treino e o dia da semana',
      (tester) async {
    await _abrirApp(tester, _comPlano(comSessao: true));
    expect(find.text('1 dia treinado'), findsOneWidget);
    expect(find.text('ÚLTIMO TREINO'), findsOneWidget);

    await tester.tap(find.text('ÚLTIMO TREINO'));
    await _assentar(tester);
    await tester.tap(find.byTooltip('Excluir treino'));
    await _assentar(tester);
    await tester.tap(_noDialogo('Excluir'));
    await _assentar(tester);

    expect(find.text('0 dias treinados'), findsOneWidget);
    expect(find.text('ÚLTIMO TREINO'), findsNothing);
  });
}
