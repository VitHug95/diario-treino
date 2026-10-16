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

  // ---- Planos (PBI-44/45) ----

  /// Planos do atleta (só os ativos), na ordem da API.
  Future<List<PlanoDaLista>> listarPlanos() async {
    final resposta = await _dio.get<List<dynamic>>('/planos');
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(PlanoDaLista.doJson)
        .toList();
  }

  /// Plano específico com as fichas (GET /planos/{id}), no mesmo formato do
  /// plano em uso. A API devolve também uso e autoria, lidos na PBI-46.
  Future<PlanoAtivo> obterPlano(String planoId) async {
    final resposta = await _dio.get<Map<String, dynamic>>('/planos/$planoId');
    return PlanoAtivo.doJson(resposta.data!);
  }

  /// Detalhe do plano com uso e autoria (tela 19).
  Future<PlanoDetalhe> obterDetalhePlano(String planoId) async {
    final resposta = await _dio.get<Map<String, dynamic>>('/planos/$planoId');
    return PlanoDetalhe.doJson(resposta.data!);
  }

  /// Cria um plano com nome e devolve o id. O primeiro do atleta nasce em uso.
  Future<String> criarPlano(String nome) async {
    try {
      final resposta = await _dio.post<Map<String, dynamic>>(
        '/planos',
        data: {'nome': nome},
      );
      return resposta.data!['id'] as String;
    } on DioException catch (e) {
      throw FichasException(_traduzirPlano(e));
    }
  }

  Future<void> renomearPlano({required String planoId, required String nome}) =>
      _executarPlano(() => _dio.put<void>('/planos/$planoId', data: {'nome': nome}));

  /// Define o plano em uso (a API troca numa transação só).
  Future<void> definirEmUso(String planoId) =>
      _executarPlano(() => _dio.post<void>('/planos/$planoId/em-uso'));

  /// Duplica o plano (cópia do atleta, fora de uso, sem sessões). Devolve o id.
  Future<String> duplicarPlano(String planoId) async {
    try {
      final resposta =
          await _dio.post<Map<String, dynamic>>('/planos/$planoId/duplicar');
      return resposta.data!['id'] as String;
    } on DioException catch (e) {
      throw FichasException(_traduzirPlano(e));
    }
  }

  /// Exclui o plano. A API apaga se não houver sessões ou esconde se houver,
  /// e passa o uso adiante quando ele estava em uso.
  Future<void> excluirPlano(String planoId) =>
      _executarPlano(() => _dio.delete<void>('/planos/$planoId'));

  Future<void> _executarPlano(Future<void> Function() acao) async {
    try {
      await acao();
    } on DioException catch (e) {
      throw FichasException(_traduzirPlano(e));
    }
  }

  static String _traduzirPlano(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => 'Confira o nome do plano.',
      403 => 'Este plano é do seu professor: só ele edita. Copie para mudar.',
      404 => 'Plano não encontrado.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }

  // ---- Fichas ----

  /// Cria a ficha no plano e devolve o id dela (PBI-61: o aviso "Adicionar
  /// exercícios" abre a ficha recém-criada).
  Future<String> adicionarFicha({
    required String planoId,
    required String nome,
    String? descricao,
  }) async {
    try {
      final resposta = await _dio.post<Map<String, dynamic>>(
        '/planos/$planoId/treinos',
        data: {'nome': nome, 'descricao': descricao},
      );
      return resposta.data!['id'] as String;
    } on DioException catch (e) {
      throw FichasException(_traduzir(e));
    }
  }

  /// Cria uma ficha a partir dos exercícios de um treino livre (PBI-19,
  /// "Salvar também como ficha"). Garante o plano no servidor.
  Future<void> salvarComoFicha({
    required String nome,
    String? descricao,
    required List<String> exercicioIds,
  }) =>
      _executar(() => _dio.post<Map<String, dynamic>>(
            '/planos/fichas-de-treino',
            data: {
              'nome': nome,
              'descricao': descricao,
              'exercicioIds': exercicioIds,
            },
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

  /// Exclui a ficha (PBI-36). O back apaga de verdade se não houver sessões, ou
  /// arquiva (ativo=false) se já houver treinos registrados com ela.
  Future<void> excluirFicha(String treinoId) =>
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

  // ---- Alvos do exercício (PBI-14) ----

  /// Define séries, alvos, descanso e instrução de um exercício da ficha.
  Future<void> definirAlvos({
    required String treinoId,
    required String treinoExercicioId,
    required int series,
    required int intensidadeMetricaId,
    double? intensidadeAlvo,
    required int volumeMetricaId,
    double? volumeAlvo,
    // Máximo da faixa de volume (TV-2); nulo = sem faixa.
    double? volumeAlvoMax,
    int? descansoSeg,
    String? instrucao,
    // Tags de série (TV-1), por rodada. Só precisa enviar as ≠ VALIDA.
    List<MarcadorRodada> marcadores = const [],
  }) =>
      _executar(() => _dio.put<void>(
            '/treinos/$treinoId/exercicios/$treinoExercicioId/alvos',
            data: {
              'series': series,
              'intensidadeMetricaId': intensidadeMetricaId,
              'intensidadeAlvo': intensidadeAlvo,
              'volumeMetricaId': volumeMetricaId,
              'volumeAlvo': volumeAlvo,
              'volumeAlvoMax': volumeAlvoMax,
              'descansoSeg': descansoSeg,
              'instrucao': instrucao,
              'marcadores': [
                for (final m in marcadores)
                  if (m.marcador != 'VALIDA')
                    {'rodada': m.rodada, 'marcador': m.marcador},
              ],
            },
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

/// Planos do atleta (PBI-45). A tela ordena com [ordenarPlanos].
final planosProvider = FutureProvider.autoDispose<List<PlanoDaLista>>(
  (ref) => ref.watch(fichasRepositoryProvider).listarPlanos(),
);

/// Um plano específico com as fichas, por id (aberto a partir da lista).
final planoPorIdProvider =
    FutureProvider.autoDispose.family<PlanoAtivo?, String>(
  (ref, planoId) => ref.watch(fichasRepositoryProvider).obterPlano(planoId),
);

/// Detalhe do plano para a tela 19 (PBI-46). Sem id, abre o plano em uso;
/// devolve nulo se o atleta não tem plano em uso.
final planoDetalheProvider =
    FutureProvider.autoDispose.family<PlanoDetalhe?, String?>(
  (ref, planoId) async {
    final repo = ref.watch(fichasRepositoryProvider);
    final alvo = planoId ?? (await repo.obterPlanoAtivo())?.id;
    if (alvo == null) return null;
    return repo.obterDetalhePlano(alvo);
  },
);

/// Detalhe de uma ficha (com os exercícios), por id.
final fichaDetalheProvider =
    FutureProvider.autoDispose.family<TreinoDetalhe, String>(
  (ref, treinoId) => ref.watch(fichasRepositoryProvider).obterFicha(treinoId),
);
