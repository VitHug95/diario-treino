// E2E da PBI-100: salvar os alvos de um exercício e voltar à ficha mostra o
// valor novo na hora, contra a stack real (Postgres + API + Auth Emulator) num
// navegador de verdade. Monta o plano, a ficha e o exercício pela API (pelos
// comandos do próprio app) e exerce a parte que importa pela interface:
// ficha → alvos → +3 séries → SALVAR → ficha.
//
// Mesmo comando do job `e2e`, trocando o --target:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/alvos_ficha_pbi100_test.dart -d web-server ...
import 'package:diario_treino/app.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/fichas/fichas_comandos.dart';
import 'package:diario_treino/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Diário do teste: sai em build/integration_response_data.json (também em
  // release, onde a mensagem de falha vem vazia).
  final passos = <String>[];
  void passo(String s) {
    passos.add(s);
    binding.reportData = {'passos': passos};
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

  testWidgets('PBI-100: salvar 4 séries e voltar à ficha mostra "4 séries"', (
    tester,
  ) async {
    await app.main();
    await tester.pump(const Duration(seconds: 1));
    // Boot + auto-login no emulador + primeira carga.
    await esperarPor(tester, find.byType(DiarioTreinoApp), tentativas: 120);
    await tester.pump(const Duration(seconds: 3));

    final c = ProviderScope.containerOf(
      tester.element(find.byType(DiarioTreinoApp)),
    );
    final comandos = c.read(fichasComandosProvider);

    // Plano, ficha e um exercício do catálogo, pela API real.
    final sufixo = DateTime.now().millisecondsSinceEpoch;
    final planoId = await comandos.criarPlano('PBI100 $sufixo');
    final fichaId = await comandos.adicionarFicha(planoId: planoId, nome: 'A');
    final catalogo = await c
        .read(catalogoRepositoryProvider)
        .buscar(busca: 'Supino reto com barra');
    final exercicio = catalogo.first;
    await comandos.adicionarExercicios(
      treinoId: fichaId,
      exercicioIds: [exercicio.id],
    );

    // Planos → detalhe do plano → ficha, como o atleta faz.
    final router = c.read(routerProvider);
    router.go(Rotas.fichas);
    await tester.pump(const Duration(seconds: 1));
    router.push('${Rotas.planoDetalhe}?id=$planoId');
    await tester.pump(const Duration(seconds: 1));
    router.push('${Rotas.fichaDoPlano}?plano=$planoId&ficha=$fichaId');
    await esperarPor(
      tester,
      find.text(exercicio.nome),
      descricao: 'o exercício na ficha',
    );
    // Exercício recém-adicionado: ainda sem alvos (1 rodada no banco).
    await esperarPor(
      tester,
      find.text('Definir séries e alvos'),
      descricao: 'convite a definir alvos',
    );

    // Alvos: +3 séries e SALVAR.
    await tester.tap(find.text(exercicio.nome));
    await esperarPor(
      tester,
      find.text('Alvos do exercício'),
      descricao: 'tela de alvos',
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel('Mais uma série'));
      await tester.pump(const Duration(milliseconds: 200));
    }
    // A lista é preguiçosa: rola até o SALVAR ser construído.
    await tester.scrollUntilVisible(
      find.text('SALVAR'),
      300,
      scrollable:
          find
              .ancestor(
                of: find.text('Séries'),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    passo('tocando SALVAR');
    await tester.tap(find.text('SALVAR'));

    // De volta à ficha: tem de mostrar 4, sem sair e voltar.
    await esperarPor(
      tester,
      find.text(exercicio.nome),
      descricao: 'de volta à ficha',
    );
    await tester.pump(
      const Duration(seconds: 3),
    ); // tempo de sobra para a recarga
    final textos =
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((s) => s.contains('série'))
            .toList();
    passo('1a volta: $textos');
    expect(
      find.textContaining('4 séries'),
      findsOneWidget,
      reason: 'a ficha ficou com o valor antigo: $textos',
    );

    // 2ª rodada, com alvos já existentes (o caso do PO: "1 série" -> "N séries"):
    // reabre, sobe para 5 e salva de novo.
    await tester.tap(find.text(exercicio.nome));
    await esperarPor(
      tester,
      find.text('Alvos do exercício'),
      descricao: 'tela de alvos (2ª vez)',
    );
    await tester.tap(find.bySemanticsLabel('Mais uma série'));
    await tester.pump(const Duration(milliseconds: 200));
    // A lista é preguiçosa: rola até o SALVAR ser construído.
    await tester.scrollUntilVisible(
      find.text('SALVAR'),
      300,
      scrollable:
          find
              .ancestor(
                of: find.text('Séries'),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('SALVAR'));
    await esperarPor(
      tester,
      find.text(exercicio.nome),
      descricao: 'de volta à ficha (2ª vez)',
    );
    await tester.pump(const Duration(seconds: 3));
    final textos2 =
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .where((s) => s.contains('série'))
            .toList();
    passo('2a volta: $textos2');
    expect(
      find.textContaining('5 séries'),
      findsOneWidget,
      reason: 'a ficha ficou com o valor antigo: $textos2',
    );
  });
}
