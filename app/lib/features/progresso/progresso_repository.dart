import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import '../sessao/sessao_repository.dart';
import 'progresso_models.dart';

/// Acesso ao progresso por exercício via API (PBI-20).
class ProgressoRepository {
  ProgressoRepository(this._dio);

  final Dio _dio;

  /// Exercícios que o atleta já treinou (para o seletor do gráfico).
  Future<List<ExercicioComHistorico>> listarExerciciosComHistorico() async {
    final resposta = await _dio.get<List<dynamic>>('/progresso/exercicios');
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ExercicioComHistorico.doJson)
        .toList();
  }

  /// Evolução de um exercício no período.
  Future<ProgressoExercicio> obterProgresso(
    String exercicioId, {
    DateTime? de,
    DateTime? ate,
  }) async {
    final resposta = await _dio.get<Map<String, dynamic>>(
      '/progresso/exercicios/$exercicioId',
      queryParameters: {
        if (de != null) 'de': _soData(de),
        if (ate != null) 'ate': _soData(ate),
      },
    );
    return ProgressoExercicio.doJson(resposta.data!);
  }

  static String _soData(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final progressoRepositoryProvider = Provider<ProgressoRepository>(
  (ref) => ProgressoRepository(ref.watch(dioProvider)),
);

/// Exercícios com histórico (seletor do gráfico).
final exerciciosComHistoricoProvider =
    FutureProvider.autoDispose<List<ExercicioComHistorico>>(
  (ref) => ref.watch(progressoRepositoryProvider).listarExerciciosComHistorico(),
);

/// Exercício selecionado no gráfico (nulo = nenhum ainda).
final exercicioSelecionadoProvider = NotifierProvider.autoDispose<
    ExercicioSelecionadoController, String?>(
  ExercicioSelecionadoController.new,
);

class ExercicioSelecionadoController extends Notifier<String?> {
  @override
  String? build() => null;

  void selecionar(String? exercicioId) => state = exercicioId;
}

/// Progresso do exercício selecionado, no período escolhido (reaproveita o
/// periodoSessoesProvider da aba Progresso).
final progressoDoExercicioProvider =
    FutureProvider.autoDispose<ProgressoExercicio?>((ref) async {
  final exercicioId = ref.watch(exercicioSelecionadoProvider);
  if (exercicioId == null) return null;

  final periodo = ref.watch(periodoSessoesProvider);
  final hoje = DateTime.now();
  final de = DateTime(hoje.year, hoje.month, hoje.day)
      .subtract(Duration(days: periodo.dias));
  return ref
      .watch(progressoRepositoryProvider)
      .obterProgresso(exercicioId, de: de);
});
