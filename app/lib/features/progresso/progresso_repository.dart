import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import '../sessao/sessao_repository.dart';
import 'progresso_models.dart';

/// Erro ao exportar o PDF do progresso (PBI-89), com mensagem amigável.
class ProgressoException implements Exception {
  const ProgressoException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

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

  /// Baixa o PDF do progresso (PBI-89) como bytes. [atletaId] não nulo é o modo
  /// educador (o aluno do vínculo). Sem [de]/[ate], a API usa os últimos 90
  /// dias. Sem acesso, a API responde 404 → [ProgressoException].
  Future<List<int>> baixarProgressoPdf({
    DateTime? de,
    DateTime? ate,
    String? atletaId,
  }) async {
    try {
      final resposta = await _dio.get<List<int>>(
        '/progresso/pdf',
        queryParameters: {
          if (de != null) 'de': _soData(de),
          if (ate != null) 'ate': _soData(ate),
          if (atletaId != null) 'atletaId': atletaId,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return resposta.data ?? const [];
    } on DioException catch (e) {
      throw ProgressoException(_traduzir(e));
    }
  }

  static String _traduzir(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      404 => 'Progresso não encontrado.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível gerar o PDF. Tente novamente.',
    };
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

/// Progresso de UM exercício por id (TV-4, aba Evolução da tela do exercício).
/// Não depende do seletor global da aba Progresso; usa o mesmo período padrão
/// (90 dias) para dar uma visão ampla da evolução.
final progressoPorExercicioProvider = FutureProvider.autoDispose
    .family<ProgressoExercicio?, String>((ref, exercicioId) async {
  final hoje = DateTime.now();
  final de = DateTime(hoje.year, hoje.month, hoje.day)
      .subtract(const Duration(days: 90));
  return ref
      .watch(progressoRepositoryProvider)
      .obterProgresso(exercicioId, de: de);
});
