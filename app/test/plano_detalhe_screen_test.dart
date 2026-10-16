import 'package:dio/dio.dart';
import 'package:diario_treino/core/rotas/app_router.dart';
import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/planos/acoes_plano.dart';
import 'package:diario_treino/features/planos/plano_detalhe_screen.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/features/sessao/treino_em_andamento.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

TreinoResumo _ficha(String id, String nome, int ordem, {String? desc}) =>
    TreinoResumo(id: id, nome: nome, descricao: desc, ordem: ordem);

PlanoDetalhe _plano({
  bool emUso = true,
  List<TreinoResumo>? fichas,
}) =>
    PlanoDetalhe(
      id: 'p1',
      nome: 'Hipertrofia',
      inicio: DateTime(2026, 9, 12),
      emUso: emUso,
      autor: 'Vitor',
      somenteLeitura: false,
      treinos: fichas ??
          [
            _ficha('fa', 'A', 1, desc: 'Peito e tríceps'),
            _ficha('fb', 'B', 2, desc: 'Costas e bíceps'),
            _ficha('fc', 'C', 3, desc: 'Pernas'),
          ],
    );

TreinoExercicioResumo _ex(int ordem) => TreinoExercicioResumo(
      id: 'te$ordem',
      exercicioId: 'e$ordem',
      nome: 'Exercício $ordem',
      grupoMuscular: 'peito',
      modalidade: 'FORCA',
      ordem: ordem,
      rodadas: 3,
      descansoSeg: null,
      instrucao: null,
      alvo: null,
    );

/// A ficha A tem 4 exercícios, a "fv" nenhum; as outras, 5.
int _qtdExercicios(String treinoId) => switch (treinoId) {
      'fa' => 4,
      'fv' => 0,
      _ => 5,
    };

/// Overrides comuns às telas de teste.
List<Override> _overrides(PlanoDetalhe plano,
        {FichasRepository? repo, TreinoEmAndamento? emAndamento}) =>
    [
      treinoEmAndamentoProvider.overrideWithValue(emAndamento),
      planoDetalheProvider.overrideWith((ref, id) async => plano),
      fichaDetalheProvider.overrideWith((ref, treinoId) async => TreinoDetalhe(
            id: treinoId,
            nome: treinoId,
            descricao: null,
            ordem: 1,
            exercicios: [
              for (var i = 1; i <= _qtdExercicios(treinoId); i++) _ex(i),
            ],
          )),
      sessoesRecentesProvider.overrideWith((ref) async => const []),
      if (repo != null) fichasRepositoryProvider.overrideWithValue(repo),
    ];

/// Com rotas de verdade (go_router), para conferir para onde o play e o corpo
/// da linha levam. As telas de destino só mostram o que receberam.
Widget _telaComRotas(PlanoDetalhe plano,
    {FichasRepository? repo, TreinoEmAndamento? emAndamento}) {
  final router = GoRouter(
    initialLocation: Rotas.planoDetalhe,
    routes: [
      GoRoute(
        path: Rotas.planoDetalhe,
        builder: (_, __) => const PlanoDetalheScreen(planoId: 'p1'),
      ),
      GoRoute(
        path: Rotas.fichaDoPlano,
        builder: (_, s) => Scaffold(
            body: Text('Editar ${s.uri.queryParameters['ficha']}')),
      ),
      GoRoute(
        path: Rotas.registrarSessao,
        builder: (_, s) {
          final args = s.extra! as RegistrarSessaoArgs;
          return Scaffold(
            body: Text('Registro ${args.treinoId} '
                '${args.registroPosterior ? 'já feito' : 'agora'}'),
          );
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: _overrides(plano, repo: repo, emAndamento: emAndamento),
    child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
  );
}

/// Repositório que só cria a ficha (devolve o id "fn").
class _RepoCriaFicha extends FichasRepository {
  _RepoCriaFicha() : super(Dio());

  String? criada;

  @override
  Future<String> adicionarFicha({
    required String planoId,
    required String nome,
    String? descricao,
  }) async {
    criada = nome;
    return 'fn';
  }
}

Widget _tela(PlanoDetalhe plano, {ThemeData? tema}) => ProviderScope(
      overrides: [
        treinoEmAndamentoProvider.overrideWithValue(null),
        planoDetalheProvider.overrideWith((ref, id) async => plano),
        // A ficha A tem 4 exercícios; as outras, 5.
        fichaDetalheProvider.overrideWith((ref, treinoId) async => TreinoDetalhe(
              id: treinoId,
              nome: treinoId,
              descricao: null,
              ordem: 1,
              exercicios: [
                for (var i = 1; i <= _qtdExercicios(treinoId); i++) _ex(i),
              ],
            )),
        // Só a ficha A tem sessão registrada (27/09).
        sessoesRecentesProvider.overrideWith((ref) async => [
              SessaoResumo(
                id: 's1',
                data: DateTime(2026, 9, 27),
                treinoId: 'fa',
                treinoNome: 'A',
                quantidadeExercicios: 4,
                duracaoMin: 50,
                temObservacao: false,
              ),
            ]),
      ],
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: const PlanoDetalheScreen(planoId: 'p1'),
      ),
    );

void main() {
  test('Quadrado da ficha: nome curto ou posição na sequência', () {
    expect(rotuloQuadradoFicha('A', 1), 'A');
    expect(rotuloQuadradoFicha('abc', 2), 'ABC');
    expect(rotuloQuadradoFicha('Peito pesado', 4), '4');
    expect(rotuloQuadradoFicha('Dia 1', 1), '1');
  });

  test('Aviso de excluir explica a troca de uso só para o plano em uso', () {
    expect(textoExcluirPlano(emUso: true),
        contains('o uso passa para o último plano que você usou'));
    expect(textoExcluirPlano(emUso: false), isNot(contains('o uso passa')));
  });

  testWidgets('Plano em uso: cabeçalho, fichas com resumo e Nova ficha',
      (tester) async {
    await tester.pumpWidget(_tela(_plano()));
    await tester.pumpAndSettle();

    expect(find.text('PLANO EM USO'), findsOneWidget);
    expect(find.text('HIPERTROFIA'), findsOneWidget);
    expect(find.text('Desde 12/09/2026 · 3 fichas · criado por você'), findsOneWidget);

    // Uma linha por ficha, com quadrado, título e resumo.
    expect(find.text('Peito e tríceps'), findsOneWidget);
    expect(find.text('4 exercícios · último em 27/09'), findsOneWidget);
    expect(find.text('5 exercícios · nunca feito'), findsNWidgets(2));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    expect(find.text('Nova ficha'), findsOneWidget);
    expect(find.text('Duplicar plano'), findsOneWidget);
    // Plano em uso não oferece "Definir como plano em uso".
    expect(find.text('DEFINIR COMO PLANO EM USO'), findsNothing);
  });

  testWidgets('Plano fora de uso oferece "Definir como plano em uso"',
      (tester) async {
    await tester.pumpWidget(_tela(_plano(emUso: false), tema: AppTheme.escuro));
    await tester.pumpAndSettle();

    expect(find.text('PLANO EM USO'), findsNothing);
    await tester.ensureVisible(find.text('DEFINIR COMO PLANO EM USO'));
    expect(find.text('DEFINIR COMO PLANO EM USO'), findsOneWidget);
  });

  testWidgets('Ficha de nome longo mostra a posição no quadrado',
      (tester) async {
    await tester.pumpWidget(_tela(_plano(fichas: [
      _ficha('fa', 'A', 1),
      _ficha('fp', 'Peito pesado', 2),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Peito pesado'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('PBI-58: lápis e lixeira no topo; rodapé só com Duplicar',
      (tester) async {
    await tester.pumpWidget(_tela(_plano()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Renomear plano'), findsOneWidget);
    expect(find.byTooltip('Excluir plano'), findsOneWidget);
    expect(find.text('Renomear'), findsNothing);
    expect(find.text('Excluir plano'), findsNothing);
    expect(find.text('Duplicar plano'), findsOneWidget);

    // Os dois botões têm 44 px.
    final lixeira = tester.getSize(find.byTooltip('Excluir plano'));
    expect(lixeira.width, greaterThanOrEqualTo(44));
    expect(lixeira.height, greaterThanOrEqualTo(44));
  });

  testWidgets('PBI-58: plano do professor não mostra lápis nem lixeira',
      (tester) async {
    final professor = PlanoDetalhe(
      id: 'p9',
      nome: 'Força 5 dias',
      inicio: DateTime(2026, 8, 1),
      emUso: false,
      autor: 'Rafael',
      somenteLeitura: true,
      treinos: [_ficha('fa', 'A', 1)],
    );
    await tester.pumpWidget(_tela(professor));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Renomear plano'), findsNothing);
    expect(find.byTooltip('Excluir plano'), findsNothing);
    expect(find.text('Copiar para editar'), findsOneWidget);
  });

  testWidgets('PBI-61: play abre o sheet de treinar; Cancelar fecha',
      (tester) async {
    await tester.pumpWidget(_telaComRotas(_plano()));
    await tester.pumpAndSettle();

    final play = find.byTooltip('Treinar B');
    expect(play, findsOneWidget);
    expect(tester.getSize(play), const Size(44, 44));

    await tester.tap(play);
    await tester.pumpAndSettle();

    expect(find.text('FICHA 2 · HIPERTROFIA'), findsOneWidget);
    expect(find.text('INICIAR TREINO AGORA'), findsOneWidget);
    expect(find.text('Registrar treino já feito'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('INICIAR TREINO AGORA'), findsNothing);
    expect(find.text('HIPERTROFIA'), findsOneWidget);
  });

  testWidgets('PBI-61: "Iniciar treino agora" abre o treino da ficha',
      (tester) async {
    await tester.pumpWidget(_telaComRotas(_plano()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Treinar A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INICIAR TREINO AGORA'));
    await tester.pumpAndSettle();

    // Testes rodam com TREINO_AO_VIVO=false: cai no registro em andamento.
    expect(find.text('Registro fa agora'), findsOneWidget);
  });

  testWidgets('PBI-61: "Registrar treino já feito" abre o registro manual',
      (tester) async {
    await tester.pumpWidget(_telaComRotas(_plano()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Treinar C'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar treino já feito'));
    await tester.pumpAndSettle();

    expect(find.text('Registro fc já feito'), findsOneWidget);
  });

  testWidgets('PBI-61: corpo da linha abre a edição sem iniciar treino',
      (tester) async {
    await tester.pumpWidget(_telaComRotas(_plano()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Costas e bíceps'));
    await tester.pumpAndSettle();

    expect(find.text('Editar fb'), findsOneWidget);
    expect(find.text('INICIAR TREINO AGORA'), findsNothing);
  });

  testWidgets('PBI-61: ficha vazia deixa o play desabilitado, com o rótulo',
      (tester) async {
    await tester.pumpWidget(_telaComRotas(_plano(fichas: [
      _ficha('fa', 'A', 1),
      _ficha('fv', 'B', 2),
    ])));
    await tester.pumpAndSettle();

    final play = find.byTooltip('B: adicione exercícios para treinar');
    expect(play, findsOneWidget);
    expect(find.byTooltip('Treinar B'), findsNothing);

    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(find.text('INICIAR TREINO AGORA'), findsNothing);
  });

  testWidgets('PBI-61: criar ficha fica no plano com o aviso "Adicionar exercícios"',
      (tester) async {
    final repo = _RepoCriaFicha();
    await tester.pumpWidget(_telaComRotas(_plano(), repo: repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Nova ficha'));
    await tester.tap(find.text('Nova ficha'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'D');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Continua no plano; a ficha não abre sozinha.
    expect(repo.criada, 'D');
    expect(find.text('HIPERTROFIA'), findsOneWidget);
    expect(find.text('Ficha “D” criada'), findsOneWidget);

    await tester.tap(find.text('Adicionar exercícios'));
    await tester.pumpAndSettle();
    expect(find.text('Editar fn'), findsOneWidget);
  });

  testWidgets('Excluir plano em uso explica que o uso passa adiante',
      (tester) async {
    await tester.pumpWidget(_tela(_plano()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Excluir plano'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir plano?'), findsOneWidget);
    expect(find.textContaining('o uso passa para o último plano que você usou'),
        findsOneWidget);
  });

  testWidgets('PBI-67: ficha em andamento fica destacada e o play vira Continuar',
      (tester) async {
    final emAndamento = TreinoEmAndamento(
      treinoId: 'fa',
      treinoNome: 'A',
      treinoLivre: false,
      dataIso: '2026-10-12',
      inicioMillis: DateTime.now()
          .subtract(const Duration(minutes: 5, seconds: 3))
          .millisecondsSinceEpoch,
      exercicios: const [],
    );
    await tester.pumpWidget(_telaComRotas(_plano(), emAndamento: emAndamento));
    await tester.pumpAndSettle();

    // Só a ficha A muda; as outras seguem com o play.
    expect(find.text('Em andamento · '), findsOneWidget);
    expect(find.byTooltip('Treinar A'), findsNothing);
    expect(find.byTooltip('Treinar B'), findsOneWidget);
    expect(
        find.bySemanticsLabel(
            RegExp(r'^Continuar A, em andamento há 5 minutos$')),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Abrir ficha A, em andamento$')),
        findsOneWidget);

    // Continuar retoma (com TREINO_AO_VIVO=false, no registro de uma vez),
    // sem passar pelo sheet de treinar.
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('INICIAR TREINO AGORA'), findsNothing);
    expect(find.text('Registro fa agora'), findsOneWidget);
  });

  testWidgets('PBI-67: destaque confere no tema escuro', (tester) async {
    final emAndamento = TreinoEmAndamento(
      treinoId: 'fb',
      treinoNome: 'B',
      treinoLivre: false,
      dataIso: '2026-10-12',
      inicioMillis: DateTime.now().millisecondsSinceEpoch,
      exercicios: const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_plano(), emAndamento: emAndamento),
      child: MaterialApp(
        theme: AppTheme.escuro,
        home: const PlanoDetalheScreen(planoId: 'p1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Em andamento · '), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byTooltip('Treinar B'), findsNothing);
  });

  for (final escuro in [false, true]) {
    testWidgets(
        'PBI-69: plano sem fichas tem um único estado vazio com "Nova ficha" '
        '(${escuro ? 'escuro' : 'claro'})', (tester) async {
      await tester.pumpWidget(_tela(_plano(fichas: const []),
          tema: escuro ? AppTheme.escuro : AppTheme.claro));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
      expect(find.text('NOVA FICHA'), findsOneWidget);
      // Sem a lista vazia, o botão tracejado e o "Duplicar" de um plano vazio.
      expect(find.text('FICHAS'), findsNothing);
      expect(find.text('Nova ficha'), findsNothing);
      expect(find.text('Duplicar plano'), findsNothing);
      // Nada leva à tela Fichas antiga.
      expect(find.text('MONTAR FICHAS'), findsNothing);
    });
  }

  testWidgets('PBI-69: "Nova ficha" no plano vazio cria e fica no plano',
      (tester) async {
    final repo = _RepoCriaFicha();
    await tester.pumpWidget(
        _telaComRotas(_plano(fichas: const []), repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NOVA FICHA'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Treino A');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repo.criada, 'Treino A');
    // Rota atual continua o detalhe do plano (não abre a ficha sozinha).
    expect(find.byType(PlanoDetalheScreen), findsOneWidget);
    expect(find.textContaining('Editar '), findsNothing);
    expect(find.text('Ficha “Treino A” criada'), findsOneWidget);
  });
}
