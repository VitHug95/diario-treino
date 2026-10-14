import 'package:diario_treino/features/catalogo/catalogo_repository.dart';
import 'package:diario_treino/features/catalogo/criar_exercicio_screen.dart';
import 'package:diario_treino/features/catalogo/membro.dart';
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

final _membros = <Membro>[
  const Membro(
    id: 1,
    codigo: 'PEITO',
    nome: 'Peito',
    ordem: 1,
    musculos: [Musculo(id: 1, codigo: 'PEITORAL', nome: 'Peitoral')],
  ),
  const Membro(
    id: 8,
    codigo: 'MOBILIDADE',
    nome: 'Mobilidade',
    ordem: 8,
    musculos: [],
  ),
];

Widget _tela() => ProviderScope(
      overrides: [
        metricasProvider.overrideWith((ref) async => _metricas),
        membrosProvider.overrideWith((ref) async => _membros),
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

  testWidgets('Membro é obrigatório: salvar sem membro mostra erro', (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    // Preenche o nome, mas deixa o membro em branco.
    await tester.enterText(find.byType(TextFormField), 'Rosca direta');
    await tester.pumpAndSettle();

    final botao = find.widgetWithText(FilledButton, 'Criar exercício');
    await tester.scrollUntilVisible(botao, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(find.text('Escolha o membro'), findsOneWidget);
  });

  testWidgets('Músculo é filtrado pelo membro escolhido', (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    // Escolhe o membro "Peito".
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peito').last);
    await tester.pumpAndSettle();

    // O dropdown de músculo passa a oferecer "Nenhum" + os músculos do Peito.
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum'), findsWidgets);
    expect(find.text('Peitoral'), findsOneWidget);
  });

  testWidgets('Membro sem músculos desabilita o seletor de músculo',
      (tester) async {
    await tester.pumpWidget(_tela());
    await tester.pumpAndSettle();

    // Escolhe "Mobilidade" (sem músculos).
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobilidade').last);
    await tester.pumpAndSettle();

    expect(find.text('Este membro não tem músculos para detalhar.'),
        findsOneWidget);
  });
}
