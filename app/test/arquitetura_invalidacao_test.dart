// PBI-70: teste de arquitetura (busca no código). Garante que a regra "quem
// muda o dado avisa quem lê, num lugar só" não volte a se espalhar:
//
// 1. `invalidate(` só existe em lib/core/dados/invalidacao.dart (o mapa de
//    invalidação). "Tentar de novo" nas telas usa `ref.refresh` da própria
//    leitura, ou `tentarDeNovo`, que mora no mesmo arquivo.
// 2. Fora dos repositórios e dos comandos, ninguém chama um método de escrita
//    do repositório direto (isso pularia o aviso). Grava-se pelos *Comandos.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _mapa = 'lib/core/dados/invalidacao.dart';

/// Métodos que gravam no servidor, por repositório.
const _escritas = [
  'garantirPlano', 'criarPlano', 'renomearPlano', 'definirEmUso',
  'duplicarPlano', 'excluirPlano', 'adicionarFicha', 'salvarComoFicha',
  'editarFicha', 'excluirFicha', 'adicionarExercicio', 'removerExercicio',
  'reordenarExercicios', 'definirAlvos', // fichas e planos
  'criarSessao', 'editarSessao', 'excluirSessao', // sessões
  'criarExercicio', // catálogo
];

Iterable<File> _arquivosDart() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _caminho(File f) => f.path.replaceAll(r'\', '/');

/// Linhas de código (sem comentários de linha inteira).
Iterable<(int, String)> _linhas(File f) sync* {
  final linhas = f.readAsLinesSync();
  for (var i = 0; i < linhas.length; i++) {
    final l = linhas[i].trimLeft();
    if (l.startsWith('//')) continue;
    yield (i + 1, linhas[i]);
  }
}

void main() {
  test('Só o mapa de invalidação chama invalidate', () {
    final violacoes = <String>[];
    for (final f in _arquivosDart()) {
      if (_caminho(f) == _mapa) continue;
      for (final (n, l) in _linhas(f)) {
        if (l.contains('invalidate(')) violacoes.add('${_caminho(f)}:$n  ${l.trim()}');
      }
    }
    expect(violacoes, isEmpty,
        reason: 'Use um *Comandos (que chama invalidarDerivados) para gravar, '
            'e ref.refresh/tentarDeNovo para "Tentar de novo".');
  });

  test('Telas não chamam escrita do repositório direto', () {
    // `ref.read(xRepositoryProvider).escrita(` ou `repo.escrita(` depois de
    // `final repo = ref.read(xRepositoryProvider)`.
    final direta = RegExp(
        r'RepositoryProvider\)\s*\.\s*(' + _escritas.join('|') + r')\(');
    final viaVariavel = RegExp(r'final (\w+) = ref\.read\(\w+RepositoryProvider\)');

    final violacoes = <String>[];
    for (final f in _arquivosDart()) {
      final p = _caminho(f);
      if (p.endsWith('_repository.dart') || p.endsWith('_comandos.dart')) continue;
      final texto = f.readAsStringSync();
      for (final m in direta.allMatches(texto)) {
        violacoes.add('$p: ${m.group(0)}');
      }
      for (final m in viaVariavel.allMatches(texto)) {
        final nome = m.group(1)!;
        final uso = RegExp('\\b$nome\\.(${_escritas.join('|')})\\(');
        for (final u in uso.allMatches(texto)) {
          violacoes.add('$p: ${u.group(0)}');
        }
      }
    }
    expect(violacoes, isEmpty,
        reason: 'Grave por fichasComandosProvider, sessaoComandosProvider ou '
            'catalogoComandosProvider (PBI-70).');
  });

  test('O próprio teste enxerga as telas (sanidade)', () {
    expect(File(_mapa).existsSync(), isTrue);
    expect(_arquivosDart().where((f) => _caminho(f).endsWith('_screen.dart')),
        isNotEmpty);
  });
}
