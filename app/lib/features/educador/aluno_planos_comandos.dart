import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import '../fichas/fichas_repository.dart';

/// Escritas de plano do aluno pelo educador (PBI-88d). Criar o plano é a única
/// escrita específica do educador: montar as fichas (nome, exercícios, alvos)
/// reusa o `fichasComandosProvider`, porque a API resolve o atleta pelo
/// plano/treino e autoriza pelo vínculo. Grava-se por aqui, nunca direto no
/// repositório (PBI-70), e ao terminar avisa quem lê via [invalidarDerivados].
class AlunoPlanosComandos {
  AlunoPlanosComandos(this._ref);

  final Ref _ref;

  FichasRepository get _repo => _ref.read(fichasRepositoryProvider);

  /// Cria um plano para o aluno (autor = educador logado) e devolve o id. Sem
  /// vínculo ativo, a API responde 404 e o erro vira [FichasException].
  Future<String> criarPlanoParaAluno({
    required String atletaId,
    required String nome,
  }) async {
    try {
      return await _repo.criarPlano(nome, atletaId: atletaId);
    } finally {
      invalidarDerivados(_ref, Mudanca.planos);
    }
  }
}

/// Sem `watch`: o objeto vive o app todo e o `Ref` nunca é descartado no meio
/// de uma gravação.
final alunoPlanosComandosProvider =
    Provider<AlunoPlanosComandos>(AlunoPlanosComandos.new);
