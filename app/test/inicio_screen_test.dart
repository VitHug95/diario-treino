import 'dart:async';
import 'dart:convert';

import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/auth/auth_service.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/inicio/dicas.dart';
import 'package:diario_treino/features/inicio/inicio_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/features/sessao/treino_ao_vivo_controller.dart';
import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

TreinoResumo _ficha(String nome, int ordem, {String? descricao}) =>
    TreinoResumo(id: nome, nome: nome, descricao: descricao, ordem: ordem);

final _hoje = () {
  final a = DateTime.now();
  return DateTime(a.year, a.month, a.day);
}();

String _dd(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

SessaoResumo _sessao(String id, DateTime data, {String? treino, int exercicios = 3}) =>
    SessaoResumo(
      id: id,
      data: data,
      treinoId: treino,
      treinoNome: treino,
      quantidadeExercicios: exercicios,
      duracaoMin: 45,
      temObservacao: false,
    );

final _planoAB = PlanoAtivo(
  id: 'p1',
  nome: 'Hipertrofia',
  treinos: [
    _ficha('B', 2, descricao: 'Costas'),
    _ficha('A', 1, descricao: 'Peito'),
  ],
);

/// Início com rotas de verdade: os destinos só mostram o que receberam.
Future<Widget> _tela(
  PlanoAtivo? plano, {
  List<SessaoResumo> sessoes = const [],
  Future<List<SessaoResumo>> Function()? carregarSessoes,
  ThemeData? tema,
  Map<String, Object> prefsIniciais = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsIniciais);
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const InicioScreen()),
      GoRoute(
        path: Rotas.registrarSessao,
        builder: (_, s) {
          final a = s.extra! as RegistrarSessaoArgs;
          return Scaffold(
            body: Text('Registro ${a.treinoId} ${_dd(a.data!)} '
                '${a.registroPosterior ? 'já feito' : 'agora'}'),
          );
        },
      ),
      GoRoute(
        path: Rotas.treinoLivre,
        builder: (_, s) => Scaffold(body: Text('Livre ${_dd(s.extra! as DateTime)}')),
      ),
      GoRoute(
        path: Rotas.detalheSessao,
        builder: (_, s) =>
            Scaffold(body: Text('Detalhe ${(s.extra! as DetalheSessaoArgs).sessaoId}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
      planoAtivoProvider.overrideWith((ref) async => plano),
      sessoesRecentesProvider.overrideWith(
          (ref) => carregarSessoes != null ? carregarSessoes() : Future.value(sessoes)),
    ],
    child: MaterialApp.router(theme: tema ?? AppTheme.claro, routerConfig: router),
  );
}

Finder _dia(DateTime d) => find.bySemanticsLabel(RegExp('^Dia ${_dd(d)},'));

void main() {
  testWidgets('Saúda o atleta e alterna o tema', (tester) async {
    await tester.pumpWidget(await _tela(_planoAB));
    await tester.pumpAndSettle();

    expect(find.text('BORA, ATLETA'), findsOneWidget);

    await tester.tap(find.byTooltip('Usar tema escuro'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tema_modo'), 'escuro');
  });

  testWidgets('PBI-68: conta nova (sem plano, sem sessão) mostra o Bem-vindo',
      (tester) async {
    await tester.pumpWidget(await _tela(null));
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsOneWidget);
    expect(find.text('CRIAR MEU PLANO'), findsOneWidget);
    expect(find.text('Registrar treino'), findsOneWidget);
  });

  testWidgets('PBI-68: plano sem fichas e sem sessão: "Montar a primeira ficha"',
      (tester) async {
    const vazio = PlanoAtivo(id: 'p1', nome: 'Meu plano', treinos: []);
    await tester.pumpWidget(await _tela(vazio, tema: AppTheme.escuro));
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsOneWidget);
    expect(find.text('MONTAR A PRIMEIRA FICHA'), findsOneWidget);
    expect(find.text('CRIAR MEU PLANO'), findsNothing);
  });

  testWidgets('PBI-68: sem plano mas com sessões, Início normal com "Crie seu plano"',
      (tester) async {
    await tester.pumpWidget(await _tela(null,
        sessoes: [_sessao('s1', _hoje.subtract(const Duration(days: 1)), treino: 'A')]));
    await tester.pumpAndSettle();

    // Nada de Bem-vindo de tela cheia: o histórico continua visível.
    expect(find.text('Seu diário de treino'), findsNothing);
    expect(find.text('BEM-VINDO DE VOLTA'), findsOneWidget);
    expect(find.text('CRIE SEU PLANO'), findsOneWidget);
    expect(find.text('CRIAR PLANO'), findsOneWidget);
    expect(find.text('ÚLTIMO TREINO'), findsOneWidget);
    // O card fica acima da semana.
    expect(tester.getTopLeft(find.text('CRIE SEU PLANO')).dy,
        lessThan(tester.getTopLeft(find.text('ESTA SEMANA')).dy));
  });

  testWidgets('PBI-68: com treino em andamento, "Continuar" vem antes de "Crie seu plano"',
      (tester) async {
    final rascunho = TreinoEmAndamento(
      treinoId: null,
      treinoNome: 'Treino livre',
      treinoLivre: true,
      dataIso: '2026-10-12',
      inicioMillis: DateTime.now().millisecondsSinceEpoch,
      exercicios: const [],
    );
    await tester.pumpWidget(await _tela(null,
        sessoes: [_sessao('s1', _hoje.subtract(const Duration(days: 1)))],
        prefsIniciais: {'treino_em_andamento': jsonEncode(rascunho.paraJson())}));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Continuar treino')).dy,
        lessThan(tester.getTopLeft(find.text('CRIE SEU PLANO')).dy));
  });

  testWidgets('Plano em uso sem fichas, mas com sessão: convida a montar',
      (tester) async {
    const vazio = PlanoAtivo(id: 'p1', nome: 'Meu plano', treinos: []);
    await tester.pumpWidget(await _tela(vazio,
        sessoes: [_sessao('s1', _hoje.subtract(const Duration(days: 1)))]));
    await tester.pumpAndSettle();

    expect(find.text('Seu diário de treino'), findsNothing);
    expect(find.text('Monte suas fichas'), findsOneWidget);
  });

  testWidgets('PBI-59: semana e último treino, sem sugestão nem lista de fichas',
      (tester) async {
    await tester.pumpWidget(await _tela(_planoAB, sessoes: [
      _sessao('s1', _hoje, treino: 'A', exercicios: 4),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('SUGESTÃO DE HOJE'), findsNothing);
    expect(find.text('SUAS FICHAS'), findsNothing);
    expect(find.text('INICIAR TREINO'), findsNothing);

    expect(find.text('ESTA SEMANA'), findsOneWidget);
    expect(find.text('1 dia treinado'), findsOneWidget);
    expect(find.text('ÚLTIMO TREINO'), findsOneWidget);
    expect(find.text('${dataCurtaInicio(_hoje)} · 4 exercícios'), findsOneWidget);

    // Estado do dia em texto (não só cor).
    expect(find.bySemanticsLabel('Dia ${_dd(_hoje)}, treino registrado'), findsOneWidget);
  });

  testWidgets('PBI-59: dias da semana com alvos de 44 px em 360 de largura',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _tela(_planoAB, tema: AppTheme.escuro));
    await tester.pumpAndSettle();

    final rotulo = _dia(_hoje);
    expect(rotulo, findsOneWidget);
    final tamanho = tester.getSize(rotulo);
    expect(tamanho.width, greaterThanOrEqualTo(44));
    expect(tamanho.height, greaterThanOrEqualTo(44));
  });

  testWidgets('PBI-59: dia futuro não responde ao toque', (tester) async {
    await tester.pumpWidget(await _tela(_planoAB));
    await tester.pumpAndSettle();

    // Domingo não tem dia futuro na semana: o teste só vale nos outros dias.
    if (_hoje.weekday == DateTime.sunday) return;
    final amanha = _hoje.add(const Duration(days: 1));
    expect(find.bySemanticsLabel('Dia ${_dd(amanha)}, ainda não chegou'), findsOneWidget);

    await tester.tap(_dia(amanha));
    await tester.pumpAndSettle();
    expect(find.text(dataCurtaInicio(amanha)), findsNothing);
  });

  testWidgets('PBI-59: dia sem treino abre a folha; ficha abre o registro do dia',
      (tester) async {
    await tester.pumpWidget(await _tela(_planoAB));
    await tester.pumpAndSettle();

    await tester.tap(_dia(_hoje));
    await tester.pumpAndSettle();

    // Folha com o dia como título e as fichas do plano em uso, na ordem.
    expect(find.text(dataCurtaInicio(_hoje)), findsOneWidget);
    expect(
      tester.getSemantics(find.text(dataCurtaInicio(_hoje))),
      matchesSemantics(label: dataCurtaInicio(_hoje), isHeader: true),
    );
    expect(find.text('REGISTRADO'), findsNothing);
    expect(find.text('REGISTRAR TREINO NESTE DIA'), findsOneWidget);
    expect(find.text('Fichas do plano Hipertrofia'), findsOneWidget);
    expect(find.text('Sem ficha'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Peito')).dy,
        lessThan(tester.getTopLeft(find.text('Costas')).dy));

    await tester.tap(find.text('Costas'));
    await tester.pumpAndSettle();
    expect(find.text('Registro B ${_dd(_hoje)} já feito'), findsOneWidget);
  });

  testWidgets('PBI-59: dia com treino mostra "Registrado" e abre o detalhe',
      (tester) async {
    await tester.pumpWidget(await _tela(_planoAB, sessoes: [
      _sessao('s9', _hoje, treino: 'A'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(_dia(_hoje));
    await tester.pumpAndSettle();

    expect(find.text('REGISTRADO'), findsOneWidget);
    expect(find.text('REGISTRAR OUTRO TREINO NESTE DIA'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Ver treino A'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe s9'), findsOneWidget);
  });

  testWidgets('PBI-59: "Sem ficha" abre o treino livre com a data do dia',
      (tester) async {
    await tester.pumpWidget(await _tela(_planoAB));
    await tester.pumpAndSettle();

    await tester.tap(_dia(_hoje));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sem ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Livre ${_dd(_hoje)}'), findsOneWidget);
  });

  testWidgets('PBI-59: último treino abre o detalhe; sem sessões não aparece',
      (tester) async {
    await tester.pumpWidget(await _tela(_planoAB, sessoes: [
      _sessao('s1', _hoje.subtract(const Duration(days: 9)), treino: 'A'),
      _sessao('s2', _hoje.subtract(const Duration(days: 8))), // livre, mais recente
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Treino livre'), findsOneWidget);
    await tester.tap(find.text('ÚLTIMO TREINO'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhe s2'), findsOneWidget);
  });

  testWidgets('PBI-60: cartão com a dica de treino do acesso', (tester) async {
    await tester.pumpWidget(await _tela(_planoAB, tema: AppTheme.escuro));
    await tester.pumpAndSettle();

    expect(find.text('DICA DE TREINO'), findsOneWidget);
    expect(find.text(dicasDeTreino.first), findsOneWidget);
    expect(find.bySemanticsLabel('Dica de treino: ${dicasDeTreino.first}'), findsOneWidget);
  });

  testWidgets('PBI-59: sem sessões, não há cartão de último treino', (tester) async {
    await tester.pumpWidget(await _tela(_planoAB));
    await tester.pumpAndSettle();

    expect(find.text('ESTA SEMANA'), findsOneWidget);
    expect(find.text('0 dias treinados'), findsOneWidget);
    expect(find.text('ÚLTIMO TREINO'), findsNothing);
  });

  testWidgets('PBI-59: erro no histórico avisa com "Tentar de novo", sem semana',
      (tester) async {
    await tester.pumpWidget(await _tela(_planoAB,
        carregarSessoes: () => Future.error(Exception('sem rede'))));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar seu histórico.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(_dia(_hoje), findsNothing);
    expect(find.textContaining('dias treinados'), findsNothing);
  });

  testWidgets('Enquanto o histórico carrega, não mostra semana falsa', (tester) async {
    await tester.pumpWidget(await _tela(_planoAB,
        carregarSessoes: () => Completer<List<SessaoResumo>>().future));
    // pump (não pumpAndSettle: o future fica pendente de propósito).
    await tester.pump();
    await tester.pump();

    expect(find.text('ESTA SEMANA'), findsOneWidget);
    expect(_dia(_hoje), findsNothing);
  });

  group('PBI-67: treino em andamento na Início', () {
    ExercicioEmAndamento ex(String id) => ExercicioEmAndamento(
          treinoExercicioId: 'te$id',
          exercicioId: id,
          nome: 'Exercício $id',
          modalidade: 'FORCA',
          origemPreenchimento: null,
          foraDaFicha: false,
          realizado: false,
          series: const [],
        );

    testWidgets('iniciar já mostra o card, com 0 séries; encerrar tira',
        (tester) async {
      await tester.pumpWidget(await _tela(_planoAB));
      await tester.pumpAndSettle();
      expect(find.text('Continuar treino'), findsNothing);

      final container =
          ProviderScope.containerOf(tester.element(find.byType(InicioScreen)));
      container.read(treinoAoVivoControllerProvider.notifier).iniciar(
            treinoId: 'A',
            treinoNome: 'A',
            treinoLivre: false,
            data: _hoje,
            exercicios: [ex('1').paraEdicao(), ex('2').paraEdicao()],
          );
      await tester.pumpAndSettle();

      // Sem invalidar nada: o card nasce do treino ao vivo.
      expect(find.text('Continuar treino'), findsOneWidget);
      expect(find.text('0 de 2 exercícios marcados'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              RegExp('^Continuar treino A, em andamento há 0 minutos')),
          findsOneWidget);

      container.read(treinoAoVivoControllerProvider.notifier).encerrar();
      await tester.pumpAndSettle();
      expect(find.text('Continuar treino'), findsNothing);
    });

    testWidgets('app reaberto: o rascunho do aparelho ainda mostra o card',
        (tester) async {
      final rascunho = TreinoEmAndamento(
        treinoId: 'B',
        treinoNome: 'B',
        treinoLivre: false,
        dataIso: '2026-10-12',
        inicioMillis: DateTime.now()
            .subtract(const Duration(minutes: 12, seconds: 5))
            .millisecondsSinceEpoch,
        exercicios: [ex('1')],
      );
      await tester.pumpWidget(await _tela(_planoAB, prefsIniciais: {
        'treino_em_andamento': jsonEncode(rascunho.paraJson()),
      }));
      await tester.pumpAndSettle();

      expect(find.text('Continuar treino'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              RegExp('^Continuar treino B, em andamento há 12 minutos')),
          findsOneWidget);
    });
  });
}
