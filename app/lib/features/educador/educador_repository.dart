import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import '../auth/perfil_api.dart';
import 'educador_models.dart';

/// Erro de negócio do modo educador (vínculo/convite), com mensagem amigável.
class EducadorException implements Exception {
  const EducadorException(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Acesso aos endpoints de vínculo educador-aluno (PBI-85/88) via API.
class EducadorRepository {
  EducadorRepository(this._dio);

  final Dio _dio;

  /// Ativa o modo educador: concede o papel EDUCADOR ao usuário logado
  /// (idempotente). Devolve o perfil atualizado com os papéis.
  Future<Perfil> ativarEducador() async {
    try {
      final resposta = await _dio.post<Map<String, dynamic>>('/me/papeis/educador');
      return Perfil.doJson(resposta.data!);
    } on DioException catch (e) {
      throw EducadorException(_traduzir(e));
    }
  }

  /// Convida um aluno por e-mail (cria o vínculo pendente).
  Future<void> convidar(String email) => _executar(
        () => _dio.post<void>('/vinculos', data: {'email': email}),
        traduzir: _traduzirConvite,
      );

  /// Convites pendentes em que o usuário logado é o aluno.
  Future<List<ConvitePendente>> listarConvitesPendentes() async {
    final resposta = await _dio.get<List<dynamic>>('/vinculos/pendentes');
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ConvitePendente.doJson)
        .toList();
  }

  /// O aluno aceita o convite (vira vínculo ativo + registra o consentimento).
  Future<void> aceitar(String vinculoId) =>
      _executar(() => _dio.post<void>('/vinculos/$vinculoId/aceitar'));

  /// O aluno recusa o convite.
  Future<void> recusar(String vinculoId) =>
      _executar(() => _dio.post<void>('/vinculos/$vinculoId/recusar'));

  /// Encerra um vínculo ativo (educador ou aluno).
  Future<void> encerrar(String vinculoId) =>
      _executar(() => _dio.post<void>('/vinculos/$vinculoId/encerrar'));

  /// Alunos com vínculo ativo do educador logado.
  Future<List<AlunoVinculado>> listarAlunos() async {
    final resposta = await _dio.get<List<dynamic>>('/alunos');
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(AlunoVinculado.doJson)
        .toList();
  }

  Future<void> _executar(
    Future<void> Function() acao, {
    String Function(DioException e)? traduzir,
  }) async {
    try {
      await acao();
    } on DioException catch (e) {
      throw EducadorException((traduzir ?? _traduzir)(e));
    }
  }

  static String _traduzir(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => 'Confira os dados e tente de novo.',
      403 => 'Ative o modo educador para convidar alunos.',
      404 => 'Convite não encontrado.',
      409 => 'Este convite não está mais disponível.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }

  /// Mensagens específicas do convite por e-mail (POST /vinculos).
  static String _traduzirConvite(DioException e) {
    final status = e.response?.statusCode;
    return switch (status) {
      400 => 'Você não pode convidar a si mesmo.',
      403 => 'Ative o modo educador para convidar alunos.',
      // 404: e-mail não existe (mensagem neutra, sem revelar o cadastro).
      404 => 'Não encontramos um aluno com esse e-mail.',
      409 => 'Você já tem um convite ou vínculo ativo com esse aluno.',
      null => 'Sem conexão. Verifique sua internet e tente de novo.',
      _ => 'Não foi possível enviar o convite. Tente novamente.',
    };
  }
}

final educadorRepositoryProvider = Provider<EducadorRepository>(
  (ref) => EducadorRepository(ref.watch(dioProvider)),
);

/// Convites pendentes do usuário logado (aba de convites recebidos).
final convitesPendentesProvider =
    FutureProvider.autoDispose<List<ConvitePendente>>(
  (ref) => ref.watch(educadorRepositoryProvider).listarConvitesPendentes(),
);

/// Alunos com vínculo ativo do educador logado.
final alunosProvider = FutureProvider.autoDispose<List<AlunoVinculado>>(
  (ref) => ref.watch(educadorRepositoryProvider).listarAlunos(),
);
