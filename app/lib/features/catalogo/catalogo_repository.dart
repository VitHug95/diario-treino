import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import 'exercicio_resumo.dart';
import 'membro.dart';
import 'metrica.dart';

/// Erro de negócio ao criar exercício, já com mensagem amigável
/// (ex.: nome repetido = 409).
class CatalogoException implements Exception {
  const CatalogoException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso ao catálogo de exercícios via API.
class CatalogoRepository {
  CatalogoRepository(this._dio);

  final Dio _dio;

  Future<List<ExercicioResumo>> buscar({
    String? busca,
    int? membroId,
  }) async {
    final resposta = await _dio.get<List<dynamic>>(
      '/exercicios',
      queryParameters: {
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
        if (membroId != null) 'membro': membroId,
      },
    );

    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ExercicioResumo.doJson)
        .toList();
  }

  Future<List<Metrica>> listarMetricas() async {
    final resposta = await _dio.get<List<dynamic>>('/metricas');
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(Metrica.doJson)
        .toList();
  }

  /// Membros com músculos, para os chips do filtro e o cadastro (PBI-31).
  Future<List<Membro>> listarMembros() async {
    final resposta = await _dio.get<List<dynamic>>('/membros');
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(Membro.doJson)
        .toList();
  }

  /// Cria um exercício próprio e devolve o id gerado. Traduz os erros da API
  /// em [CatalogoException]. Membro obrigatório; músculo opcional.
  Future<String> criarExercicio({
    required String nome,
    required int membroId,
    int? musculoId,
    required String modalidade,
    required int intensidadeMetricaId,
    required int volumeMetricaId,
  }) async {
    try {
      final resposta = await _dio.post<Map<String, dynamic>>('/exercicios', data: {
        'nome': nome,
        'membroId': membroId,
        'musculoId': musculoId,
        'modalidade': modalidade,
        'intensidadeMetricaId': intensidadeMetricaId,
        'volumeMetricaId': volumeMetricaId,
      });
      return (resposta.data?['id'] as String?) ?? '';
    } on DioException catch (e) {
      throw CatalogoException(_traduzir(e));
    }
  }

  /// Busca um exercício específico pelo id, dentro do catálogo do usuário.
  /// Usado após criar um exercício no seletor, para devolvê-lo já selecionado.
  Future<ExercicioResumo?> buscarPorId(String id) async {
    final itens = await buscar();
    return itens.where((e) => e.id == id).firstOrNull;
  }

  static String _traduzir(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      409 => 'Você já tem um exercício com esse nome.',
      400 => 'Confira os campos: algo está inválido.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível criar o exercício. Tente novamente.',
    };
  }
}

final catalogoRepositoryProvider = Provider<CatalogoRepository>(
  (ref) => CatalogoRepository(ref.watch(dioProvider)),
);

/// Critério de busca atual (texto + membro), observado pela tela. membroId nulo
/// = chip "Todos" (PBI-31).
class CatalogoFiltro {
  const CatalogoFiltro({this.busca = '', this.membroId});

  final String busca;
  final int? membroId;

  CatalogoFiltro comBusca(String busca) =>
      CatalogoFiltro(busca: busca, membroId: membroId);

  CatalogoFiltro comMembro(int? membroId) =>
      CatalogoFiltro(busca: busca, membroId: membroId);
}

final catalogoFiltroProvider =
    NotifierProvider<CatalogoFiltroController, CatalogoFiltro>(
  CatalogoFiltroController.new,
);

class CatalogoFiltroController extends Notifier<CatalogoFiltro> {
  @override
  CatalogoFiltro build() => const CatalogoFiltro();

  void definirBusca(String busca) => state = state.comBusca(busca);

  void definirMembro(int? membroId) => state = state.comMembro(membroId);

  /// Volta ao filtro inicial (busca vazia, membro "Todos"). Chamado ao abrir
  /// o catálogo ou o seletor, para a tela nunca reabrir com a busca anterior.
  void limpar() => state = const CatalogoFiltro();
}

/// Resultado da busca segundo o filtro atual. Recarrega quando o filtro muda.
final catalogoProvider = FutureProvider.autoDispose<List<ExercicioResumo>>((ref) {
  final filtro = ref.watch(catalogoFiltroProvider);
  final repo = ref.watch(catalogoRepositoryProvider);
  return repo.buscar(busca: filtro.busca, membroId: filtro.membroId);
});

/// Métricas disponíveis para a tela de criar exercício.
final metricasProvider = FutureProvider<List<Metrica>>(
  (ref) => ref.watch(catalogoRepositoryProvider).listarMetricas(),
);

/// Membros com músculos, para os chips de filtro e o cadastro.
final membrosProvider = FutureProvider<List<Membro>>(
  (ref) => ref.watch(catalogoRepositoryProvider).listarMembros(),
);
