import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/dados/invalidacao.dart';
import '../../core/tema/tema_controller.dart';
import 'sessao_edicao.dart';
import 'treino_ao_vivo_controller.dart';

/// Rascunho de um treino em andamento, guardado só no aparelho (PBI-37). Não há
/// estado "em andamento" no servidor: isto some ao finalizar ou descartar.
///
/// Guarda o suficiente para reabrir o registro de onde parou: a ficha (ou treino
/// livre), a data, a hora de início (para calcular a duração) e, por exercício,
/// se foi marcado como realizado e os valores digitados em cada série.
class TreinoEmAndamento {
  const TreinoEmAndamento({
    required this.treinoId,
    required this.treinoNome,
    required this.treinoLivre,
    required this.dataIso,
    required this.inicioMillis,
    required this.exercicios,
  });

  /// Nulo = treino livre (sem ficha).
  final String? treinoId;
  final String treinoNome;
  final bool treinoLivre;

  /// Data do treino (yyyy-MM-dd), que o atleta pode ter ajustado.
  final String dataIso;

  /// Instante em que o treino começou (epoch ms), para a duração automática.
  final int inicioMillis;

  final List<ExercicioEmAndamento> exercicios;

  DateTime get data => DateTime.parse(dataIso);
  DateTime get inicio => DateTime.fromMillisecondsSinceEpoch(inicioMillis);

  Map<String, dynamic> paraJson() => {
        'treinoId': treinoId,
        'treinoNome': treinoNome,
        'treinoLivre': treinoLivre,
        'dataIso': dataIso,
        'inicioMillis': inicioMillis,
        'exercicios': exercicios.map((e) => e.paraJson()).toList(),
      };

  factory TreinoEmAndamento.doJson(Map<String, dynamic> json) =>
      TreinoEmAndamento(
        treinoId: json['treinoId'] as String?,
        treinoNome: json['treinoNome'] as String,
        treinoLivre: json['treinoLivre'] as bool,
        dataIso: json['dataIso'] as String,
        inicioMillis: (json['inicioMillis'] as num).toInt(),
        exercicios: (json['exercicios'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(ExercicioEmAndamento.doJson)
            .toList(),
      );
}

/// Um exercício dentro do rascunho: identidade, metadados para montar o card e
/// o estado atual (realizado + séries com os valores digitados).
class ExercicioEmAndamento {
  const ExercicioEmAndamento({
    required this.treinoExercicioId,
    required this.exercicioId,
    required this.nome,
    required this.modalidade,
    required this.origemPreenchimento,
    required this.foraDaFicha,
    required this.realizado,
    required this.series,
    this.concluido = false,
  });

  final String? treinoExercicioId;
  final String exercicioId;
  final String nome;
  final String modalidade;
  final String? origemPreenchimento;
  final bool foraDaFicha;
  final bool realizado;
  final List<SerieEmAndamento> series;

  /// "Concluir exercício" (PBI-65). Rascunhos antigos não têm o campo: falso.
  final bool concluido;

  Map<String, dynamic> paraJson() => {
        'treinoExercicioId': treinoExercicioId,
        'exercicioId': exercicioId,
        'nome': nome,
        'modalidade': modalidade,
        'origemPreenchimento': origemPreenchimento,
        'foraDaFicha': foraDaFicha,
        'realizado': realizado,
        'concluido': concluido,
        'series': series.map((s) => s.paraJson()).toList(),
      };

  factory ExercicioEmAndamento.doJson(Map<String, dynamic> json) =>
      ExercicioEmAndamento(
        treinoExercicioId: json['treinoExercicioId'] as String?,
        exercicioId: json['exercicioId'] as String,
        nome: json['nome'] as String,
        modalidade: json['modalidade'] as String,
        origemPreenchimento: json['origemPreenchimento'] as String?,
        foraDaFicha: json['foraDaFicha'] as bool,
        realizado: json['realizado'] as bool,
        concluido: json['concluido'] as bool? ?? false,
        series: (json['series'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SerieEmAndamento.doJson)
            .toList(),
      );
}

/// Uma série do rascunho: a identidade da métrica (para remontar) e os textos
/// digitados (intensidade/volume/descanso), que podem estar vazios.
class SerieEmAndamento {
  const SerieEmAndamento({
    required this.rodada,
    required this.ordem,
    required this.tipo,
    required this.intensidadeMetricaId,
    required this.intensidadeMetricaCodigo,
    required this.intensidadeMetricaNome,
    required this.intensidadeTexto,
    required this.volumeMetricaId,
    required this.volumeMetricaCodigo,
    required this.volumeMetricaNome,
    required this.volumeTexto,
    required this.descansoTexto,
    this.marcador = 'VALIDA',
    this.feita = false,
  });

  final int rodada;
  final int ordem;
  final String tipo;
  final int intensidadeMetricaId;
  final String intensidadeMetricaCodigo;
  final String intensidadeMetricaNome;
  final String intensidadeTexto;
  final int volumeMetricaId;
  final String volumeMetricaCodigo;
  final String volumeMetricaNome;
  final String volumeTexto;
  final String descansoTexto;

  /// Tag da série (TV-1), preservada no rascunho ao reabrir.
  final String marcador;

  /// Check por série (TV-3): true quando o atleta concluiu esta série.
  final bool feita;

  Map<String, dynamic> paraJson() => {
        'rodada': rodada,
        'ordem': ordem,
        'tipo': tipo,
        'intensidadeMetricaId': intensidadeMetricaId,
        'intensidadeMetricaCodigo': intensidadeMetricaCodigo,
        'intensidadeMetricaNome': intensidadeMetricaNome,
        'intensidadeTexto': intensidadeTexto,
        'volumeMetricaId': volumeMetricaId,
        'volumeMetricaCodigo': volumeMetricaCodigo,
        'volumeMetricaNome': volumeMetricaNome,
        'volumeTexto': volumeTexto,
        'descansoTexto': descansoTexto,
        'marcador': marcador,
        'feita': feita,
      };

  factory SerieEmAndamento.doJson(Map<String, dynamic> json) => SerieEmAndamento(
        rodada: (json['rodada'] as num).toInt(),
        ordem: (json['ordem'] as num).toInt(),
        tipo: json['tipo'] as String,
        intensidadeMetricaId: (json['intensidadeMetricaId'] as num).toInt(),
        intensidadeMetricaCodigo: json['intensidadeMetricaCodigo'] as String,
        intensidadeMetricaNome: json['intensidadeMetricaNome'] as String,
        intensidadeTexto: json['intensidadeTexto'] as String,
        volumeMetricaId: (json['volumeMetricaId'] as num).toInt(),
        volumeMetricaCodigo: json['volumeMetricaCodigo'] as String,
        volumeMetricaNome: json['volumeMetricaNome'] as String,
        volumeTexto: json['volumeTexto'] as String,
        descansoTexto: json['descansoTexto'] as String,
        marcador: json['marcador'] as String? ?? 'VALIDA',
        feita: json['feita'] as bool? ?? false,
      );
}

/// Lê e grava o único treino em andamento no `shared_preferences` (PBI-37).
/// Só existe um por vez: gravar substitui o anterior.
class RascunhoTreinoService {
  RascunhoTreinoService(this._prefs, {void Function()? aoMudar})
      : _aoMudar = aoMudar;

  final SharedPreferences _prefs;

  /// Avisa quem lê o treino em andamento depois de gravar ou apagar (PBI-70).
  final void Function()? _aoMudar;

  static const _chave = 'treino_em_andamento';

  TreinoEmAndamento? carregar() {
    final texto = _prefs.getString(_chave);
    if (texto == null || texto.isEmpty) return null;
    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      return TreinoEmAndamento.doJson(json);
    } catch (_) {
      // Rascunho corrompido ou de uma versão antiga: descarta sem quebrar.
      _prefs.remove(_chave);
      return null;
    }
  }

  // O shared_preferences atualiza a cópia em memória na hora; o aviso pode
  // sair antes de o disco terminar.
  Future<void> salvar(TreinoEmAndamento treino) {
    final gravacao = _prefs.setString(_chave, jsonEncode(treino.paraJson()));
    _aoMudar?.call();
    return gravacao;
  }

  Future<void> limpar() {
    final remocao = _prefs.remove(_chave);
    _aoMudar?.call();
    return remocao;
  }
}

/// Converte o estado vivo da tela ([ExercicioEdicao]) para o rascunho e de volta.
/// Fica aqui (e não em sessao_edicao) para não criar dependência circular.
extension ConversaoRascunho on ExercicioEmAndamento {
  ExercicioEdicao paraEdicao() => ExercicioEdicao(
        treinoExercicioId: treinoExercicioId,
        exercicioId: exercicioId,
        nome: nome,
        grupoMuscular: null,
        modalidade: modalidade,
        origemPreenchimento: origemPreenchimento,
        realizado: realizado,
        foraDaFicha: foraDaFicha,
        series: series
            .map((s) => SerieEdicao(
                  rodada: s.rodada,
                  ordem: s.ordem,
                  tipo: s.tipo,
                  intensidadeMetricaId: s.intensidadeMetricaId,
                  intensidadeMetricaCodigo: s.intensidadeMetricaCodigo,
                  intensidadeMetricaNome: s.intensidadeMetricaNome,
                  intensidadeTexto: s.intensidadeTexto,
                  volumeMetricaId: s.volumeMetricaId,
                  volumeMetricaCodigo: s.volumeMetricaCodigo,
                  volumeMetricaNome: s.volumeMetricaNome,
                  volumeTexto: s.volumeTexto,
                  descansoTexto: s.descansoTexto,
                  marcador: s.marcador,
                  feita: s.feita,
                ))
            .toList(),
      )..concluido = concluido;
}

/// Serializa um [ExercicioEdicao] vivo (com os textos atuais) para o rascunho.
ExercicioEmAndamento exercicioParaRascunho(ExercicioEdicao e) =>
    ExercicioEmAndamento(
      treinoExercicioId: e.treinoExercicioId,
      exercicioId: e.exercicioId,
      nome: e.nome,
      modalidade: e.modalidade,
      origemPreenchimento: e.origemPreenchimento,
      foraDaFicha: e.foraDaFicha,
      realizado: e.realizado,
      concluido: e.concluido,
      series: e.series
          .map((s) => SerieEmAndamento(
                rodada: s.rodada,
                ordem: s.ordem,
                tipo: s.tipo,
                intensidadeMetricaId: s.intensidadeMetricaId,
                intensidadeMetricaCodigo: s.intensidadeMetricaCodigo,
                intensidadeMetricaNome: s.intensidadeMetricaNome,
                intensidadeTexto: s.intensidadeTexto,
                volumeMetricaId: s.volumeMetricaId,
                volumeMetricaCodigo: s.volumeMetricaCodigo,
                volumeMetricaNome: s.volumeMetricaNome,
                volumeTexto: s.volumeTexto,
                descansoTexto: s.descansoTexto,
                marcador: s.marcador,
                feita: s.feita,
              ))
          .toList(),
    );

final rascunhoTreinoServiceProvider = Provider<RascunhoTreinoService>(
  (ref) => RascunhoTreinoService(
    ref.watch(sharedPreferencesProvider),
    aoMudar: () => invalidarDerivados(ref, Mudanca.treinoEmAndamento),
  ),
);

/// Treino em andamento atual (ou nulo), a única fonte para a Início ("Continuar
/// treino") e o plano (ficha "Em andamento"), PBI-67.
///
/// Deriva do treino ao vivo, que é reativo: iniciar, marcar série, salvar ou
/// descartar já atualizam quem observa, sem invalidar nos chamadores. Sem treino
/// ao vivo carregado (app reaberto, ou o registro antigo com a flag desligada),
/// cai no rascunho gravado no aparelho.
final treinoEmAndamentoProvider = Provider<TreinoEmAndamento?>((ref) {
  final vivo = ref.watch(treinoAoVivoControllerProvider);
  if (vivo != null) return rascunhoDoEstado(vivo);
  // Muda a cada gravação do rascunho (PBI-70): relê o aparelho.
  ref.watch(versaoRascunhoTreinoProvider);
  return ref.watch(rascunhoTreinoServiceProvider).carregar();
});

/// Contador que avança a cada gravação ou remoção do rascunho (PBI-70). O
/// serviço não pode invalidar quem depende dele (o Riverpod acusa ciclo), então
/// avisa por aqui, via [invalidarDerivados].
final versaoRascunhoTreinoProvider =
    NotifierProvider<VersaoRascunhoTreino, int>(VersaoRascunhoTreino.new);

class VersaoRascunhoTreino extends Notifier<int> {
  @override
  int build() => 0;

  void avancar() => state++;
}

/// Tempo de treino para o leitor de tela (PBI-67): "1 minuto", "12 minutos".
/// O cronômetro visível não entra no rótulo para não ser lido a cada segundo.
String minutosEmAndamento(DateTime agora, DateTime inicio) {
  final m = agora.difference(inicio).inMinutes.clamp(0, 1 << 30);
  return m == 1 ? '1 minuto' : '$m minutos';
}
