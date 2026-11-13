// E2E da PBI-102: treino ao vivo com um bloco conjugado de dois exercícios,
// contra a stack real (Postgres + API + Auth Emulator) num navegador de
// verdade, com o TREINO_AO_VIVO LIGADO. Monta a ficha pela API (comandos do
// próprio app) e exerce pela interface: plano → play → "Iniciar treino agora"
// → bloco → "Rodada feita" (2x) → Resumo → "Salvar treino". No fim, confere na
// API que a sessão gravou uma série por exercício, com o bloco e o descanso só
// na última série de cada rodada.
//
// Mesmo comando do job `e2e`, trocando o --target e ligando a flag:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/bloco_ao_vivo_pbi102_test.dart \
//     --dart-define=TREINO_AO_VIVO=true -d web-server ...
import 'package:diario_treino/app.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/features/catalogo/catalogo_comandos.dart';
import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/fichas/fichas_comandos.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/sessao/descanso_controller.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final passos = <String>[];
  void passo(String s) {
    passos.add(s);
    binding.reportData = {'passos': passos};
    debugPrint('PASSO: $s');
  }

  Future<void> esperarPor(
    WidgetTester tester,
    Finder condicao, {
    int tentativas = 60,
    String? descricao,
  }) async {
    for (var i = 0; i < tentativas; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (condicao.evaluate().isNotEmpty) return;
    }
    final textos =
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((s) => s != null && s.trim().isNotEmpty)
            .toList();
    passo('TIMEOUT ${descricao ?? condicao}: $textos');
    fail(
      'Tempo esgotado esperando por: ${descricao ?? condicao}.\nTextos: $textos',
    );
  }

  /// Rola a lista que contém [referencia] até [alvo] ser construído e visível
  /// (as listas são preguiçosas; os campos de texto também têm Scrollable).
  Future<void> rolarAte(
    WidgetTester tester,
    Finder alvo,
    Finder referencia,
  ) async {
    if (alvo.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        alvo,
        300,
        scrollable:
            find
                .ancestor(of: referencia, matching: find.byType(Scrollable))
                .first,
      );
    }
    await tester.ensureVisible(alvo);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('PBI-102: bloco de dois exercícios no treino ao vivo', (
    tester,
  ) async {
    await app.main();
    await tester.pump(const Duration(seconds: 1));
    await esperarPor(tester, find.byType(DiarioTreinoApp), tentativas: 120);
    await tester.pump(const Duration(seconds: 3));

    final c = ProviderScope.containerOf(
      tester.element(find.byType(DiarioTreinoApp)),
    );
    final comandos = c.read(fichasComandosProvider);
    final catalogo = c.read(catalogoRepositoryProvider);

    // Ficha com dois exercícios (2 séries cada) num bloco de 30 s.
    final sufixo = DateTime.now().millisecondsSinceEpoch;
    final planoId = await comandos.criarPlano('PBI102 $sufixo');
    final fichaId = await comandos.adicionarFicha(planoId: planoId, nome: 'C');
    // Exercícios novos a cada execução: sem treino anterior, o rascunho vem
    // dos alvos da ficha (MER 5.1), e não de uma sessão de outra execução.
    final membro = (await catalogo.listarMembros()).first;
    final ids = <String>[];
    for (final nome in ['Adução E2E ', 'Agachamento E2E ']) {
      ids.add(
        await c
            .read(catalogoComandosProvider)
            .criarExercicio(
              nome: nome,
              membroId: membro.id,
              modalidade: 'FORCA',
              intensidadeMetricaId: 1,
              volumeMetricaId: 10,
            ),
      );
    }
    await comandos.adicionarExercicios(treinoId: fichaId, exercicioIds: ids);
    final ficha = await c.read(fichasRepositoryProvider).obterFicha(fichaId);
    for (final te in ficha.exercicios) {
      await comandos.definirAlvos(
        treinoId: fichaId,
        treinoExercicioId: te.id,
        series: 2,
        intensidadeMetricaId: 1,
        intensidadeAlvo: 20,
        volumeMetricaId: 10,
        volumeAlvo: 12,
      );
    }
    await comandos.criarBloco(
      treinoId: fichaId,
      treinoExercicioIds: ficha.exercicios.map((e) => e.id).toList(),
      descansoSeg: 30,
    );
    passo('ficha montada: ${ficha.exercicios.map((e) => e.nome).toList()}');

    // Plano → play → "Iniciar treino agora".
    final router = c.read(routerProvider);
    router.go(Rotas.fichas);
    await tester.pump(const Duration(seconds: 1));
    router.push('${Rotas.planoDetalhe}?id=$planoId');
    await esperarPor(
      tester,
      find.byTooltip('Treinar C'),
      descricao: 'play da ficha',
    );
    await tester.tap(find.byTooltip('Treinar C'));
    await esperarPor(
      tester,
      find.text('INICIAR TREINO AGORA'),
      descricao: 'sheet de treinar',
    );
    await tester.tap(find.text('INICIAR TREINO AGORA'));
    await esperarPor(
      tester,
      find.text('CONJUGADO'),
      descricao: 'cartão do bloco na tela 14',
    );
    passo('tela 14 com o bloco');

    // Bloco: duas rodadas, um descanso por rodada.
    await tester.tap(find.text('CONJUGADO'));
    await esperarPor(
      tester,
      find.text('Rodada 1 de 2'),
      descricao: 'tela do bloco',
    );
    await rolarAte(
      tester,
      find.text('RODADA FEITA'),
      find.text('RODADA FEITA'),
    );
    await tester.tap(find.text('RODADA FEITA'));
    await esperarPor(tester, find.text('Rodada 2 de 2'), descricao: 'rodada 2');
    expect(
      c.read(descansoControllerProvider)?.total,
      const Duration(seconds: 30),
      reason: 'o descanso do bloco não disparou',
    );
    passo('rodada 1 feita, descanso 30 s');
    // Com a barra de descanso no rodapé, o botão pode ter saído da tela.
    await rolarAte(
      tester,
      find.text('RODADA FEITA'),
      find.text('RODADA FEITA'),
    );
    await tester.tap(find.text('RODADA FEITA'));
    await esperarPor(
      tester,
      find.text('Todas as rodadas feitas.'),
      descricao: 'rodada 2 fechada',
    );

    await rolarAte(
      tester,
      find.text('Concluir e ir ao resumo'),
      find.text('RODADA FEITA'),
    );
    await tester.tap(find.text('Concluir e ir ao resumo'));
    await esperarPor(tester, find.text('SALVAR TREINO'), descricao: 'resumo');
    await tester.tap(find.text('SALVAR TREINO'));
    await esperarPor(
      tester,
      find.textContaining('Treino salvo'),
      descricao: 'treino salvo',
    );
    passo('treino salvo');

    // A sessão gravada: uma série por exercício, bloco 1, posições 1 e 2, e o
    // descanso só na série do agachamento (a última de cada rodada).
    final sessoes = await c.read(sessaoRepositoryProvider).listarSessoes();
    final resumo = sessoes.firstWhere((s) => s.treinoId == fichaId);
    final detalhe = await c
        .read(sessaoRepositoryProvider)
        .obterSessao(resumo.id);
    final porNome = {for (final e in detalhe.exercicios) e.exercicioId: e};
    final primeiro = porNome[ficha.exercicios[0].exercicioId]!;
    final segundo = porNome[ficha.exercicios[1].exercicioId]!;
    passo('séries: ${primeiro.series.length} + ${segundo.series.length}');
    expect(primeiro.series.length, 2);
    expect(segundo.series.length, 2);
    expect(
      primeiro.series.every((s) => s.bloco == 1 && s.posicaoNoBloco == 1),
      isTrue,
    );
    expect(
      segundo.series.every((s) => s.bloco == 1 && s.posicaoNoBloco == 2),
      isTrue,
    );
    expect(primeiro.series.every((s) => s.descansoSeg == null), isTrue);
    expect(segundo.series.every((s) => s.descansoSeg == 30), isTrue);
  });
}
