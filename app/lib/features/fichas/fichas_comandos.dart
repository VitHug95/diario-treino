import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import 'fichas_repository.dart';
import 'plano_models.dart';

/// Escritas de planos e fichas (PBI-70). Cada uma chama o repositório e, ao
/// terminar (com sucesso ou erro, porque o estado no servidor pode ter
/// mudado), avisa quem lê via [invalidarDerivados]. As telas gravam por aqui,
/// nunca direto no repositório.
class FichasComandos {
  FichasComandos(this._ref);

  final Ref _ref;

  // Lido a cada chamada: os testes trocam o repositório por fakes.
  FichasRepository get _repo => _ref.read(fichasRepositoryProvider);

  Future<T> _mudar<T>(Future<T> Function(FichasRepository repo) acao) async {
    try {
      return await acao(_repo);
    } finally {
      invalidarDerivados(_ref, Mudanca.planos);
    }
  }

  // ---- Planos ----

  Future<String> garantirPlano() => _mudar((r) => r.garantirPlano());

  Future<String> criarPlano(String nome) => _mudar((r) => r.criarPlano(nome));

  Future<void> renomearPlano({required String planoId, required String nome}) =>
      _mudar((r) => r.renomearPlano(planoId: planoId, nome: nome));

  Future<void> definirEmUso(String planoId) =>
      _mudar((r) => r.definirEmUso(planoId));

  Future<String> duplicarPlano(String planoId) =>
      _mudar((r) => r.duplicarPlano(planoId));

  Future<void> excluirPlano(String planoId) =>
      _mudar((r) => r.excluirPlano(planoId));

  // ---- Fichas ----

  Future<String> adicionarFicha({
    required String planoId,
    required String nome,
    String? descricao,
  }) =>
      _mudar((r) =>
          r.adicionarFicha(planoId: planoId, nome: nome, descricao: descricao));

  Future<void> salvarComoFicha({
    required String nome,
    String? descricao,
    required List<String> exercicioIds,
  }) =>
      _mudar((r) => r.salvarComoFicha(
          nome: nome, descricao: descricao, exercicioIds: exercicioIds));

  Future<void> editarFicha({
    required String treinoId,
    required String nome,
    String? descricao,
  }) =>
      _mudar((r) =>
          r.editarFicha(treinoId: treinoId, nome: nome, descricao: descricao));

  Future<void> excluirFicha(String treinoId) =>
      _mudar((r) => r.excluirFicha(treinoId));

  // ---- Exercícios e alvos da ficha ----

  /// Adiciona vários exercícios na ordem dada (PBI-49) e avisa uma vez só.
  /// Devolve os ids que falharam; os outros ficam.
  Future<List<String>> adicionarExercicios({
    required String treinoId,
    required List<String> exercicioIds,
  }) =>
      _mudar((r) async {
        final falharam = <String>[];
        for (final id in exercicioIds) {
          try {
            await r.adicionarExercicio(treinoId: treinoId, exercicioId: id);
          } on FichasException {
            falharam.add(id);
          }
        }
        return falharam;
      });

  Future<void> removerExercicio({
    required String treinoId,
    required String treinoExercicioId,
  }) =>
      _mudar((r) => r.removerExercicio(
          treinoId: treinoId, treinoExercicioId: treinoExercicioId));

  Future<void> reordenarExercicios({
    required String treinoId,
    required List<String> treinoExercicioIds,
  }) =>
      _mudar((r) => r.reordenarExercicios(
          treinoId: treinoId, treinoExercicioIds: treinoExercicioIds));

  Future<void> definirAlvos({
    required String treinoId,
    required String treinoExercicioId,
    required int series,
    required int intensidadeMetricaId,
    double? intensidadeAlvo,
    required int volumeMetricaId,
    double? volumeAlvo,
    double? volumeAlvoMax,
    int? descansoSeg,
    String? instrucao,
    List<MarcadorRodada> marcadores = const [],
  }) =>
      _mudar((r) => r.definirAlvos(
            treinoId: treinoId,
            treinoExercicioId: treinoExercicioId,
            series: series,
            intensidadeMetricaId: intensidadeMetricaId,
            intensidadeAlvo: intensidadeAlvo,
            volumeMetricaId: volumeMetricaId,
            volumeAlvo: volumeAlvo,
            volumeAlvoMax: volumeAlvoMax,
            descansoSeg: descansoSeg,
            instrucao: instrucao,
            marcadores: marcadores,
          ));
}

/// Sem `watch`: o objeto vive o app todo e o `Ref` nunca é descartado no meio
/// de uma gravação.
final fichasComandosProvider = Provider<FichasComandos>(FichasComandos.new);
