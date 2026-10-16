import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema/tema_controller.dart';

/// Dicas de treino da Início (PBI-60, opção A: conteúdo no app). Para mudar ou
/// acrescentar, edite esta lista e publique o front. Frases curtas, gerais, sem
/// orientação médica.
const dicasDeTreino = <String>[
  'Se hidrate durante o treino: tenha uma garrafa de água por perto.',
  'Antes de iniciar séries com cargas altas, aqueça.',
  'Faça uma ou duas séries leves do exercício antes das séries de trabalho.',
  'Execução vem antes da carga: só aumente o peso quando o movimento estiver firme.',
  'Respeite o descanso entre as séries. Ele também faz parte do treino.',
  'Anote como foi o treino. Olhar a evolução depois ajuda a manter o ritmo.',
  'Dormir bem ajuda na recuperação tanto quanto o próprio treino.',
  'Dor diferente do cansaço normal é sinal para parar e avaliar.',
  'Controle a descida do peso. A fase lenta do movimento também conta.',
  'Mantenha a respiração: não prenda o ar durante toda a série.',
  'Constância vale mais que um treino perfeito. Volte no próximo dia.',
  'Aumente a carga aos poucos. Pequenos passos somam muito em semanas.',
  'Use a observação do dia para lembrar o que incomodou ou deu certo.',
  'Alongue e solte a musculatura ao terminar, com calma.',
];

/// Chave da próxima dica a mostrar, no aparelho.
const _chaveProximaDica = 'inicio_proxima_dica';

/// Dica deste acesso ao app (PBI-60). Lida uma vez por execução: o provider
/// não é autoDispose, então trocar de aba ou voltar à Início mantém a mesma
/// dica. Já deixa salva a posição da próxima, para o próximo acesso.
///
/// Nulo sem dicas. Falha ao ler ou gravar a posição: mostra a primeira.
final dicaDoAcessoProvider = Provider<String?>((ref) {
  return escolherDica(
    dicasDeTreino,
    lerPosicao: () => ref.read(sharedPreferencesProvider).getInt(_chaveProximaDica),
    // `ignore()`: falha assíncrona ao gravar também não quebra a Início.
    gravarPosicao: (p) =>
        ref.read(sharedPreferencesProvider).setInt(_chaveProximaDica, p).ignore(),
  );
});

/// Regra pura da rotação: devolve a dica da posição salva e grava a seguinte
/// (volta ao começo depois da última).
String? escolherDica(
  List<String> dicas, {
  required int? Function() lerPosicao,
  required void Function(int proxima) gravarPosicao,
}) {
  if (dicas.isEmpty) return null;
  var atual = 0;
  try {
    atual = (lerPosicao() ?? 0) % dicas.length;
  } catch (_) {
    atual = 0;
  }
  try {
    gravarPosicao((atual + 1) % dicas.length);
  } catch (_) {
    // Sem gravar, o próximo acesso repete a dica. Não quebra a Início.
  }
  return dicas[atual];
}
