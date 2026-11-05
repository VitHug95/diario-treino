import 'package:diario_treino/features/educador/aluno_detalhe_screen.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/progresso/progresso_models.dart';
import 'package:diario_treino/features/progresso/progresso_repository.dart';
import 'package:diario_treino/features/progresso/progresso_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Fake que registra os parâmetros da exportação de PDF, sem rede.
class _ProgressoFake extends ProgressoRepository {
  _ProgressoFake() : super(Dio());

  bool chamou = false;
  String? atletaIdRecebido;
  DateTime? deRecebido;

  @override
  Future<List<int>> baixarProgressoPdf({
    DateTime? de,
    DateTime? ate,
    String? atletaId,
  }) async {
    chamou = true;
    atletaIdRecebido = atletaId;
    deRecebido = de;
    return const [37, 80, 68, 70]; // "%PDF" — bytes fictícios.
  }
}

void main() {
  testWidgets('Progresso: botão Exportar PDF aparece e chama o repositório sem atletaId',
      (tester) async {
    final repo = _ProgressoFake();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        progressoRepositoryProvider.overrideWithValue(repo),
        sessoesDoPeriodoProvider.overrideWith((ref) async => const <SessaoResumo>[]),
        exerciciosComHistoricoProvider
            .overrideWith((ref) async => const <ExercicioComHistorico>[]),
        progressoDoExercicioProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: const ProgressoScreen()),
    ));
    await tester.pumpAndSettle();

    final botao = find.byTooltip('Exportar progresso em PDF');
    expect(botao, findsOneWidget);

    await tester.tap(botao);
    await tester.pump(); // dispara o clique e o setState de "gerando"
    await tester.pumpAndSettle();

    expect(repo.chamou, isTrue);
    // Aba Progresso: exporta o próprio atleta (sem atletaId) e com período.
    expect(repo.atletaIdRecebido, isNull);
    expect(repo.deRecebido, isNotNull);
  });

  testWidgets('Aluno: botão Exportar PDF chama o repositório com o atletaId do aluno',
      (tester) async {
    final repo = _ProgressoFake();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        progressoRepositoryProvider.overrideWithValue(repo),
        sessoesDoAlunoProvider.overrideWith((ref, atletaId) async => const <SessaoResumo>[]),
        exerciciosDoAlunoProvider
            .overrideWith((ref, atletaId) async => const <ExercicioComHistorico>[]),
        progressoDoAlunoProvider.overrideWith((ref, atletaId) async => null),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: const AlunoDetalheScreen(atletaId: 'a-77', alunoNome: 'João'),
      ),
    ));
    await tester.pumpAndSettle();

    final botao = find.byTooltip('Exportar progresso em PDF');
    expect(botao, findsOneWidget);
    expect(find.byIcon(LucideIcons.download), findsOneWidget);

    await tester.tap(botao);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.chamou, isTrue);
    expect(repo.atletaIdRecebido, 'a-77');
  });
}
