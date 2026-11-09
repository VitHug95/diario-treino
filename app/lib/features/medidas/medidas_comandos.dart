import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import 'medidas_models.dart';
import 'medidas_repository.dart';

/// Escritas das medidas (PBI-70): cada comando chama o repositório e, ao fim,
/// avisa o que mudou em [invalidarDerivados] — o único lugar que invalida.
class MedidasComandos {
  MedidasComandos(this._ref);

  final Ref _ref;

  // Lido a cada chamada para os testes poderem trocar o repositório.
  MedidasRepository get _repo => _ref.read(medidasRepositoryProvider);

  Future<T> _mudar<T>(Future<T> Function(MedidasRepository repo) acao) async {
    try {
      return await acao(_repo);
    } finally {
      invalidarDerivados(_ref, Mudanca.medidas);
    }
  }

  /// Valor nulo remove só aquele tipo do dia.
  Future<void> salvar(DateTime data, Map<TipoMedida, double?> valores) =>
      _mudar((r) => r.salvarMedidas(data, valores));

  Future<void> excluir(DateTime data) => _mudar((r) => r.excluirMedidas(data));
}

final medidasComandosProvider = Provider<MedidasComandos>(MedidasComandos.new);
