import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rede/cliente_http.dart';

/// Perfil do usuário devolvido por GET /me (espelha o PerfilUsuario da API).
class Perfil {
  const Perfil({
    required this.id,
    required this.nome,
    required this.email,
    required this.papeis,
  });

  final String id;
  final String nome;
  final String email;
  final List<String> papeis;

  factory Perfil.doJson(Map<String, dynamic> json) => Perfil(
        id: json['id'] as String,
        nome: json['nome'] as String,
        email: json['email'] as String,
        papeis: (json['papeis'] as List<dynamic>).cast<String>(),
      );
}

/// Chama GET /me. No primeiro acesso, a API provisiona o usuário (ATLETA).
class PerfilApi {
  PerfilApi(this._dio);

  final Dio _dio;

  Future<Perfil> obterMe() async {
    final resposta = await _dio.get<Map<String, dynamic>>('/me');
    return Perfil.doJson(resposta.data!);
  }
}

final perfilApiProvider = Provider<PerfilApi>(
  (ref) => PerfilApi(ref.watch(dioProvider)),
);
