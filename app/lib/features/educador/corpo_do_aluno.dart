import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import '../../core/relogio.dart';
import '../medidas/medidas_formato.dart';
import '../medidas/medidas_models.dart';
import '../medidas/perfil_corporal_models.dart';

/// O corpo do aluno visto pelo educador (E12 / PBI-95 e 96). Só leitura; cada
/// seção vem nula quando o aluno a deixou trancada.
class CorpoDoAluno {
  const CorpoDoAluno({
    required this.dadosCorporaisCompartilhados,
    required this.dadosCorporais,
    required this.medidasCompartilhadas,
    required this.medidas,
  });

  final bool dadosCorporaisCompartilhados;
  final PerfilCorporal? dadosCorporais;
  final bool medidasCompartilhadas;
  final ResumoMedidas? medidas;

  factory CorpoDoAluno.doJson(Map<String, dynamic> json) => CorpoDoAluno(
        dadosCorporaisCompartilhados: json['dadosCorporaisCompartilhados'] as bool? ?? false,
        dadosCorporais: json['dadosCorporais'] == null
            ? null
            : PerfilCorporal.doJson(json['dadosCorporais'] as Map<String, dynamic>),
        medidasCompartilhadas: json['medidasCompartilhadas'] as bool? ?? false,
        medidas: json['medidas'] == null
            ? null
            : ResumoMedidas.doJson(json['medidas'] as Map<String, dynamic>),
      );
}

/// O aluno trancou as medidas (403 `corpo-nao-compartilhado`): a tela mostra o
/// cadeado, não um erro.
class CorpoTrancadoException implements Exception {
  const CorpoTrancadoException();
}

/// `GET /alunos/{atletaId}/corpo` e a evolução de uma medida do aluno.
class CorpoDoAlunoRepository {
  CorpoDoAlunoRepository(this._dio);

  final Dio _dio;

  Future<CorpoDoAluno> obter(String atletaId) async {
    final resposta = await _dio.get<Map<String, dynamic>>('/alunos/$atletaId/corpo');
    return CorpoDoAluno.doJson(resposta.data!);
  }

  Future<EvolucaoMedida> obterEvolucao(String atletaId, TipoMedida tipo, {DateTime? de}) async {
    try {
      final resposta = await _dio.get<Map<String, dynamic>>(
        '/alunos/$atletaId/medidas/${tipo.codigo}/evolucao',
        queryParameters: {if (de != null) 'de': dataParaApi(de)},
      );
      return EvolucaoMedida.doJson(resposta.data!, tipo);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) throw const CorpoTrancadoException();
      rethrow;
    }
  }
}

final corpoDoAlunoRepositoryProvider = Provider<CorpoDoAlunoRepository>(
  (ref) => CorpoDoAlunoRepository(ref.watch(dioProvider)),
);

/// Corpo do aluno (dados e últimas medidas), por aluno.
final corpoDoAlunoProvider = FutureProvider.autoDispose.family<CorpoDoAluno, String>(
  (ref, atletaId) => ref.watch(corpoDoAlunoRepositoryProvider).obter(atletaId),
);

typedef ChaveEvolucaoDoAluno = ({String atletaId, TipoMedida tipo, PeriodoMedida periodo});

/// Evolução de uma medida do aluno no período (como a do atleta, PBI-94).
final evolucaoMedidaDoAlunoProvider =
    FutureProvider.autoDispose.family<EvolucaoMedida, ChaveEvolucaoDoAluno>((ref, chave) {
  final dias = chave.periodo.dias;
  DateTime? de;
  if (dias != null) {
    final agora = ref.watch(relogioProvider).agora();
    de = DateTime(agora.year, agora.month, agora.day).subtract(Duration(days: dias));
  }
  return ref
      .watch(corpoDoAlunoRepositoryProvider)
      .obterEvolucao(chave.atletaId, chave.tipo, de: de);
});
