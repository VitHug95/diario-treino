import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import '../auth/perfil_api.dart';
import 'educador_repository.dart';

/// Escritas do modo educador (PBI-88): ativar o papel, convidar, aceitar,
/// recusar e encerrar vínculo. Cada uma chama o repositório e, ao terminar,
/// avisa quem lê via [invalidarDerivados] (mapa único de invalidação). As
/// telas gravam por aqui, nunca direto no repositório.
class EducadorComandos {
  EducadorComandos(this._ref);

  final Ref _ref;

  EducadorRepository get _repo => _ref.read(educadorRepositoryProvider);

  Future<T> _mudar<T>(Future<T> Function(EducadorRepository repo) acao) async {
    try {
      return await acao(_repo);
    } finally {
      invalidarDerivados(_ref, Mudanca.vinculos);
    }
  }

  /// Ativa o modo educador. Devolve o perfil atualizado (com o papel EDUCADOR).
  Future<Perfil> ativarEducador() => _mudar((r) => r.ativarEducador());

  Future<void> convidar(String email) => _mudar((r) => r.convidar(email));

  Future<void> aceitar(String vinculoId) => _mudar((r) => r.aceitar(vinculoId));

  Future<void> recusar(String vinculoId) => _mudar((r) => r.recusar(vinculoId));

  Future<void> encerrar(String vinculoId) => _mudar((r) => r.encerrar(vinculoId));
}

final educadorComandosProvider =
    Provider<EducadorComandos>(EducadorComandos.new);
