import 'package:diario_treino/features/sessao/sessao_edicao.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/shared/tags/seletor_tag_serie.dart';
import 'package:diario_treino/shared/tags/tag_serie.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envolve o widget no tema do app (a AppColors é ThemeExtension e o chip
/// resolve as cores por token).
Widget _comTema(Widget filho) => MaterialApp(
      theme: AppTheme.claro,
      home: Scaffold(body: Center(child: filho)),
    );

SerieRascunho _serie({required String marcador}) => SerieRascunho(
      rodada: 1,
      ordem: 1,
      tipo: 'ESFORCO',
      intensidadeMetricaId: 1,
      intensidadeMetricaCodigo: 'CARGA_KG',
      intensidadeMetricaNome: 'Carga',
      intensidade: 30,
      volumeMetricaId: 10,
      volumeMetricaCodigo: 'REPETICOES',
      volumeMetricaNome: 'Repetições',
      volume: 10,
      descansoSeg: 90,
      marcador: marcador,
    );

void main() {
  group('TagsSerie (catálogo)', () {
    test('tem os 10 códigos na ordem, Válida primeiro', () {
      expect(TagsSerie.lista.length, 10);
      expect(TagsSerie.lista.first.codigo, 'VALIDA');
      expect(TagsSerie.lista.map((t) => t.codigo), contains('TOP_SET'));
    });

    test('rótulo e ehValida', () {
      expect(TagsSerie.rotulo('AQUECIMENTO'), 'Aquecimento');
      expect(TagsSerie.ehValida('VALIDA'), isTrue);
      expect(TagsSerie.ehValida('FALHA'), isFalse);
    });

    test('código desconhecido cai em Válida (robustez)', () {
      expect(TagsSerie.info('INVENTADO').codigo, 'VALIDA');
    });
  });

  group('ChipTagSerie', () {
    testWidgets('modo leitura esconde VALIDA', (tester) async {
      await tester.pumpWidget(_comTema(
        const ChipTagSerie(marcador: 'VALIDA', rodada: 1),
      ));
      // Nada renderizado para a tag padrão em leitura.
      expect(find.text('Válida'), findsNothing);
    });

    testWidgets('modo leitura mostra o rótulo de uma tag ≠ VALIDA', (tester) async {
      await tester.pumpWidget(_comTema(
        const ChipTagSerie(marcador: 'AQUECIMENTO', rodada: 1),
      ));
      expect(find.text('Aquecimento'), findsOneWidget);
    });

    testWidgets('modo edição mostra "Válida" (dá para trocar)', (tester) async {
      await tester.pumpWidget(_comTema(
        ChipTagSerie(marcador: 'VALIDA', rodada: 1, aoTocar: (_) {}),
      ));
      expect(find.text('Válida'), findsOneWidget);
    });

    testWidgets('abre o seletor e troca o valor', (tester) async {
      String? escolhido;
      await tester.pumpWidget(_comTema(
        ChipTagSerie(
          marcador: 'VALIDA',
          rodada: 1,
          aoTocar: (novo) => escolhido = novo,
        ),
      ));

      // Toca no chip -> abre o bottom sheet com as 10 opções.
      await tester.tap(find.byType(ChipTagSerie));
      await tester.pumpAndSettle();
      expect(find.text('Tag da série'), findsOneWidget);
      expect(find.text('Aquecimento'), findsWidgets);

      // Escolhe "Top set".
      await tester.tap(find.text('Top set'));
      await tester.pumpAndSettle();
      expect(escolhido, 'TOP_SET');
    });
  });

  group('Herança da tag (SerieEdicao)', () {
    test('doRascunho traz a tag pré-preenchida pelo servidor', () {
      final edicao = SerieEdicao.doRascunho(_serie(marcador: 'AQUECIMENTO'));
      expect(edicao.marcador, 'AQUECIMENTO');
    });

    test('copiarComoRodada propaga a tag para a nova série', () {
      final original = SerieEdicao.doRascunho(_serie(marcador: 'TOP_SET'));
      final copia = original.copiarComoRodada(2);
      expect(copia.marcador, 'TOP_SET');
      expect(copia.rodada, 2);
    });
  });
}
