import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/fichas_screen.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PlanoAtivo _plano(List<TreinoResumo> treinos) =>
    PlanoAtivo(id: 'p1', nome: 'Hipertrofia', treinos: treinos);

TreinoResumo _ficha(String nome, int ordem, {String? desc}) =>
    TreinoResumo(id: 'f$ordem', nome: nome, descricao: desc, ordem: ordem);

TreinoDetalhe _detalhe(String id, List<TreinoExercicioResumo> ex) =>
    TreinoDetalhe(id: id, nome: 'A', descricao: null, ordem: 1, exercicios: ex);

TreinoExercicioResumo _ex(String nome, int ordem) => TreinoExercicioResumo(
      id: 'te$ordem',
      exercicioId: 'e$ordem',
      nome: nome,
      grupoMuscular: 'peito',
      modalidade: 'FORCA',
      ordem: ordem,
      rodadas: 1,
      descansoSeg: null,
      instrucao: null,
      alvo: null,
    );

/// A tela da ficha empilhada sobre uma tela "Plano", como no app: a seta e a
/// ficha inexistente voltam para ela.
Widget _tela({
  required Future<PlanoAtivo?> Function(Ref ref) plano,
  TreinoDetalhe Function(String treinoId)? detalhe,
  String? fichaId,
  bool? temSessoes,
  List<SessaoResumo> sessoes = const [],
  ThemeData? tema,
}) =>
    ProviderScope(
      overrides: [
        planoAtivoProvider.overrideWith(plano),
        // Sem rede nos testes: diz direto se a ficha tem sessões.
        fichaTemSessoesProvider.overrideWith((ref, id) async => temSessoes),
        sessoesRecentesProvider.overrideWith((ref) async => sessoes),
        if (detalhe != null)
          fichaDetalheProvider.overrideWith((ref, treinoId) async => detalhe(treinoId)),
      ],
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: _TelaPlano(fichaId: fichaId),
      ),
    );

class _TelaPlano extends StatefulWidget {
  const _TelaPlano({this.fichaId});
  final String? fichaId;

  @override
  State<_TelaPlano> createState() => _TelaPlanoState();
}

class _TelaPlanoState extends State<_TelaPlano> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FichasScreen(fichaInicialId: widget.fichaId),
      ));
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Tela do plano')));
}

void main() {
  testWidgets('PBI-57: mostra só a ficha aberta, sem chips nem "Nova ficha"',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([
        _ficha('A', 1, desc: 'Peito e tríceps'),
        _ficha('B', 2, desc: 'Costas e bíceps'),
        _ficha('C', 3),
      ]),
      detalhe: (id) => _detalhe(id, [_ex('Remada de $id', 1), _ex('Puxada', 2)]),
      fichaId: 'f2',
      sessoes: [
        SessaoResumo(
          id: 's1',
          data: DateTime(2026, 9, 27),
          treinoId: 'f2',
          treinoNome: 'B',
          quantidadeExercicios: 2,
          duracaoMin: 50,
          temObservacao: false,
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Cabeçalho: plano, ficha B como título e resumo.
    expect(find.text('HIPERTROFIA'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Costas e bíceps'), findsOneWidget);
    expect(find.text('2 exercícios · último em 27/09'), findsOneWidget);
    expect(find.text('Remada de f2'), findsOneWidget);

    // Nada das outras fichas nem do "Nova ficha".
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Peito e tríceps'), findsNothing);
    expect(find.text('Nova ficha'), findsNothing);
    expect(find.text('NOME DA FICHA'), findsNothing);

    // Título da ficha como cabeçalho de semântica.
    expect(
      tester.getSemantics(find.text('B')),
      matchesSemantics(label: 'B', isHeader: true),
    );
  });

  testWidgets('PBI-57: nenhuma ficha tem botões de treinar', (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, [_ex('Supino reto', 1)]),
      fichaId: 'f1',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('INICIAR TREINO AGORA'), findsNothing);
    expect(find.text('Registrar treino já feito'), findsNothing);
    expect(find.text('1 exercício · nunca feito'), findsOneWidget);
  });

  testWidgets('PBI-57: ficha vazia mostra só o estado e o adicionar',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, const []),
      fichaId: 'f1',
      tema: AppTheme.escuro,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ficha sem exercícios'), findsOneWidget);
    expect(find.text('Adicionar exercício à ficha'), findsOneWidget);
    expect(find.text('Adicione exercícios para iniciar.'), findsNothing);
    expect(find.text('INICIAR TREINO AGORA'), findsNothing);
  });

  testWidgets('PBI-57: a seta volta ao plano de origem', (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, const []),
      fichaId: 'f1',
    ));
    await tester.pumpAndSettle();

    final seta = find.byTooltip('Voltar para Hipertrofia');
    expect(seta, findsOneWidget);
    expect(tester.getSize(seta).height, greaterThanOrEqualTo(44));

    await tester.tap(seta);
    await tester.pumpAndSettle();
    expect(find.text('Tela do plano'), findsOneWidget);
  });

  testWidgets('PBI-57: ficha inexistente volta ao plano com o aviso',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1), _ficha('B', 2)]),
      detalhe: (id) => _detalhe(id, const []),
      fichaId: 'nao-existe',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tela do plano'), findsOneWidget);
    expect(find.text('Essa ficha não existe mais'), findsOneWidget);
    expect(find.byType(FichasScreen), findsNothing);
  });

  testWidgets('Sem fichas: estado vazio convida a criar a primeira',
      (tester) async {
    await tester.pumpWidget(_tela(plano: (ref) async => null));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'CRIAR FICHA'), findsOneWidget);
    expect(find.text('Nova ficha'), findsNothing);
  });

  testWidgets('PBI-58: lixeira no topo pede confirmação (ficha com sessões)',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, const []),
      fichaId: 'f1',
      temSessoes: true,
    ));
    await tester.pumpAndSettle();

    // Lápis e lixeira no lugar do menu "⋯".
    expect(find.byTooltip('Mais ações da ficha'), findsNothing);
    expect(find.byTooltip('Renomear ficha'), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir ficha'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir ficha?'), findsOneWidget);
    expect(find.textContaining('ela sai do plano mas o histórico e o gráfico continuam'),
        findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Excluir ficha'), findsOneWidget);
  });

  test('PBI-58: texto de excluir ficha conforme as sessões', () {
    expect(textoExcluirFicha('A', temSessoes: true), contains('sai do plano'));
    expect(textoExcluirFicha('A', temSessoes: false), contains('serão apagados'));
    expect(textoExcluirFicha('A', temSessoes: null),
        contains('continuam no seu histórico'));
  });

  test('Resumo da ficha: contagem e última vez', () {
    expect(resumoFicha(qtdExercicios: 4, ultimaVez: DateTime(2026, 9, 7)),
        '4 exercícios · último em 07/09');
    expect(resumoFicha(qtdExercicios: 1, ultimaVez: null), '1 exercício · nunca feito');
    expect(resumoFicha(qtdExercicios: null, ultimaVez: null), 'nunca feito');
  });
}
