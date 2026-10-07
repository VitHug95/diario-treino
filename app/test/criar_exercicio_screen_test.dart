import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/criar_exercicio_screen.dart';
import 'package:diario_treino/features/catalogo/metrica.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _metricas = <Metrica>[
  const Metrica(id: 1, codigo: 'CARGA_KG', nome: 'Carga', unidade: 'kg', eixo: 'INTENSIDADE'),
  const Metrica(id: 2, codigo: 'PESO_CORPORAL', nome: 'Peso corporal', unidade: '-', eixo: 'INTENSIDADE'),
  const Metrica(id: 3, codigo: 'ZONA', nome: 'Zona', unidade: '1 a 5', eixo: 'INTENSIDADE'),
  const Metrica(id: 10, codigo: 'REPETICOES', nome: 'Repetições', unidade: 'rep', eixo: 'VOLUME'),
  const Metrica(id: 11, codigo: 'TEMPO_SEG', nome: 'Tempo', unidade: 's', eixo: 'VOLUME'),
];

Widget _tela() => ProviderScope(
      overrides: [
        metricasProvider.overrideWith((ref) async => _metricas),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: const CriarExercicioScreen()),
    );

void main() {
  testWidgets('Sugere Carga e Repetições para Força e troca ao escolher Cardio',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    // Força (padrão) sugere Carga × Repetições — aparece na prévia.
    expect(find.textContaining('Carga × Repetições'), findsOneWidget);

    // Troca para Cardio (cartão de tipo): sugere Zona × Tempo.
    await tester.tap(find.text('Cardio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Zona × Tempo'), findsOneWidget);
  });

  testWidgets('Não cria sem nome: mostra erro de validação', (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    final botao = find.widgetWithText(FilledButton, 'Criar exercício');
    await tester.ensureVisible(botao);
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome'), findsOneWidget);
  });
}
