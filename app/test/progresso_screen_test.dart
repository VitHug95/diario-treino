import 'package:diario_treino/features/progresso/progresso_models.dart';
import 'package:diario_treino/features/progresso/progresso_repository.dart';
import 'package:diario_treino/features/progresso/progresso_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SessaoResumo _sessao({
  required String id,
  required DateTime data,
  String? treinoNome,
  int exercicios = 2,
  int? duracao,
  bool obs = false,
}) =>
    SessaoResumo(
      id: id,
      data: data,
      treinoId: treinoNome == null ? null : 't-$id',
      treinoNome: treinoNome,
      quantidadeExercicios: exercicios,
      duracaoMin: duracao,
      temObservacao: obs,
    );

ExercicioComHistorico _exercicio(String id, String nome) =>
    ExercicioComHistorico(id: id, nome: nome, modalidade: 'FORCA');

ProgressoExercicio _progressoCarga() => ProgressoExercicio(
      exercicioId: 'e1',
      nome: 'Supino',
      modalidade: 'FORCA',
      metrica: 'CARGA',
      pontos: [
        PontoProgresso(data: DateTime(2026, 10, 1), valor: 40, repeticoes: 10),
        PontoProgresso(data: DateTime(2026, 10, 8), valor: 45, repeticoes: 8),
        PontoProgresso(data: DateTime(2026, 10, 15), valor: 50, repeticoes: 6),
      ],
      resumo: const ResumoProgresso(
          sessoes: 3, variacao: 10, sessoesComObservacao: 1),
    );

/// Monta a tela controlando os três providers que ela observa. Por padrão não
/// há exercício selecionado nem lista de exercícios, para os testes do PBI-22
/// continuarem valendo sem precisar de dados do gráfico.
Widget _tela({
  List<SessaoResumo> sessoes = const [],
  List<ExercicioComHistorico> exercicios = const [],
  ProgressoExercicio? progresso,
  String? selecionado,
}) =>
    ProviderScope(
      overrides: [
        sessoesDoPeriodoProvider.overrideWith((ref) async => sessoes),
        exerciciosComHistoricoProvider.overrideWith((ref) async => exercicios),
        progressoDoExercicioProvider.overrideWith((ref) async => progresso),
        if (selecionado != null)
          exercicioSelecionadoProvider.overrideWith(
            () => _SelecionadoFixo(selecionado),
          ),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: const ProgressoScreen()),
    );

class _SelecionadoFixo extends ExercicioSelecionadoController {
  _SelecionadoFixo(this._inicial);
  final String _inicial;
  @override
  String? build() => _inicial;
}

void main() {
  group('Lista de sessões (PBI-22)', () {
    testWidgets('Lista sessões com ficha, detalhes e selo Obs', (tester) async {
      await tester.pumpWidget(_tela(sessoes: [
        _sessao(
          id: '1',
          data: DateTime(2026, 10, 13),
          treinoNome: 'A',
          exercicios: 3,
          duracao: 45,
          obs: true,
        ),
        _sessao(
          id: '2',
          data: DateTime(2026, 10, 11),
          treinoNome: 'B',
          exercicios: 2,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('3 exercícios · 45 min'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('2 exercícios'), findsOneWidget);
      expect(find.text('Obs.'), findsOneWidget);
    });

    testWidgets('Sessão sem ficha aparece como Treino livre', (tester) async {
      await tester.pumpWidget(_tela(sessoes: [
        _sessao(id: '1', data: DateTime(2026, 10, 13), exercicios: 1),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Treino livre'), findsOneWidget);
      expect(find.text('1 exercício'), findsOneWidget);
    });

    testWidgets('Período sem sessões mostra estado vazio', (tester) async {
      await tester.pumpWidget(_tela());
      await tester.pumpAndSettle();

      expect(find.text('Nenhum treino neste período'), findsOneWidget);
    });

    testWidgets('Mostra o seletor de período (15/30/90 dias)', (tester) async {
      await tester.pumpWidget(_tela());
      await tester.pumpAndSettle();

      expect(find.text('15 dias'), findsOneWidget);
      expect(find.text('30 dias'), findsOneWidget);
      expect(find.text('90 dias'), findsOneWidget);
    });
  });

  group('Gráfico de evolução (PBI-20)', () {
    testWidgets('Sem exercício selecionado, pede para selecionar',
        (tester) async {
      await tester.pumpWidget(_tela(
        exercicios: [_exercicio('e1', 'Supino')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Selecione um exercício'), findsOneWidget);
      expect(
          find.text('Selecione um exercício para ver sua evolução.'),
          findsOneWidget);
      // Não desenha gráfico sem seleção.
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('Sem histórico, o seletor avisa', (tester) async {
      await tester.pumpWidget(_tela());
      await tester.pumpAndSettle();

      expect(
          find.text('Nenhum exercício com histórico ainda.'), findsOneWidget);
    });

    testWidgets('Com exercício selecionado e dados, desenha o gráfico de carga',
        (tester) async {
      await tester.pumpWidget(_tela(
        exercicios: [_exercicio('e1', 'Supino')],
        selecionado: 'e1',
        progresso: _progressoCarga(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      // Título do eixo pela métrica CARGA.
      expect(find.text('Carga (kg)'), findsOneWidget);
      // Resumo: 3 sessões, variação e sessões com observação.
      expect(find.textContaining('3 sessões'), findsOneWidget);
      expect(find.textContaining('+10 kg'), findsOneWidget);
      expect(find.textContaining('1 com obs.'), findsOneWidget);
    });

    testWidgets('Isometria usa título de tempo', (tester) async {
      final iso = ProgressoExercicio(
        exercicioId: 'e2',
        nome: 'Prancha',
        modalidade: 'ISOMETRIA',
        metrica: 'TEMPO',
        pontos: [
          PontoProgresso(data: DateTime(2026, 10, 1), valor: 30, repeticoes: null),
          PontoProgresso(data: DateTime(2026, 10, 8), valor: 45, repeticoes: null),
        ],
        resumo: const ResumoProgresso(
            sessoes: 2, variacao: 15, sessoesComObservacao: 0),
      );
      await tester.pumpWidget(_tela(
        exercicios: [_exercicio('e2', 'Prancha')],
        selecionado: 'e2',
        progresso: iso,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Tempo (s)'), findsOneWidget);
    });

    testWidgets('Exercício sem dados no período mostra estado vazio',
        (tester) async {
      final vazio = ProgressoExercicio(
        exercicioId: 'e1',
        nome: 'Supino',
        modalidade: 'FORCA',
        metrica: 'CARGA',
        pontos: const [],
        resumo: const ResumoProgresso(
            sessoes: 0, variacao: null, sessoesComObservacao: 0),
      );
      await tester.pumpWidget(_tela(
        exercicios: [_exercicio('e1', 'Supino')],
        selecionado: 'e1',
        progresso: vazio,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sem dados no período para este exercício.'),
          findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });
  });
}
