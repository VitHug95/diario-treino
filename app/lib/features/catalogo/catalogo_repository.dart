import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import 'exercicio_resumo.dart';

/// Acesso ao catálogo de exercícios via API (GET /exercicios).
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
