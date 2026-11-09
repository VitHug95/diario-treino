import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import 'medidas_formato.dart';
import 'medidas_models.dart';

/// Erro de negócio nas medidas, com mensagem amigável. Nunca carrega o valor
/// digitado (dado de saúde).
class MedidasException implements Exception {
  const MedidasException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso às medidas corporais via API (E12 / PBI-91, só o dono, sob `/me`).
class MedidasRepository {
  MedidasRepository(this._dio);

  final Dio _dio;

  /// Últimas medidas (com variação) e histórico por dia.
  Future<ResumoMedidas> obterResumo() async {
    final resposta = await _dio.get<Map<String, dynamic>>('/me/medidas');
    return ResumoMedidas.doJson(resposta.data!);
  }

  /// Valores de um dia. 404 se o dia não tem medida.
  Future<DiaMedidas> obterDia(DateTime data) async {
    final resposta =
        await _dio.get<Map<String, dynamic>>('/me/medidas/${dataParaApi(data)}');
    return DiaMedidas.doJson(resposta.data!);
  }

  /// Grava as medidas do dia (upsert por tipo). Valor nulo remove só aquele tipo.
  Future<void> salvarMedidas(DateTime data, Map<TipoMedida, double?> valores) async {
    try {
      await _dio.put<Map<String, dynamic>>(
        '/me/medidas/${dataParaApi(data)}',
        data: {
          'valores': {for (final e in valores.entries) e.key.codigo: e.value},
        },
      );
    } on DioException catch (e) {
      throw MedidasException(_traduzir(e, 'Não foi possível salvar as medidas.'));
    }
  }

  /// Apaga o dia inteiro.
  Future<void> excluirMedidas(DateTime data) async {
    try {
      await _dio.delete<void>('/me/medidas/${dataParaApi(data)}');
    } on DioException catch (e) {
      throw MedidasException(_traduzir(e, 'Não foi possível excluir a medição.'));
    }
  }

  static String _traduzir(DioException e, String padrao) {
    switch (e.response?.statusCode) {
      case 400:
        return _mensagemDoProblema(e.response?.data) ??
            'Confira os valores e tente de novo.';
      case 404:
        return 'Essa medição não foi encontrada.';
      case null:
        return 'Sem conexão. Verifique sua internet e tente de novo.';
      default:
        return '$padrao Tente novamente.';
    }
  }

  /// Mensagem concreta de um 400 (ValidationProblem ou Problem Details).
  static String? _mensagemDoProblema(dynamic corpo) {
    if (corpo is! Map) return null;
    final errors = corpo['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final mensagens = <String>[];
      for (final valor in errors.values) {
        if (valor is List) {
          mensagens.addAll(valor.map((m) => m.toString()));
        } else if (valor != null) {
          mensagens.add(valor.toString());
        }
      }
      if (mensagens.isNotEmpty) return mensagens.join(' ');
    }
    final title = corpo['title'];
    if (title is String && title.trim().isNotEmpty) return title;
    return null;
  }
}

final medidasRepositoryProvider = Provider<MedidasRepository>(
  (ref) => MedidasRepository(ref.watch(dioProvider)),
);

/// Últimas medidas e histórico: alimenta a lista de medidas e o resumo do Perfil.
final resumoMedidasProvider = FutureProvider.autoDispose<ResumoMedidas>(
  (ref) => ref.watch(medidasRepositoryProvider).obterResumo(),
);

/// Valores de um dia (chave normalizada à meia-noite), para editar a medição.
final diaMedidasProvider =
    FutureProvider.autoDispose.family<DiaMedidas, DateTime>(
  (ref, data) => ref.watch(medidasRepositoryProvider).obterDia(data),
);
