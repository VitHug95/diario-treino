import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dados/invalidacao.dart';
import 'perfil_corporal_models.dart';
import 'perfil_corporal_repository.dart';

/// Escritas dos dados corporais (PBI-70): cada comando chama o repositório e, ao
/// fim, avisa o que mudou em [invalidarDerivados]. O peso pode ter virado uma
/// medida nova, então a mudança também atualiza a lista de medidas.
class PerfilCorporalComandos {
  PerfilCorporalComandos(this._ref);

  final Ref _ref;

  // Lido a cada chamada para os testes poderem trocar o repositório.
  PerfilCorporalRepository get _repo => _ref.read(perfilCorporalRepositoryProvider);

  Future<T> _mudar<T>(Future<T> Function(PerfilCorporalRepository repo) acao) async {
    try {
      return await acao(_repo);
    } finally {
      invalidarDerivados(_ref, Mudanca.perfilCorporal);
    }
  }

  /// Devolve os dados já recalculados (a TMB vem do back).
  Future<PerfilCorporal> salvar({
    SexoBiologico? sexo,
    DateTime? nascimento,
    int? alturaCm,
    double? pesoKg,
    DateTime? dataPeso,
  }) =>
      _mudar((r) => r.salvarPerfilCorporal(
            sexo: sexo,
            nascimento: nascimento,
            alturaCm: alturaCm,
            pesoKg: pesoKg,
            dataPeso: dataPeso,
          ));

  Future<void> limpar() => _mudar((r) => r.limparPerfilCorporal());

  /// TMB informada pelo atleta (PBI-98). Devolve os dados já recalculados.
  Future<PerfilCorporal> definirTmbManual(int kcal) =>
      _mudar((r) => r.definirTmbManual(kcal));

  /// Volta à TMB calculada.
  Future<void> usarTmbCalculada() => _mudar((r) => r.usarTmbCalculada());
}

final perfilCorporalComandosProvider =
    Provider<PerfilCorporalComandos>(PerfilCorporalComandos.new);
