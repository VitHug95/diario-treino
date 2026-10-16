import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import 'sessao_edicao.dart';
import 'sessao_repository.dart';

/// Escritas de sessão (PBI-70): salvar, editar e excluir. Ao terminar, avisam
/// quem lê (semana, último treino, progresso, histórico, plano) num lugar só.
class SessaoComandos {
  SessaoComandos(this._ref);

  final Ref _ref;

  SessaoRepository get _repo => _ref.read(sessaoRepositoryProvider);

  Future<T> _mudar<T>(Future<T> Function(SessaoRepository repo) acao) async {
    try {
      return await acao(_repo);
    } finally {
      invalidarDerivados(_ref, Mudanca.sessoes);
    }
  }

  Future<String> criarSessao({
    required String? treinoId,
    required DateTime data,
    int? duracaoMin,
    String? observacao,
    required List<ExercicioEdicao> exercicios,
  }) =>
      _mudar((r) => r.criarSessao(
            treinoId: treinoId,
            data: data,
            duracaoMin: duracaoMin,
            observacao: observacao,
            exercicios: exercicios,
          ));

  Future<void> editarSessao({
    required String sessaoId,
    required String? treinoId,
    required DateTime data,
    int? duracaoMin,
    String? observacao,
    required List<ExercicioEdicao> exercicios,
  }) =>
      _mudar((r) => r.editarSessao(
            sessaoId: sessaoId,
            treinoId: treinoId,
            data: data,
            duracaoMin: duracaoMin,
            observacao: observacao,
            exercicios: exercicios,
          ));

  Future<void> excluirSessao(String sessaoId) =>
      _mudar((r) => r.excluirSessao(sessaoId));
}

final sessaoComandosProvider = Provider<SessaoComandos>(SessaoComandos.new);
