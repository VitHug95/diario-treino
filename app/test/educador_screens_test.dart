import 'package:diario_treino/features/educador/aluno_detalhe_screen.dart';
import 'package:diario_treino/features/educador/alunos_screen.dart';
import 'package:diario_treino/features/educador/convites_screen.dart';
import 'package:diario_treino/features/educador/educador_models.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/progresso/progresso_models.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake do repositório: guarda o que foi chamado e devolve dados fixos, sem rede.
class _RepoFake extends EducadorRepository {
  _RepoFake() : super(Dio());

  String? aceitou;
  String? recusou;

  @override
  Future<void> aceitar(String vinculoId) async => aceitou = vinculoId;

  @override
  Future<void> recusar(String vinculoId) async => recusou = vinculoId;
}

Widget _tela(Widget home, {EducadorRepository? repo, List<dynamic>? dados}) =>
    ProviderScope(
      overrides: [
        if (repo != null) educadorRepositoryProvider.overrideWithValue(repo),
        alunosProvider.overrideWith(
            (ref) async => (dados ?? const []).cast<AlunoVinculado>()),
        convitesPendentesProvider.overrideWith(
            (ref) async => (dados ?? const []).cast<ConvitePendente>()),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: home),
    );

/// Monta a tela de detalhe do aluno com os providers de leitura sobrescritos.
Widget telaAluno({
  List<SessaoResumo> sessoes = const [],
  List<ExercicioComHistorico> exercicios = const [],
}) =>
    ProviderScope(
      overrides: [
        sessoesDoAlunoProvider.overrideWith((ref, atletaId) async => sessoes),
        exerciciosDoAlunoProvider
            .overrideWith((ref, atletaId) async => exercicios),
        progressoDoAlunoProvider.overrideWith((ref, atletaId) async => null),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: const AlunoDetalheScreen(atletaId: 'a1', alunoNome: 'João'),
      ),
    );

void main() {
  // ---- Alunos ----

  testWidgets('Alunos: estado vazio convida a convidar', (tester) async {
    await tester.pumpWidget(_tela(const AlunosScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum aluno ainda'), findsOneWidget);
    expect(find.text('Convidar aluno'), findsOneWidget);
  });

  testWidgets('Alunos: lista os alunos vinculados', (tester) async {
    await tester.pumpWidget(_tela(const AlunosScreen(), dados: const [
      AlunoVinculado(
          vinculoId: 'v1', alunoId: 'a1',
          alunoNome: 'João', alunoEmail: 'joao@teste.local'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('João'), findsOneWidget);
    expect(find.text('joao@teste.local'), findsOneWidget);
    expect(find.text('Nenhum aluno ainda'), findsNothing);
  });

  // ---- Convites ----

  testWidgets('Convites: estado vazio quando não há nenhum', (tester) async {
    await tester.pumpWidget(_tela(const ConvitesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum convite'), findsOneWidget);
  });

  testWidgets('Convites: lista o convite com Aceitar e Recusar', (tester) async {
    await tester.pumpWidget(_tela(const ConvitesScreen(), dados: const [
      ConvitePendente(
          vinculoId: 'v1', educadorId: 'e1',
          educadorNome: 'Prof. Ana', educadorEmail: 'ana@teste.local'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Prof. Ana'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Aceitar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Recusar'), findsOneWidget);
  });

  testWidgets('Convites: recusar chama o repositório com o id do vínculo',
      (tester) async {
    final repo = _RepoFake();
    await tester.pumpWidget(_tela(const ConvitesScreen(), repo: repo, dados: const [
      ConvitePendente(
          vinculoId: 'v-123', educadorId: 'e1',
          educadorNome: 'Prof. Ana', educadorEmail: 'ana@teste.local'),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Recusar'));
    await tester.pumpAndSettle();

    expect(repo.recusou, 'v-123');
  });

  testWidgets('Convites: Aceitar passa pelo termo e, ao confirmar, aceita',
      (tester) async {
    final repo = _RepoFake();
    await tester.pumpWidget(_tela(const ConvitesScreen(), repo: repo, dados: const [
      ConvitePendente(
          vinculoId: 'v-9', educadorId: 'e1',
          educadorNome: 'Prof. Ana', educadorEmail: 'ana@teste.local'),
    ]));
    await tester.pumpAndSettle();

    // Toca Aceitar -> abre a tela do termo de consentimento.
    await tester.tap(find.widgetWithText(FilledButton, 'Aceitar'));
    await tester.pumpAndSettle();
    expect(find.text('Termo de consentimento'), findsOneWidget);
    expect(repo.aceitou, isNull); // ainda não aceitou só por abrir o termo.

    // Confirma no termo.
    await tester.tap(find.widgetWithText(FilledButton, 'ACEITAR E ATIVAR'));
    await tester.pumpAndSettle();

    expect(repo.aceitou, 'v-9');
  });

  // ---- Detalhe do aluno (PBI-88c) ----

  testWidgets('Aluno: AppBar com o nome e estado vazio de sessões',
      (tester) async {
    await tester.pumpWidget(telaAluno());
    await tester.pumpAndSettle();

    expect(find.text('João'), findsOneWidget);
    expect(find.text('EVOLUÇÃO'), findsOneWidget);
    expect(find.text('SESSÕES RECENTES'), findsOneWidget);
    expect(find.text('Nenhum treino recente'), findsOneWidget);
    // Sem exercícios com histórico, o seletor mostra a dica.
    expect(find.text('O aluno ainda não tem exercícios com histórico.'),
        findsOneWidget);
  });

  testWidgets('Aluno: lista as sessões recentes do aluno', (tester) async {
    await tester.pumpWidget(telaAluno(sessoes: [
      SessaoResumo(
        id: 's1',
        data: DateTime(2026, 10, 20),
        treinoId: 't1',
        treinoNome: 'Treino A',
        quantidadeExercicios: 5,
        duracaoMin: 50,
        temObservacao: false,
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('20/10/2026'), findsOneWidget);
    expect(find.text('Treino A'), findsOneWidget);
    expect(find.text('Nenhum treino recente'), findsNothing);
  });

  testWidgets('Aluno: seletor lista os exercícios com histórico do aluno',
      (tester) async {
    await tester.pumpWidget(telaAluno(exercicios: const [
      ExercicioComHistorico(id: 'e1', nome: 'Supino reto', modalidade: 'FORCA'),
    ]));
    await tester.pumpAndSettle();

    // Antes de selecionar, o gráfico pede para escolher um exercício.
    expect(find.text('Selecione um exercício para ver a evolução do aluno.'),
        findsOneWidget);
    // Não está no estado "sem exercícios": o seletor (dropdown) foi montado.
    expect(find.text('O aluno ainda não tem exercícios com histórico.'),
        findsNothing);
    expect(find.byType(DropdownButton<String>), findsOneWidget);

    // Abrir o dropdown mostra o exercício como opção.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Supino reto'), findsWidgets);
  });
}
