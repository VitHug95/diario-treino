// E2E do caminho mais importante (PBI-26): entrar, registrar um treino e ver no
// progresso. Roda com integration_test — dirige a árvore de widgets do Flutter
// (tester.enterText/tap), não o DOM do navegador. Isso é necessário porque o
// Flutter web usa CanvasKit (o renderer HTML foi removido no 3.29) e os campos
// de texto não aceitam entrada via DOM de forma confiável (Playwright/Robot).
//
// A stack real sobe no CI (Postgres + API .NET + Firebase Auth Emulator). O
// app entra já autenticado pelo atalho de login do boot (main.dart, só no modo
// emulador), então o teste começa na Início e exerce o fluxo de ponta a ponta.
//
// Build/execução (ver job `e2e` do ci.yml):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/fluxo_pbi26_test.dart -d web-server \
//     --dart-define=API_BASE_URL=... --dart-define=USE_AUTH_EMULATOR=true \
//     --dart-define=TREINO_AO_VIVO=false --dart-define=AUTH_EMULATOR_HOST=... \
//     --dart-define=AUTH_EMULATOR_PORT=9099

import 'package:diario_treino/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Bombeia frames por até [tentativas] × [passo] até [condicao] achar o
  /// widget, sem usar pumpAndSettle (a Início/catálogo mostram
  /// CircularProgressIndicator — animação contínua — enquanto falam com a API
  /// real, e pumpAndSettle expiraria). Falha com mensagem clara se estourar.
  Future<void> esperarPor(
    WidgetTester tester,
    Finder condicao, {
    int tentativas = 60,
    Duration passo = const Duration(milliseconds: 500),
    String? descricao,
  }) async {
    for (var i = 0; i < tentativas; i++) {
      await tester.pump(passo);
      if (condicao.evaluate().isNotEmpty) return;
    }
    // Diagnóstico: no timeout, lista os textos visíveis na tela — para saber o
    // que apareceu no lugar do esperado (ex.: tela de login = auto-login
    // falhou; spinner = ainda carregando; outro texto = finder errado).
    final textos = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((s) => s != null && s.trim().isNotEmpty)
        .toList();
    debugPrint('E2E DIAGNOSTICO — textos na tela no timeout: $textos');
    fail('Tempo esgotado esperando por: ${descricao ?? condicao.toString()}.\n'
        'Textos visíveis na tela: $textos');
  }

  testWidgets('Atleta registra um treino livre e vê no progresso (PBI-26)',
      (tester) async {
    // Sobe o app de verdade: main() faz Firebase init + auto-login no emulador.
    await app.main();
    await tester.pump(const Duration(seconds: 1));

    // 1) Início, já autenticado. Conta nova (sem ficha/sessão) cai no Primeiro
    //    acesso, cujo "Registrar treino" abre direto o treino livre (PBI-71).
    //    Timeout maior: boot + Firebase init + auto-login + 1ª carga dos
    //    providers (API real) no web debug é lento.
    await esperarPor(tester, find.text('Registrar treino'),
        tentativas: 120,
        descricao: 'botão "Registrar treino" na Início');
    await tester.tap(find.text('Registrar treino'));

    // 2) Treino livre (AppBar "Treino livre").
    await esperarPor(tester, find.text('Treino livre'),
        descricao: 'tela "Treino livre"');

    // 3) Adicionar um exercício do catálogo (API real).
    await tester.tap(find.widgetWithText(OutlinedButton, 'Adicionar exercício'));
    await esperarPor(tester, find.text('Adicionar exercícios'),
        descricao: 'seletor de exercícios');

    // Busca pelo nome para reduzir a lista (debounce de 350ms no campo).
    await tester.enterText(find.byType(TextField).first, 'Supino');
    await tester.pump(const Duration(milliseconds: 500));
    await esperarPor(tester, find.text('Supino reto com barra'),
        descricao: 'exercício "Supino reto com barra" no catálogo');

    await tester.tap(find.text('Supino reto com barra'));
    await tester.pump(const Duration(milliseconds: 300));
    await esperarPor(tester, find.text('ADICIONAR 1 EXERCÍCIO'),
        descricao: 'rodapé "ADICIONAR 1 EXERCÍCIO"');
    await tester.tap(find.text('ADICIONAR 1 EXERCÍCIO'));

    // 4) De volta ao treino livre: marcar como feito e preencher a série.
    await esperarPor(tester, find.text('Marcar'),
        descricao: 'ação "Marcar" (sugestão de série)');
    await tester.tap(find.text('Marcar'));
    await tester.pump(const Duration(milliseconds: 300));

    // Campos da série, mirados pelo rótulo (labelText): no seed, a intensidade
    // é "Carga" e o volume "Repetições".
    await esperarPor(tester, find.widgetWithText(TextField, 'Carga'),
        descricao: 'campo "Carga" da série');
    await tester.enterText(find.widgetWithText(TextField, 'Carga'), '30');
    await tester.enterText(find.widgetWithText(TextField, 'Repetições'), '10');
    await tester.pump(const Duration(milliseconds: 300));

    // 5) Finalizar. Como o único exercício está marcado, não há diálogo.
    await tester.tap(find.text('FINALIZAR TREINO'));

    // Pós-salvar (PBI-64): volta à Início com o aviso "Treino salvo".
    await esperarPor(tester, find.text('Treino salvo'),
        descricao: 'aviso "Treino salvo" na Início');

    // 6) Aba Progresso: confirma que o exercício registrado aparece.
    await esperarPor(tester, find.text('Progresso'),
        descricao: 'aba "Progresso" na navegação inferior');
    await tester.tap(find.text('Progresso'));
    await esperarPor(tester, find.text('EVOLUÇÃO'),
        descricao: 'tela de Progresso (seção EVOLUÇÃO)');

    // O exercício aparece no seletor do gráfico (valor selecionado) e/ou no
    // card da sessão ("Treino livre"). Confirma qualquer uma das evidências.
    await esperarPor(tester, find.text('Supino reto com barra'),
        descricao: 'exercício "Supino reto com barra" no Progresso');
    expect(find.text('Supino reto com barra'), findsWidgets);
  });
}
