import 'package:dio/dio.dart';
import 'package:diario_treino/core/localizacao/material_pt.dart';
import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/exercicio_resumo.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
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
        localizationsDelegates: LocalizacoesPt.delegates,
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

  testWidgets('PBI-69: sem ficha para abrir, volta ao plano sem estado vazio',
      (tester) async {
    await tester.pumpWidget(_tela(plano: (ref) async => _plano(const [])));
    await tester.pumpAndSettle();

    // A tela Fichas antiga sem plano não existe mais: nada de "Criar ficha".
    expect(find.text('Tela do plano'), findsOneWidget);
    expect(find.byType(FichasScreen), findsNothing);
    expect(find.text('CRIAR FICHA'), findsNothing);
    expect(find.text('Essa ficha não existe mais'), findsNothing);
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

  testWidgets('PBI-62: uma alça e um remover por cartão, 44 px, em 360 de largura',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, [_ex('Supino reto', 1), _ex('Crucifixo', 2)]),
      fichaId: 'f1',
      tema: AppTheme.escuro,
    ));
    await tester.pumpAndSettle();

    // Sem a alça automática do Flutter (o "=" extra).
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byTooltip('Remover da ficha'), findsNothing);

    final remover = find.byTooltip('Remover Supino reto da ficha');
    expect(remover, findsOneWidget);
    expect(find.byTooltip('Remover Crucifixo da ficha'), findsOneWidget);
    expect(tester.getSize(remover), const Size(44, 44));

    final alca = find.byWidgetPredicate((w) =>
        w is Semantics && w.properties.label == 'Arrastar para reordenar Supino reto');
    expect(alca, findsOneWidget);
    expect(tester.getSize(alca), const Size(36, 44));
    // Alça e lixeira não se sobrepõem.
    expect(tester.getRect(alca).right, lessThan(tester.getRect(remover).left));
  });

  testWidgets('PBI-62: "Mover para baixo" reordena e persiste', (tester) async {
    final repo = _RepoReordena();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        planoAtivoProvider.overrideWith((ref) async => _plano([_ficha('A', 1)])),
        sessoesRecentesProvider.overrideWith((ref) async => const []),
        fichaDetalheProvider.overrideWith((ref, id) async =>
            _detalhe(id, [_ex('Supino reto', 1), _ex('Crucifixo', 2)])),
        fichasRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        localizationsDelegates: LocalizacoesPt.delegates,
        home: const _TelaPlano(fichaId: 'f1'),
      ),
    ));
    await tester.pumpAndSettle();

    // Ações de semântica de cada cartão, em português.
    final acoes = tester
        .widgetList<Semantics>(find.byWidgetPredicate((w) =>
            w is Semantics &&
            (w.properties.customSemanticsActions?.isNotEmpty ?? false)))
        .map((s) => s.properties.customSemanticsActions!)
        .toList();
    expect(acoes, hasLength(2));
    final primeiro = {for (final e in acoes.first.entries) e.key.label: e.value};
    final ultimo = acoes.last.keys.map((a) => a.label);
    expect(primeiro.keys, contains('Mover para baixo'));
    expect(primeiro.keys, isNot(contains('Mover para cima')));
    expect(ultimo, contains('Mover para cima'));

    primeiro['Mover para baixo']!();
    await tester.pumpAndSettle();
    expect(repo.ordem, ['te2', 'te1']);
  });

  testWidgets('PBI-49: adiciona vários na ordem; falha parcial avisa qual não entrou',
      (tester) async {
    final repo = _RepoAdiciona(falha: 'Crucifixo');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        planoAtivoProvider.overrideWith((ref) async => _plano([_ficha('A', 1)])),
        sessoesRecentesProvider.overrideWith((ref) async => const []),
        fichaDetalheProvider.overrideWith((ref, id) async => _detalhe(id, const [])),
        fichasRepositoryProvider.overrideWithValue(repo),
        catalogoProvider.overrideWith((ref) async => [
              _resumo('Supino reto'),
              _resumo('Crucifixo'),
              _resumo('Remada'),
            ]),
        membrosProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.claro,
        localizationsDelegates: LocalizacoesPt.delegates,
        home: const _TelaPlano(fichaId: 'f1'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar exercício à ficha'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsWidgets); // destino acima do título
    await tester.tap(find.text('Remada'));
    await tester.tap(find.text('Crucifixo'));
    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADICIONAR 3 EXERCÍCIOS'));
    await tester.pumpAndSettle();

    expect(repo.tentados, ['Remada', 'Crucifixo', 'Supino reto']);
    expect(find.text('Não foi possível adicionar: Crucifixo. Tente de novo.'), findsOneWidget);
  });

  test('Resumo da ficha: contagem e última vez', () {
    expect(resumoFicha(qtdExercicios: 4, ultimaVez: DateTime(2026, 9, 7)),
        '4 exercícios · último em 07/09');
    expect(resumoFicha(qtdExercicios: 1, ultimaVez: null), '1 exercício · nunca feito');
    expect(resumoFicha(qtdExercicios: null, ultimaVez: null), 'nunca feito');
  });

  // ---- PBI-79: resumo do alvo no card da ficha ----

  testWidgets('PBI-79: resumo mostra a faixa de repetições e "65 kg"', (tester) async {
    for (final tema in [AppTheme.claro, AppTheme.escuro]) {
      await tester.pumpWidget(_telaComMetricas(
        detalhe: (id) => _detalhe(id, [
          _exComAlvo('Crucifixo inclinado', rodadas: 3, descansoSeg: 120,
              volumeAlvo: 8, volumeAlvoMax: 12, intensidadeAlvo: 65),
        ]),
        tema: tema,
      ));
      await tester.pumpAndSettle();

      // Faixa de repetições, carga com unidade "kg" (não "carga") e descanso.
      expect(find.text('3 séries · 8 a 12 rep · 65 kg · 120 s'), findsOneWidget);
      expect(find.textContaining('carga'), findsNothing);
    }
  });

  testWidgets('PBI-79: alvo sem máximo aparece sem faixa', (tester) async {
    await tester.pumpWidget(_telaComMetricas(
      detalhe: (id) => _detalhe(id, [
        _exComAlvo('Supino reto', rodadas: 3, descansoSeg: null,
            volumeAlvo: 8, volumeAlvoMax: null, intensidadeAlvo: 50),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3 séries · 8 rep · 50 kg'), findsOneWidget);
  });

  testWidgets('PBI-79: exercício de peso corporal não mostra "carga"', (tester) async {
    await tester.pumpWidget(_telaComMetricas(
      detalhe: (id) => _detalhe(id, [
        _exComAlvo('Flexão', rodadas: 4, descansoSeg: 60,
            volumeAlvo: 15, volumeAlvoMax: null, intensidadeAlvo: null,
            intensidadeCodigo: 'PESO_CORPORAL', intensidadeNome: 'Peso corporal'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('4 séries · 15 rep · 60 s'), findsOneWidget);
    expect(find.textContaining('carga'), findsNothing);
    expect(find.textContaining('peso corporal'), findsNothing);
  });

  // ---- PBI-78: o editor abre com o dado ATUAL da ficha, não um capturado ----

  testWidgets('PBI-78: tocar no cartão abre o editor com os valores gravados',
      (tester) async {
    // O provider devolve o alvo gravado (3 séries, 8 a 12, 65 kg). O editor,
    // ao abrir, deve mostrar esses valores — não um estado em branco.
    await tester.pumpWidget(_telaComMetricas(
      detalhe: (id) => _detalhe(id, [
        _exComAlvo('Crucifixo inclinado', rodadas: 3, descansoSeg: 120,
            volumeAlvo: 8, volumeAlvoMax: 12, intensidadeAlvo: 65),
      ]),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crucifixo inclinado'));
    await tester.pumpAndSettle();

    // Abriu o editor com os valores gravados, não em branco. O topo do editor
    // mostra "3 séries" e a carga 65 (um editor em branco teria "1" e vazios).
    expect(find.text('Alvos do exercício'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // contador de séries
    final valores = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((t) => t.controller?.text ?? '')
        .toList();
    expect(valores, contains('65')); // campo de carga, preenchido
  });
}

/// Métricas do seed (unidades reais) para o resumo do alvo (PBI-79).
const _metricasSeed = [
  Metrica(id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE'),
  Metrica(id: 2, codigo: 'PESO_CORPORAL', nome: 'Peso corporal', unidade: '-', eixo: 'INTENSIDADE'),
  Metrica(id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: 'rep', eixo: 'VOLUME'),
  Metrica(id: 11, codigo: 'TEMPO_SEG', nome: 'Tempo', unidade: 's', eixo: 'VOLUME'),
];

/// Tela da ficha com `metricasProvider` resolvido (para o resumo do alvo).
Widget _telaComMetricas({
  required TreinoDetalhe Function(String treinoId) detalhe,
  ThemeData? tema,
}) =>
    ProviderScope(
      overrides: [
        planoAtivoProvider.overrideWith((ref) async => _plano([_ficha('A', 1)])),
        sessoesRecentesProvider.overrideWith((ref) async => const []),
        metricasProvider.overrideWith((ref) async => _metricasSeed),
        fichaDetalheProvider.overrideWith((ref, treinoId) async => detalhe(treinoId)),
      ],
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        localizationsDelegates: LocalizacoesPt.delegates,
        home: const _TelaPlano(fichaId: 'f1'),
      ),
    );

TreinoExercicioResumo _exComAlvo(
  String nome, {
  required int rodadas,
  required int? descansoSeg,
  required double? volumeAlvo,
  required double? volumeAlvoMax,
  required double? intensidadeAlvo,
  String intensidadeCodigo = 'CARGA_KG',
  String intensidadeNome = 'Carga',
}) =>
    TreinoExercicioResumo(
      id: 'te-$nome',
      exercicioId: 'e-$nome',
      nome: nome,
      grupoMuscular: 'peito',
      modalidade: 'FORCA',
      ordem: 1,
      rodadas: rodadas,
      descansoSeg: descansoSeg,
      instrucao: null,
      alvo: AlvoExercicio(
        intensidadeMetricaId: 1,
        intensidadeMetricaCodigo: intensidadeCodigo,
        intensidadeMetricaNome: intensidadeNome,
        intensidadeAlvo: intensidadeAlvo,
        volumeMetricaId: 10,
        volumeMetricaCodigo: 'REPETICOES',
        volumeMetricaNome: 'Repetições',
        volumeAlvo: volumeAlvo,
        volumeAlvoMax: volumeAlvoMax,
      ),
    );

/// Repositório que só guarda a ordem enviada ao reordenar.
class _RepoReordena extends FichasRepository {
  _RepoReordena() : super(Dio());

  List<String>? ordem;

  @override
  Future<void> reordenarExercicios({
    required String treinoId,
    required List<String> treinoExercicioIds,
  }) async {
    ordem = treinoExercicioIds;
  }
}

/// Repositório que registra a ordem dos exercícios adicionados e falha em um.
class _RepoAdiciona extends FichasRepository {
  _RepoAdiciona({required this.falha}) : super(Dio());

  final String falha;
  final tentados = <String>[];

  @override
  Future<void> adicionarExercicio({
    required String treinoId,
    required String exercicioId,
  }) async {
    tentados.add(exercicioId);
    if (exercicioId == falha) throw const FichasException('falhou');
  }
}

ExercicioResumo _resumo(String nome) => ExercicioResumo(
      id: nome,
      nome: nome,
      grupoMuscular: null,
      membroId: 1,
      membroNome: 'Peito',
      musculoId: null,
      musculoNome: null,
      modalidade: 'FORCA',
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      proprio: false,
    );
