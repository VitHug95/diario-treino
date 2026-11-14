import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';

/// Os dois cadeados do corpo e quem vê (E12 / PBI-95 e 96). Destrancado, todo
/// educador com vínculo ativo vê, só leitura; trancado é o padrão.
class CompartilhamentoCorporal {
  const CompartilhamentoCorporal({
    required this.dadosCorporais,
    required this.medidas,
    required this.educadores,
  });

  /// Sexo, idade, altura, peso e TMB liberados.
  final bool dadosCorporais;

  /// Medidas corporais (e a evolução delas) liberadas.
  final bool medidas;

  /// Nomes dos educadores com vínculo ativo: quem vê o que estiver liberado.
  final List<String> educadores;

  bool get algumLiberado => dadosCorporais || medidas;

  factory CompartilhamentoCorporal.doJson(Map<String, dynamic> json) =>
      CompartilhamentoCorporal(
        dadosCorporais: json['dadosCorporais'] as bool? ?? false,
        medidas: json['medidas'] as bool? ?? false,
        educadores: [
          for (final e in (json['educadores'] as List<dynamic>? ?? const []))
            (e as Map<String, dynamic>)['nome'] as String,
        ],
      );
}

class CompartilhamentoException implements Exception {
  const CompartilhamentoException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// `GET|PUT /me/compartilhamento-corporal`.
class CompartilhamentoRepository {
  CompartilhamentoRepository(this._dio);

  final Dio _dio;

  Future<CompartilhamentoCorporal> obter() async {
    final resposta =
        await _dio.get<Map<String, dynamic>>('/me/compartilhamento-corporal');
    return CompartilhamentoCorporal.doJson(resposta.data!);
  }

  /// Define os dois cadeados de uma vez (a API exige os dois).
  Future<CompartilhamentoCorporal> definirCompartilhamentoCorporal({
    required bool dadosCorporais,
    required bool medidas,
  }) async {
    try {
      final resposta = await _dio.put<Map<String, dynamic>>(
        '/me/compartilhamento-corporal',
        data: {'dadosCorporais': dadosCorporais, 'medidas': medidas},
      );
      return CompartilhamentoCorporal.doJson(resposta.data!);
    } on DioException catch (e) {
      throw CompartilhamentoException(e.response == null
          ? 'Sem conexão. Verifique sua internet e tente de novo.'
          : 'Não foi possível salvar. Tente novamente.');
    }
  }
}

final compartilhamentoRepositoryProvider = Provider<CompartilhamentoRepository>(
  (ref) => CompartilhamentoRepository(ref.watch(dioProvider)),
);

/// Cadeados do corpo: a tela "Compartilhar", os selos e a linha do Perfil.
final compartilhamentoCorporalProvider =
    FutureProvider.autoDispose<CompartilhamentoCorporal>(
  (ref) => ref.watch(compartilhamentoRepositoryProvider).obter(),
);
