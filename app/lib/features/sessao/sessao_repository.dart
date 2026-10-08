import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import '../catalogo/catalogo_repository.dart';
import '../catalogo/metrica.dart';
import 'sessao_edicao.dart';
import 'sessao_models.dart';

/// Erro de negócio ao registrar sessão, com mensagem amigável.
class SessaoException implements Exception {
  const SessaoException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso ao registro de treino via API (PBI-15).
class SessaoRepository {
  SessaoRepository(this._dio);

  final Dio _dio;

  /// Rascunho pré-preenchido de uma ficha.
  Future<RascunhoSessao> obterRascunho(String treinoId) async {
    final resposta = await _dio.get<Map<String, dynamic>>(
      '/treinos/$treinoId/rascunho-sessao',
    );
    return RascunhoSessao.doJson(resposta.data!);
  }

  /// Grava a sessão. Exercícios não realizados ou sem séries ficam de fora.
  Future<void> criarSessao({
    required String? treinoId,
    required DateTime data,
    int? duracaoMin,
    String? observacao,
    required List<ExercicioEdicao> exercicios,
  }) async {
    final corpoExercicios = <Map<String, dynamic>>[];
    for (final e in exercicios) {
      final series = e.realizado ? _serializarSeries(e.series) : const [];
      corpoExercicios.add({
        'exercicioId': e.exercicioId,
        'treinoExercicioId': e.treinoExercicioId,
        'series': series,
      });
    }

    try {
      await _dio.post<Map<String, dynamic>>('/sessoes', data: {
        'treinoId': treinoId,
        'data': _soData(data),
        'duracaoMin': duracaoMin,
        'observacao': observacao,
        'exercicios': corpoExercicios,
      });
    } on DioException catch (e) {
      throw SessaoException(_traduzir(e));
    }
  }

  static List<Map<String, dynamic>> _serializarSeries(List<SerieEdicao> series) {
    final lista = <Map<String, dynamic>>[];
    for (final s in series) {
      final volume = _parse(s.volumeTexto);
      // Série sem volume não é uma série feita: ignora.
      if (volume == null) continue;
      lista.add({
        'rodada': s.rodada,
        'ordem': s.ordem,
        'tipo': s.tipo,
        'intensidadeMetricaId': s.intensidadeMetricaId,
        'intensidade': s.intensidadePorPesoCorporal ? null : _parse(s.intensidadeTexto),
        'volumeMetricaId': s.volumeMetricaId,
        'volume': volume,
        'descansoSeg': int.tryParse(s.descansoTexto.trim()),
      });
    }
    return lista;
  }

  static double? _parse(String texto) {
    final limpo = texto.trim().replaceAll(',', '.');
    if (limpo.isEmpty) return null;
    return double.tryParse(limpo);
  }

  /// Envia só a data (sem hora), no formato ISO yyyy-MM-dd que o DateOnly aceita.
  static String _soData(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _traduzir(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => 'Confira os campos: alguma informação está inválida.',
      404 => 'Ficha não encontrada.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível registrar o treino. Tente novamente.',
    };
  }
}

final sessaoRepositoryProvider = Provider<SessaoRepository>(
  (ref) => SessaoRepository(ref.watch(dioProvider)),
);

/// Rascunho de sessão de uma ficha, por treinoId.
final rascunhoSessaoProvider =
    FutureProvider.autoDispose.family<RascunhoSessao, String>(
  (ref, treinoId) => ref.watch(sessaoRepositoryProvider).obterRascunho(treinoId),
);

/// Métricas indexadas por código, para montar um exercício fora da ficha
/// (PBI-17) resolvendo o id/nome a partir do código vindo do catálogo.
final metricasPorCodigoProvider =
    FutureProvider.autoDispose<Map<String, Metrica>>((ref) async {
  final metricas = await ref.watch(catalogoRepositoryProvider).listarMetricas();
  return {for (final m in metricas) m.codigo: m};
});
