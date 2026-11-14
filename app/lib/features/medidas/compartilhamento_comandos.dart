import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import 'compartilhamento_repository.dart';

/// Escrita dos cadeados do corpo (PBI-96), com o aviso em [invalidarDerivados].
class CompartilhamentoComandos {
  CompartilhamentoComandos(this._ref);

  final Ref _ref;

  Future<CompartilhamentoCorporal> definir({
    required bool dadosCorporais,
    required bool medidas,
  }) async {
    try {
      return await _ref
          .read(compartilhamentoRepositoryProvider)
          .definirCompartilhamentoCorporal(dadosCorporais: dadosCorporais, medidas: medidas);
    } finally {
      invalidarDerivados(_ref, Mudanca.compartilhamentoCorporal);
    }
  }
}

final compartilhamentoComandosProvider =
    Provider<CompartilhamentoComandos>(CompartilhamentoComandos.new);
