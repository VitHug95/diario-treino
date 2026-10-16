import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localizacao/material_pt.dart';
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
      // Ações de mover da lista reordenável em português (PBI-62).
      // O MaterialApp completa a lista com os padrões (widgets, Cupertino).
      localizationsDelegates: LocalizacoesPt.delegates,
      // O app é desenhado para celular (MAS, seção 10). Em telas largas (web no
      // computador), limita o conteúdo a 600px e centraliza, para não esticar.
      builder: (context, child) => _LarguraMaxima(child: child),
    );
  }
}

/// Centraliza e limita a largura do conteúdo em telas largas. Em telas estreitas
/// (celular), não tem efeito, pois a largura disponível já é menor que o teto.
class _LarguraMaxima extends StatelessWidget {
  const _LarguraMaxima({required this.child});

  static const double _maxLargura = 600;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final conteudo = child ?? const SizedBox.shrink();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxLargura),
          // Material garante o fundo correto do app dentro da faixa de 600px.
          child: Material(color: Theme.of(context).scaffoldBackgroundColor, child: conteudo),
        ),
      ),
    );
  }
}
