import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import 'exercicio_resumo.dart';
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
    String? modalidade,
  }) async {
    final resposta = await _dio.get<List<dynamic>>(
      '/exercicios',
      queryParameters: {
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
        if (modalidade != null) 'modalidade': modalidade,
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

  /// Cria um exercício próprio e devolve o id gerado. Traduz os erros da API
  /// em [CatalogoException].
  Future<String> criarExercicio({
    required String nome,
    String? grupoMuscular,
    required String modalidade,
    required int intensidadeMetricaId,
    required int volumeMetricaId,
  }) async {
    try {
      final resposta = await _dio.post<Map<String, dynamic>>('/exercicios', data: {
        'nome': nome,
        'grupoMuscular': grupoMuscular,
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

/// Critério de busca atual (texto + modalidade), observado pela tela.
class CatalogoFiltro {
  const CatalogoFiltro({this.busca = '', this.modalidade = ModalidadeFiltro.todos});

  final String busca;
  final ModalidadeFiltro modalidade;

  CatalogoFiltro copyWith({String? busca, ModalidadeFiltro? modalidade}) =>
      CatalogoFiltro(
        busca: busca ?? this.busca,
        modalidade: modalidade ?? this.modalidade,
      );
}

final catalogoFiltroProvider =
    NotifierProvider<CatalogoFiltroController, CatalogoFiltro>(
  CatalogoFiltroController.new,
);

class CatalogoFiltroController extends Notifier<CatalogoFiltro> {
  @override
  CatalogoFiltro build() => const CatalogoFiltro();

  void definirBusca(String busca) => state = state.copyWith(busca: busca);

  void definirModalidade(ModalidadeFiltro modalidade) =>
      state = state.copyWith(modalidade: modalidade);

  /// Volta ao filtro inicial (busca vazia, modalidade Todos). Chamado ao abrir
  /// o catálogo ou o seletor, para a tela nunca reabrir com a busca anterior.
  void limpar() => state = const CatalogoFiltro();
}

/// Resultado da busca segundo o filtro atual. Recarrega quando o filtro muda.
final catalogoProvider = FutureProvider.autoDispose<List<ExercicioResumo>>((ref) {
  final filtro = ref.watch(catalogoFiltroProvider);
  final repo = ref.watch(catalogoRepositoryProvider);
  return repo.buscar(
    busca: filtro.busca,
    modalidade: filtro.modalidade.valorApi,
  );
});

/// Métricas disponíveis para a tela de criar exercício.
final metricasProvider = FutureProvider<List<Metrica>>(
  (ref) => ref.watch(catalogoRepositoryProvider).listarMetricas(),
);
