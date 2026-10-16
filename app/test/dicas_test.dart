import 'package:diario_treino/core/tema/tema_controller.dart';
import 'package:diario_treino/features/inicio/dicas.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um "acesso ao app": container novo sobre as mesmas preferências.
Future<String?> _acessar(SharedPreferences prefs) async {
  final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  final dica = c.read(dicaDoAcessoProvider);
  // Ler de novo no mesmo acesso (trocar de aba) não troca a dica.
  expect(c.read(dicaDoAcessoProvider), dica);
  c.dispose();
  return dica;
}

void main() {
  test('PBI-60: cada acesso mostra a próxima dica e volta ao começo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(await _acessar(prefs), dicasDeTreino[0]);
    expect(await _acessar(prefs), dicasDeTreino[1]);

    // Depois da última, volta à primeira.
    await prefs.setInt('inicio_proxima_dica', dicasDeTreino.length - 1);
    expect(await _acessar(prefs), dicasDeTreino.last);
    expect(await _acessar(prefs), dicasDeTreino.first);
  });

  test('PBI-60: posição salva fora da lista (lista encolheu) não quebra', () {
    final dica = escolherDica(['a', 'b'], lerPosicao: () => 7, gravarPosicao: (_) {});
    expect(dica, 'b');
  });

  test('PBI-60: sem dicas devolve nulo', () {
    expect(escolherDica(const [], lerPosicao: () => 0, gravarPosicao: (_) {}), isNull);
  });

  test('PBI-60: falha ao ler ou gravar mostra a primeira', () {
    final dica = escolherDica(
      ['a', 'b'],
      lerPosicao: () => throw Exception('sem acesso'),
      gravarPosicao: (_) => throw Exception('sem acesso'),
    );
    expect(dica, 'a');
  });

  test('PBI-60: as dicas são curtas e não se repetem', () {
    expect(dicasDeTreino.toSet(), hasLength(dicasDeTreino.length));
    for (final d in dicasDeTreino) {
      expect(d.length, lessThanOrEqualTo(90), reason: d);
    }
  });
}
