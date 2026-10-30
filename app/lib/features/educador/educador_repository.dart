import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';
import '../auth/perfil_api.dart';
import '../progresso/progresso_models.dart';
import '../sessao/sessao_models.dart';
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

  // ---- Dados do aluno (PBI-88c): leitura via ?atletaId= (regra 11.3 no back).
  // Reusa os endpoints da PBI-86. O educador só enxerga quem tem vínculo ativo
  // (senão a API responde 404). Observação privada do aluno já vem oculta.

  /// Exercícios que o aluno já treinou (seletor do gráfico de evolução).
  Future<List<ExercicioComHistorico>> exerciciosDoAluno(String atletaId) async {
    final resposta = await _dio.get<List<dynamic>>(
      '/progresso/exercicios',
      queryParameters: {'atletaId': atletaId},
    );
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(ExercicioComHistorico.doJson)
        .toList();
  }

  /// Evolução de um exercício do aluno no período.
  Future<ProgressoExercicio> progressoDoAluno(
    String atletaId,
    String exercicioId, {
    DateTime? de,
    DateTime? ate,
  }) async {
    final resposta = await _dio.get<Map<String, dynamic>>(
      '/progresso/exercicios/$exercicioId',
      queryParameters: {
        'atletaId': atletaId,
        if (de != null) 'de': _soData(de),
        if (ate != null) 'ate': _soData(ate),
      },
    );
    return ProgressoExercicio.doJson(resposta.data!);
  }

  /// Sessões do aluno no período, mais recentes primeiro.
  Future<List<SessaoResumo>> sessoesDoAluno(
    String atletaId, {
    DateTime? de,
    DateTime? ate,
  }) async {
    final resposta = await _dio.get<List<dynamic>>(
      '/sessoes',
      queryParameters: {
        'atletaId': atletaId,
        if (de != null) 'de': _soData(de),
        if (ate != null) 'ate': _soData(ate),
      },
    );
    return (resposta.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(SessaoResumo.doJson)
        .toList();
  }

  static String _soData(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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

// ---- Dados do aluno (PBI-88c), providers family por atletaId ----

/// Exercícios com histórico do aluno (seletor do gráfico na tela do aluno).
final exerciciosDoAlunoProvider = FutureProvider.autoDispose
    .family<List<ExercicioComHistorico>, String>(
  (ref, atletaId) =>
      ref.watch(educadorRepositoryProvider).exerciciosDoAluno(atletaId),
);

/// Exercício selecionado no gráfico da tela do aluno (nulo = nenhum). Como a
/// tela do aluno é autoDispose e só há uma aberta por vez, um provider simples
/// basta (reinicia ao fechar a tela), no mesmo padrão do seletor da aba
/// Progresso.
final exercicioDoAlunoSelecionadoProvider = NotifierProvider.autoDispose<
    ExercicioDoAlunoController, String?>(ExercicioDoAlunoController.new);

class ExercicioDoAlunoController extends Notifier<String?> {
  @override
  String? build() => null;

  void selecionar(String? exercicioId) => state = exercicioId;
}

/// Evolução do exercício selecionado do aluno (90 dias, visão ampla).
final progressoDoAlunoProvider =
    FutureProvider.autoDispose.family<ProgressoExercicio?, String>(
  (ref, atletaId) async {
    final exercicioId = ref.watch(exercicioDoAlunoSelecionadoProvider);
    if (exercicioId == null) return null;
    final hoje = DateTime.now();
    final de = DateTime(hoje.year, hoje.month, hoje.day)
        .subtract(const Duration(days: 90));
    return ref
        .watch(educadorRepositoryProvider)
        .progressoDoAluno(atletaId, exercicioId, de: de);
  },
);

/// Sessões recentes do aluno (últimos 30 dias).
final sessoesDoAlunoProvider =
    FutureProvider.autoDispose.family<List<SessaoResumo>, String>(
  (ref, atletaId) {
    final hoje = DateTime.now();
    final de = DateTime(hoje.year, hoje.month, hoje.day)
        .subtract(const Duration(days: 30));
    return ref.watch(educadorRepositoryProvider).sessoesDoAluno(atletaId, de: de);
  },
);
