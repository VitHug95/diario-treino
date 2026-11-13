import 'sessao_edicao.dart';

/// Regras do bloco conjugado no treino ao vivo (PBI-102), sem tela.
///
/// A rodada `r` (1-based) de um bloco é a série de posição `r` de cada membro
/// que tem ao menos `r` séries. Rodadas desiguais: no item 1 da ficha do PO
/// (prancha 2, elevação 4), as rodadas 3 e 4 só têm a elevação.

/// Um item da tela 14: um exercício avulso ou um bloco (índices na lista).
sealed class GrupoAoVivo {
  const GrupoAoVivo();

  /// Índices dos exercícios do grupo na lista do treino.
  List<int> get indices;
}

class GrupoAvulso extends GrupoAoVivo {
  const GrupoAvulso(this.indice);
  final int indice;

  @override
  List<int> get indices => [indice];
}

class GrupoBloco extends GrupoAoVivo {
  const GrupoBloco(this.blocoId, this.indices);
  final String blocoId;

  @override
  final List<int> indices;
}

/// Agrupa os exercícios: membros vizinhos com o mesmo `blocoId` viram um bloco.
/// Um "bloco" com um exercício só é tratado como avulso.
List<GrupoAoVivo> gruposDoTreino(List<ExercicioEdicao> exercicios) {
  final grupos = <GrupoAoVivo>[];
  var i = 0;
  while (i < exercicios.length) {
    final bloco = exercicios[i].blocoId;
    var fim = i + 1;
    if (bloco != null) {
      while (fim < exercicios.length && exercicios[fim].blocoId == bloco) {
        fim++;
      }
    }
    if (bloco != null && fim - i >= 2) {
      grupos.add(GrupoBloco(bloco, [for (var k = i; k < fim; k++) k]));
    } else {
      grupos.add(GrupoAvulso(i));
      fim = i + 1;
    }
    i = fim;
  }
  return grupos;
}

/// Posição (0-based) do grupo que contém o exercício de índice [indice].
int grupoDoExercicio(List<GrupoAoVivo> grupos, int indice) =>
    grupos.indexWhere((g) => g.indices.contains(indice));

/// Posição (0-based) do bloco [blocoId], ou -1.
int grupoDoBloco(List<GrupoAoVivo> grupos, String blocoId) =>
    grupos.indexWhere((g) => g is GrupoBloco && g.blocoId == blocoId);

/// Rodadas do bloco: o maior número de séries entre os membros.
int rodadasDoBloco(List<ExercicioEdicao> membros) =>
    membros.fold(0, (maior, m) => m.series.length > maior ? m.series.length : maior);

/// Os pares (membro, série) da rodada [rodada], na ordem do bloco.
List<(ExercicioEdicao, SerieEdicao)> seriesDaRodada(
        List<ExercicioEdicao> membros, int rodada) =>
    [
      for (final m in membros)
        if (rodada >= 1 && m.series.length >= rodada) (m, m.series[rodada - 1]),
    ];

/// A rodada está fechada quando todas as séries dela estão marcadas.
bool rodadaFechada(List<ExercicioEdicao> membros, int rodada) {
  final series = seriesDaRodada(membros, rodada);
  return series.isNotEmpty && series.every((p) => p.$2.feita);
}

/// Quantas rodadas estão fechadas ("2 de 4 rodadas").
int rodadasFeitas(List<ExercicioEdicao> membros) {
  var n = 0;
  for (var r = 1; r <= rodadasDoBloco(membros); r++) {
    if (rodadaFechada(membros, r)) n++;
  }
  return n;
}

/// Rodada atual: a primeira que ainda não fechou; com todas fechadas, a última.
/// É calculada pelas marcações, então o "Continuar treino" volta na rodada
/// certa sem guardar nada além do check de cada série.
int rodadaAtual(List<ExercicioEdicao> membros) {
  final total = rodadasDoBloco(membros);
  for (var r = 1; r <= total; r++) {
    if (!rodadaFechada(membros, r)) return r;
  }
  return total == 0 ? 1 : total;
}

/// Descanso do bloco a disparar: só quando ele é maior que zero.
int? descansoQueDispara(int? descansoDoBloco) =>
    (descansoDoBloco ?? 0) > 0 ? descansoDoBloco : null;

/// Descanso de cada série de bloco ao salvar (PBI-102): o do bloco vai só na
/// última série marcada de cada rodada; as outras séries do bloco ficam sem
/// descanso. Séries avulsas não entram no mapa (seguem com o próprio).
Map<SerieEdicao, String> descansosParaSalvar(
  List<ExercicioEdicao> exercicios,
  Map<String, int?> descansoDosBlocos,
) {
  final resultado = <SerieEdicao, String>{};
  for (final grupo in gruposDoTreino(exercicios)) {
    if (grupo is! GrupoBloco) continue;
    final membros = [for (final i in grupo.indices) exercicios[i]];
    final descanso = descansoQueDispara(descansoDosBlocos[grupo.blocoId]);
    for (var r = 1; r <= rodadasDoBloco(membros); r++) {
      final feitas = seriesDaRodada(membros, r).where((p) => p.$2.feita).toList();
      for (var k = 0; k < feitas.length; k++) {
        final ultima = k == feitas.length - 1;
        resultado[feitas[k].$2] = ultima && descanso != null ? '$descanso' : '';
      }
    }
  }
  return resultado;
}

/// "Rodada 2 de 4, adução com a bola e agachamento livre" (leitor de tela).
String rotuloFaladoRodada(List<ExercicioEdicao> membros, int rodada) {
  final nomes = seriesDaRodada(membros, rodada).map((p) => p.$1.nome.toLowerCase()).toList();
  final lista = switch (nomes.length) {
    0 => '',
    1 => nomes.first,
    _ => '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}',
  };
  return 'Rodada $rodada de ${rodadasDoBloco(membros)}, $lista';
}
