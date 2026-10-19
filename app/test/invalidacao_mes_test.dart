import 'package:diario_treino/core/dados/invalidacao.dart';
import 'package:diario_treino/features/sessao/sessao_models.dart';
import 'package:diario_treino/features/sessao/sessao_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório fake que conta quantas vezes listarSessoes foi chamado, para
/// provar que o provider do mês é REFEITO após a invalidação (PBI-82/PBI-70).
class _SessoesContando extends SessaoRepository {
  _SessoesContando() : super(Dio());
  int chamadas = 0;

  @override
  Future<List<SessaoResumo>> listarSessoes({DateTime? de, DateTime? ate}) async {
    chamadas++;
    return const [];
  }
}

/// Expõe um Ref para chamar invalidarDerivados (como os *Comandos fazem).
final _gatilhoProvider = Provider<Ref>((ref) => ref);

void main() {
  test('Mudanca.sessoes refaz o sessoesDoMesProvider', () async {
    final repo = _SessoesContando();
    final container = ProviderContainer(overrides: [
      sessaoRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final mes = DateTime(2026, 10);

    // 1ª leitura: busca uma vez.
    await container.read(sessoesDoMesProvider(mes).future);
    expect(repo.chamadas, 1);

    // Mantém o provider "vivo" (observado), senão autoDispose o descarta e a
    // invalidação não teria efeito observável.
    final sub = container.listen(sessoesDoMesProvider(mes), (_, __) {});
    addTearDown(sub.close);

    // Uma escrita de sessão avisa pelo mapa de invalidação.
    invalidarDerivados(container.read(_gatilhoProvider), Mudanca.sessoes);

    // O provider foi refeito: nova busca.
    await container.read(sessoesDoMesProvider(mes).future);
    expect(repo.chamadas, 2);
  });
}
