import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preenchido na inicialização do app (ver `main.dart`).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Defina sharedPreferencesProvider no main'),
);

/// Estado do [ThemeMode] escolhido pelo usuário, persistido no aparelho
/// (ADR-08). Padrão: seguir o sistema. A escolha fica salva e é restaurada ao
/// reabrir o app.
class TemaController extends Notifier<ThemeMode> {
  static const _chave = 'tema_modo';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  ThemeMode build() {
    final salvo = _prefs.getString(_chave);
    return switch (salvo) {
      'claro' => ThemeMode.light,
      'escuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> definir(ThemeMode modo) async {
    state = modo;
    final valor = switch (modo) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'escuro',
      ThemeMode.system => 'sistema',
    };
    await _prefs.setString(_chave, valor);
  }
}

final temaControllerProvider =
    NotifierProvider<TemaController, ThemeMode>(TemaController.new);
