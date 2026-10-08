import 'package:diario_treino/features/fichas/fichas_repository.dart';
import 'package:diario_treino/features/fichas/fichas_screen.dart';
import 'package:diario_treino/features/fichas/plano_models.dart';
import 'package:diario_treino/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PlanoAtivo _plano(List<TreinoResumo> treinos) =>
    PlanoAtivo(id: 'p1', nome: 'Meu plano', treinos: treinos);

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

Widget _tela({
  required Future<PlanoAtivo?> Function(Ref ref) plano,
  TreinoDetalhe Function(String treinoId)? detalhe,
}) =>
    ProviderScope(
      overrides: [
        planoAtivoProvider.overrideWith(plano),
        if (detalhe != null)
          fichaDetalheProvider.overrideWith((ref, treinoId) async => detalhe(treinoId)),
      ],
      child: MaterialApp(theme: AppTheme.claro, home: const FichasScreen()),
    );

void main() {
  testWidgets('Mostra uma aba por ficha e lista os exercícios da selecionada',
      (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([
        _ficha('A', 1, desc: 'Peito e tríceps'),
        _ficha('B', 2),
        _ficha('C', 3),
      ]),
      detalhe: (id) => _detalhe(id, [_ex('Supino reto', 1), _ex('Crucifixo', 2)]),
    ));
    await tester.pumpAndSettle();

    // Três abas (ChoiceChip) — por ficha, não fixo em 3.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text('Peito e tríceps'), findsOneWidget);
    // Exercícios da ficha selecionada.
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Crucifixo'), findsOneWidget);
    expect(find.text('Adicionar exercício à ficha'), findsOneWidget);
  });

  testWidgets('Ficha sem exercícios mostra o estado vazio', (tester) async {
    await tester.pumpWidget(_tela(
      plano: (ref) async => _plano([_ficha('A', 1)]),
      detalhe: (id) => _detalhe(id, const []),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ficha sem exercícios'), findsOneWidget);
  });

  testWidgets('Estado vazio convida a criar a primeira ficha', (tester) async {
    await tester.pumpWidget(_tela(plano: (ref) async => null));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma ficha ainda'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'CRIAR FICHA'), findsOneWidget);
  });
}
