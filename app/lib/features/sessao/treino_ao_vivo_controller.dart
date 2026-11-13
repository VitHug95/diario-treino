import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/relogio.dart';
import 'bloco_ao_vivo.dart';
import 'sessao_edicao.dart';
import 'treino_em_andamento.dart';

/// Estado vivo de um treino ao vivo (TV-3). Guarda os exercícios em edição
/// (com os `TextEditingController` de cada série), a identidade da ficha e a
/// hora de início. É mantido em memória pelo [TreinoAoVivoController] e
/// espelhado no rascunho local a cada mudança (autosave).
///
/// A tela 14 e a tela do exercício observam o MESMO controller, então
/// "completar série" numa reflete o contador na outra sem round-trip de
/// serialização. [versao] muda a cada mutação para o Riverpod notificar sem
/// recriar os controllers de texto.
class TreinoAoVivoEstado {
  const TreinoAoVivoEstado({
    required this.treinoId,
    required this.treinoNome,
    required this.treinoLivre,
    required this.data,
    required this.inicio,
    required this.exercicios,
    required this.versao,
    this.descansoDosBlocos = const {},
  });

  /// Descanso de cada bloco conjugado (PBI-102), por id do bloco. Nulo ou 0 =
  /// sem descanso. Os membros são os exercícios com o mesmo locoId.
  final Map<String, int?> descansoDosBlocos;

  /// Nulo = treino livre (sem ficha).
  final String? treinoId;
  final String treinoNome;
  final bool treinoLivre;
  final DateTime data;
  final DateTime inicio;
  final List<ExercicioEdicao> exercicios;
  final int versao;

  TreinoAoVivoEstado _bump({List<ExercicioEdicao>? exercicios}) =>
      TreinoAoVivoEstado(
        treinoId: treinoId,
        treinoNome: treinoNome,
        treinoLivre: treinoLivre,
        data: data,
        inicio: inicio,
        exercicios: exercicios ?? this.exercicios,
        versao: versao + 1,
        descansoDosBlocos: descansoDosBlocos,
      );

  /// Total de séries de todos os exercícios.
  int get totalSeries =>
      exercicios.fold(0, (soma, e) => soma + e.series.length);

  /// Séries marcadas como feitas (check por série, TV-3).
  int get seriesFeitas => exercicios.fold(
      0, (soma, e) => soma + e.series.where((s) => s.feita).length);

  /// Exercícios concluídos: todas as séries feitas, ou encerrado pelo
  /// "Concluir exercício" (PBI-65) com ao menos uma série feita. Concluído sem
  /// nenhuma série feita continua "Não realizado".
  int get exerciciosConcluidos => exercicios
      .where((e) =>
          e.series.isNotEmpty &&
          (e.series.every((s) => s.feita) ||
              (e.concluido && e.series.any((s) => s.feita))))
      .length;
}

/// Controla o treino ao vivo: inicia (do rascunho da ficha ou de um rascunho
/// salvo), persiste cada mudança no [RascunhoTreinoService] e limpa ao
/// finalizar/descartar. É um [Notifier] para a tela 14 e a tela do exercício
/// compartilharem o estado.
class TreinoAoVivoController extends Notifier<TreinoAoVivoEstado?> {
  @override
  TreinoAoVivoEstado? build() => null;

  RascunhoTreinoService get _rascunho =>
      ref.read(rascunhoTreinoServiceProvider);

  /// Inicia um treino ao vivo com os exercícios já montados (do rascunho da
  /// ficha, PBI-15, ou do rascunho avulso). Grava o estado inicial para
  /// "Continuar treino" valer de cara.
  void iniciar({
    required String? treinoId,
    required String treinoNome,
    required bool treinoLivre,
    required DateTime data,
    required List<ExercicioEdicao> exercicios,
    DateTime? inicio,
    Map<String, int?> descansoDosBlocos = const {},
  }) {
    state = TreinoAoVivoEstado(
      treinoId: treinoId,
      treinoNome: treinoNome,
      treinoLivre: treinoLivre,
      data: data,
      inicio: inicio ?? ref.read(relogioProvider).agora(),
      exercicios: exercicios,
      versao: 0,
      descansoDosBlocos: descansoDosBlocos,
    );
    _persistir();
  }

  /// Reabre o treino em andamento salvo no aparelho, se houver. Devolve true
  /// quando havia um rascunho para retomar.
  bool retomarDoRascunho() {
    final salvo = _rascunho.carregar();
    if (salvo == null) return false;
    state = TreinoAoVivoEstado(
      treinoId: salvo.treinoId,
      treinoNome: salvo.treinoNome,
      treinoLivre: salvo.treinoLivre,
      data: salvo.data,
      inicio: salvo.inicio,
      exercicios: salvo.exercicios.map((e) => e.paraEdicao()).toList(),
      versao: 0,
      descansoDosBlocos: salvo.descansoDosBlocos,
    );
    return true;
  }

  /// Aplica uma mutação na lista viva e re-emite o estado (bump de versão) +
  /// autosave. Usado por marcar série, adicionar/remover série, trocar tag etc.
  void mudar(void Function(TreinoAoVivoEstado estado) acao) {
    final atual = state;
    if (atual == null) return;
    acao(atual);
    state = atual._bump();
    _persistir();
  }

  /// Marca/desmarca uma série como feita (check por série, TV-3).
  void definirSerieFeita(ExercicioEdicao exercicio, SerieEdicao serie, bool feita) {
    mudar((_) {
      serie.feita = feita;
      // "Realizado" do exercício acompanha ter ao menos uma série feita, para
      // o POST /sessoes (que grava só exercícios realizados) continuar certo.
      exercicio.realizado = exercicio.series.any((s) => s.feita);
    });
  }

  /// "Concluir exercício" (PBI-65): marca o exercício como encerrado. Não
  /// marca séries por baixo dos panos: as pendentes ficam de fora ao salvar.
  void concluirExercicio(ExercicioEdicao exercicio) {
    mudar((_) => exercicio.concluido = true);
  }

  /// "Rodada feita" (PBI-102): marca de uma vez as séries da rodada em todos
  /// os membros do bloco que têm aquela série (rodadas desiguais).
  void marcarRodada(List<ExercicioEdicao> membros, int rodada) {
    mudar((_) {
      for (final (membro, serie) in seriesDaRodada(membros, rodada)) {
        serie.feita = true;
        membro.realizado = true;
      }
    });
  }

  /// "Concluir bloco" (PBI-102): o "Concluir exercício" de cada membro. As
  /// séries não marcadas ficam de fora ao salvar, como hoje.
  void concluirBloco(List<ExercicioEdicao> membros) {
    mudar((_) {
      for (final m in membros) {
        m.concluido = true;
      }
    });
  }

  /// Adiciona um exercício fora da ficha (PBI-17) ao treino em andamento.
  void adicionarExercicio(ExercicioEdicao exercicio) {
    mudar((estado) => estado.exercicios.add(exercicio));
  }

  /// Persiste o estado atual no rascunho local (autosave). Vale desde o
  /// `iniciar`, mesmo com 0 séries marcadas.
  void _persistir() {
    final atual = state;
    if (atual == null) return;
    _rascunho.salvar(rascunhoDoEstado(atual));
  }

  /// Encerra o treino (finalizar ou descartar): apaga o rascunho e zera o estado.
  void encerrar() {
    _rascunho.limpar();
    state = null;
  }

}

/// Converte o estado vivo no formato do rascunho (o mesmo que vai para o
/// aparelho e que a Início e o plano leem como "treino em andamento").
TreinoEmAndamento rascunhoDoEstado(TreinoAoVivoEstado e) => TreinoEmAndamento(
      treinoId: e.treinoId,
      treinoNome: e.treinoNome,
      treinoLivre: e.treinoLivre,
      dataIso: _soDataIso(e.data),
      inicioMillis: e.inicio.millisecondsSinceEpoch,
      exercicios: e.exercicios.map(exercicioParaRascunho).toList(),
      descansoDosBlocos: e.descansoDosBlocos,
    );

String _soDataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Treino ao vivo em andamento (TV-3). Nulo quando não há treino aberto.
final treinoAoVivoControllerProvider =
    NotifierProvider<TreinoAoVivoController, TreinoAoVivoEstado?>(
  TreinoAoVivoController.new,
);
