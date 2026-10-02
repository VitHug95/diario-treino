import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/rotas/app_router.dart';
import 'core/tema/tema_controller.dart';
import 'theme/app_theme.dart';

/// Raiz do app: aplica os temas claro/escuro, o [ThemeMode] escolhido e o
/// roteador. Nenhuma cor é definida aqui — tudo vem de [AppTheme].
class DiarioTreinoApp extends ConsumerWidget {
  const DiarioTreinoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final modo = ref.watch(temaControllerProvider);

    return MaterialApp.router(
      title: 'Diário de Treino',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      darkTheme: AppTheme.escuro,
      themeMode: modo,
      routerConfig: router,
    );
  }
}
