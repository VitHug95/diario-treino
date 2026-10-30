import 'package:diario_treino/features/educador/alunos_screen.dart';
import 'package:diario_treino/features/educador/convites_screen.dart';
import 'package:diario_treino/features/educador/educador_models.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
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
}
