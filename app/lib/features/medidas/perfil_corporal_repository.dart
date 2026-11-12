import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import 'medidas_formato.dart';
import 'perfil_corporal_models.dart';

/// Erro de negócio nos dados corporais, com mensagem amigável. Nunca carrega o
/// valor digitado (dado de saúde).
class PerfilCorporalException implements Exception {
  const PerfilCorporalException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso aos dados corporais e à TMB via API (E12 / PBI-93, só o dono, sob `/me`).
class PerfilCorporalRepository {
  PerfilCorporalRepository(this._dio);

  final Dio _dio;

  Future<PerfilCorporal> obter() async {
    final resposta = await _dio.get<Map<String, dynamic>>('/me/perfil-corporal');
    return PerfilCorporal.doJson(resposta.data!);
  }

  /// Substitui sexo, nascimento e altura (nulo limpa). Com [pesoKg], a API grava
  /// a medida PESO do dia [dataPeso] (o dia local do app, que à noite no Brasil
  /// já é "amanhã" em UTC). Sem [pesoKg], o histórico de peso não é tocado.
  Future<PerfilCorporal> salvarPerfilCorporal({
    SexoBiologico? sexo,
    DateTime? nascimento,
    int? alturaCm,
    double? pesoKg,
    DateTime? dataPeso,
  }) async {
    try {
      final resposta = await _dio.put<Map<String, dynamic>>(
        '/me/perfil-corporal',
        data: {
          'sexo': sexo?.codigo,
          'dataNascimento': nascimento == null ? null : dataParaApi(nascimento),
          'alturaCm': alturaCm,
          'pesoKg': pesoKg,
          'dataPeso': dataPeso == null ? null : dataParaApi(dataPeso),
        },
      );
      return PerfilCorporal.doJson(resposta.data!);
    } on DioException catch (e) {
      throw PerfilCorporalException(
          _traduzir(e, 'Não foi possível salvar os dados corporais.'));
    }
  }

  /// Grava a TMB informada pelo atleta (PBI-98), 800 a 5000 kcal. Rota própria:
  /// não mexe em sexo, nascimento e altura. Devolve os dados já recalculados.
  Future<PerfilCorporal> definirTmbManual(int kcal) async {
    try {
      final resposta = await _dio.put<Map<String, dynamic>>(
        '/me/perfil-corporal/tmb-manual',
        data: {'kcal': kcal},
      );
      return PerfilCorporal.doJson(resposta.data!);
    } on DioException catch (e) {
      throw PerfilCorporalException(_traduzir(e, 'Não foi possível salvar a TMB.'));
    }
  }

  /// Volta à TMB calculada (apaga a informada).
  Future<void> usarTmbCalculada() async {
    try {
      await _dio.delete<void>('/me/perfil-corporal/tmb-manual');
    } on DioException catch (e) {
      throw PerfilCorporalException(_traduzir(e, 'Não foi possível voltar ao cálculo.'));
    }
  }

  /// Limpa sexo, nascimento, altura e a TMB informada. O histórico de peso fica
  /// nas medidas.
  Future<void> limparPerfilCorporal() async {
    try {
      await _dio.delete<void>('/me/perfil-corporal');
    } on DioException catch (e) {
      throw PerfilCorporalException(
          _traduzir(e, 'Não foi possível limpar os dados corporais.'));
    }
  }

  static String _traduzir(DioException e, String padrao) {
    switch (e.response?.statusCode) {
      case 400:
        return _mensagemDoProblema(e.response?.data) ??
            'Confira os dados e tente de novo.';
      case null:
        return 'Sem conexão. Verifique sua internet e tente de novo.';
      default:
        return '$padrao Tente novamente.';
    }
  }

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

final perfilCorporalRepositoryProvider = Provider<PerfilCorporalRepository>(
  (ref) => PerfilCorporalRepository(ref.watch(dioProvider)),
);

/// Dados corporais e TMB: alimenta a tela de dados e o resumo do Perfil.
final perfilCorporalProvider = FutureProvider.autoDispose<PerfilCorporal>(
  (ref) => ref.watch(perfilCorporalRepositoryProvider).obter(),
);
