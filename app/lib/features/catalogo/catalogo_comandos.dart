import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import 'catalogo_repository.dart';

/// Escritas do catálogo (PBI-70): criar exercício próprio atualiza a busca.
class CatalogoComandos {
  CatalogoComandos(this._ref);

  final Ref _ref;

  Future<String> criarExercicio({
    required String nome,
    required int membroId,
    int? musculoId,
    required String modalidade,
    required int intensidadeMetricaId,
    required int volumeMetricaId,
  }) async {
    try {
      return await _ref.read(catalogoRepositoryProvider).criarExercicio(
            nome: nome,
            membroId: membroId,
            musculoId: musculoId,
            modalidade: modalidade,
            intensidadeMetricaId: intensidadeMetricaId,
            volumeMetricaId: volumeMetricaId,
          );
    } finally {
      invalidarDerivados(_ref, Mudanca.catalogo);
    }
  }
}

final catalogoComandosProvider =
    Provider<CatalogoComandos>(CatalogoComandos.new);
