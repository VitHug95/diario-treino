import 'package:diario_treino/features/educador/aluno_plano_detalhe_screen.dart';
import 'package:diario_treino/features/educador/aluno_planos_screen.dart';
import 'package:diario_treino/features/educador/educador_repository.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Fake do FichasRepository: registra o que foi pedido, sem rede. Guarda o
/// atletaId recebido ao criar o plano, para o teste conferir o modo educador.
class _FichasFake extends FichasRepository {
  _FichasFake() : super(Dio());

  String? criouNome;
  String? criouParaAtleta;

  @override
  Future<String> criarPlano(String nome, {String? atletaId}) async {
    criouNome = nome;
    criouParaAtleta = atletaId;
    return 'p-novo';
  }

  String? fichaCriada;

  @override
  Future<String> adicionarFicha({
    required String planoId,
    required String nome,
    String? descricao,
  }) async {
    fichaCriada = nome;
    return 't-novo';
  }
}

PlanoDaLista _plano({
  String id = 'p1',
  String nome = 'Força 5 dias',
  bool emUso = true,
  int fichas = 2,
  int exercicios = 8,
}) =>
    PlanoDaLista(
      id: id,
      nome: nome,
      inicio: DateTime(2026, 10, 1),
      emUso: emUso,
      autor: 'Prof. Ana',
      somenteLeitura: true,
      quantidadeFichas: fichas,
      quantidadeExercicios: exercicios,
    );

PlanoDetalhe _detalhe({List<TreinoResumo> treinos = const []}) => PlanoDetalhe(
      id: 'p1',
      nome: 'Força 5 dias',
      inicio: DateTime(2026, 10, 1),
      emUso: true,
      autor: 'Prof. Ana',
      somenteLeitura: true,
      treinos: treinos,
    );

Widget _telaPlanos({
  List<PlanoDaLista> planos = const [],
  FichasRepository? repo,
}) {
  // GoRouter local: a tela usa context.push para abrir o plano criado, então
  // precisa de um roteador com a rota destino (placeholder, não exercitada).
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            const AlunoPlanosScreen(atletaId: 'a1', alunoNome: 'João'),
      ),
      GoRoute(
        path: '/perfil/alunos/aluno/planos/plano',
        builder: (_, __) => const Scaffold(body: Text('detalhe')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      if (repo != null) fichasRepositoryProvider.overrideWithValue(repo),
      planosDoAlunoProvider.overrideWith((ref, atletaId) async => planos),
    ],
    child: MaterialApp.router(
      theme: AppTheme.claro,
      routerConfig: router,
    ),
  );
}

Widget _telaDetalhe({List<TreinoResumo> treinos = const [], FichasRepository? repo}) =>
    ProviderScope(
      overrides: [
        if (repo != null) fichasRepositoryProvider.overrideWithValue(repo),
        planoDoAlunoDetalheProvider
            .overrideWith((ref, arg) async => _detalhe(treinos: treinos)),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        home: const AlunoPlanoDetalheScreen(
            atletaId: 'a1', alunoNome: 'João', planoId: 'p1'),
      ),
    );

void main() {
  // ---- Planos do aluno ----

  testWidgets('Planos do aluno: estado vazio convida a criar', (tester) async {
    await tester.pumpWidget(_telaPlanos());
    await tester.pumpAndSettle();

    expect(find.text('Planos de João'), findsOneWidget);
    expect(find.text('Nenhum plano ainda'), findsOneWidget);
    expect(find.text('CRIAR PLANO'), findsOneWidget);
  });

  testWidgets('Planos do aluno: lista os planos', (tester) async {
    await tester.pumpWidget(_telaPlanos(planos: [_plano()]));
    await tester.pumpAndSettle();

    expect(find.text('FORÇA 5 DIAS'), findsOneWidget);
    expect(find.text('Em uso'), findsOneWidget);
    expect(find.textContaining('2 fichas'), findsOneWidget);
  });

  testWidgets('Planos do aluno: criar plano manda o atletaId para o comando',
      (tester) async {
    final repo = _FichasFake();
    await tester.pumpWidget(_telaPlanos(repo: repo));
    await tester.pumpAndSettle();

    // Abre o diálogo "Novo plano".
    await tester.tap(find.text('CRIAR PLANO'));
    await tester.pumpAndSettle();

    // Confirma com o nome sugerido (o botão do diálogo é o último "CRIAR PLANO").
    await tester.tap(find.text('CRIAR PLANO').last);
    await tester.pumpAndSettle();

    expect(repo.criouParaAtleta, 'a1'); // modo educador: cria para o aluno
    expect(repo.criouNome, 'Meu plano');
  });

  // ---- Detalhe do plano do aluno ----

  testWidgets('Detalhe do plano: estado vazio de fichas', (tester) async {
    await tester.pumpWidget(_telaDetalhe());
    await tester.pumpAndSettle();

    expect(find.text('Força 5 dias'), findsOneWidget); // título (AppBar)
    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
    expect(find.text('NOVA FICHA'), findsOneWidget);
  });

  testWidgets('PBI-75: nova ficha para o aluno confirma na pílula', (tester) async {
    final repo = _FichasFake();
    await tester.pumpWidget(_telaDetalhe(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NOVA FICHA'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'A');
    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(repo.fichaCriada, 'A');
    expect(find.text('Ficha “A” criada'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).shape, isA<StadiumBorder>());
  });

  testWidgets('Detalhe do plano: lista as fichas do plano', (tester) async {
    await tester.pumpWidget(_telaDetalhe(treinos: const [
      TreinoResumo(id: 't1', nome: 'A', descricao: 'Peito', ordem: 1),
      TreinoResumo(id: 't2', nome: 'B', descricao: null, ordem: 2),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Peito'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Nenhuma ficha ainda'), findsNothing);
    expect(find.text('Nova ficha'), findsOneWidget);
  });
}
