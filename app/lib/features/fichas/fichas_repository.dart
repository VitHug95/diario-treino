import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import 'plano_models.dart';

/// Erro de negócio ao mexer em fichas, com mensagem amigável.
class FichasException implements Exception {
  const FichasException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso às fichas de treino via API (PBI-12).
class FichasRepository {
  FichasRepository(this._dio);

  final Dio _dio;

  /// Plano ativo com as fichas, ou nulo se o atleta ainda não tem plano (204).
  Future<PlanoAtivo?> obterPlanoAtivo() async {
    final resposta = await _dio.get<Map<String, dynamic>>('/planos/ativo');
    if (resposta.statusCode == 204 || resposta.data == null) {
      return null;
    }
    return PlanoAtivo.doJson(resposta.data!);
  }

  /// Garante um plano ativo e devolve o id.
  Future<String> garantirPlano() async {
    final resposta = await _dio.post<Map<String, dynamic>>('/planos');
    return resposta.data!['id'] as String;
  }

  Future<void> adicionarFicha({
    required String planoId,
    required String nome,
    String? descricao,
  }) =>
      _executar(() => _dio.post<Map<String, dynamic>>(
            '/planos/$planoId/treinos',
            data: {'nome': nome, 'descricao': descricao},
          ));

  Future<void> editarFicha({
    required String treinoId,
    required String nome,
    String? descricao,
  }) =>
      _executar(() => _dio.put<void>(
            '/treinos/$treinoId',
            data: {'nome': nome, 'descricao': descricao},
          ));

  Future<void> arquivarFicha(String treinoId) =>
      _executar(() => _dio.delete<void>('/treinos/$treinoId'));

  // ---- Exercícios da ficha (PBI-13) ----

  Future<TreinoDetalhe> obterFicha(String treinoId) async {
    final resposta = await _dio.get<Map<String, dynamic>>('/treinos/$treinoId');
    return TreinoDetalhe.doJson(resposta.data!);
  }

  Future<void> adicionarExercicio({
    required String treinoId,
    required String exercicioId,
  }) =>
      _executar(() => _dio.post<Map<String, dynamic>>(
            '/treinos/$treinoId/exercicios',
            data: {'exercicioId': exercicioId},
          ));

  Future<void> removerExercicio({
    required String treinoId,
    required String treinoExercicioId,
  }) =>
      _executar(() => _dio.delete<void>(
            '/treinos/$treinoId/exercicios/$treinoExercicioId',
          ));

  Future<void> reordenarExercicios({
    required String treinoId,
    required List<String> treinoExercicioIds,
  }) =>
      _executar(() => _dio.put<void>(
            '/treinos/$treinoId/exercicios/ordem',
            data: {'treinoExercicioIds': treinoExercicioIds},
          ));

  Future<void> _executar(Future<void> Function() acao) async {
    try {
      await acao();
    } on DioException catch (e) {
      throw FichasException(_traduzir(e));
    }
  }

  static String _traduzir(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => 'Confira os campos: algo está inválido.',
      404 => 'Ficha não encontrada.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }
}

final fichasRepositoryProvider = Provider<FichasRepository>(
  (ref) => FichasRepository(ref.watch(dioProvider)),
);

/// Plano ativo atual (recarrega ao invalidar após criar/editar/arquivar).
final planoAtivoProvider = FutureProvider.autoDispose<PlanoAtivo?>(
  (ref) => ref.watch(fichasRepositoryProvider).obterPlanoAtivo(),
);

/// Detalhe de uma ficha (com os exercícios), por id.
final fichaDetalheProvider =
    FutureProvider.autoDispose.family<TreinoDetalhe, String>(
  (ref, treinoId) => ref.watch(fichasRepositoryProvider).obterFicha(treinoId),
);
