import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tema/tema_controller.dart';

/// Tela inicial (placeholder do PBI-02). O conteúdo real — próximo treino,
/// lista de fichas, atalhos — chega no PBI-23. Aqui serve para validar a
/// estrutura, a navegação e a troca de tema.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(temaControllerProvider);
    final escuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diário de Treino'),
        actions: [
          IconButton(
            onPressed: () => ref
                .read(temaControllerProvider.notifier)
                .definir(escuro ? ThemeMode.light : ThemeMode.dark),
            icon: Icon(escuro ? Icons.light_mode : Icons.dark_mode),
            tooltip: escuro ? 'Usar tema claro' : 'Usar tema escuro',
          ),
        ],
      ),
      body: Center(
        child: Semantics(
          label: 'Mensagem de boas-vindas da tela inicial',
          child: Text(
            'Estrutura pronta. Tema atual: ${_rotuloModo(modo)}.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _rotuloModo(ThemeMode modo) => switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'escuro',
        ThemeMode.system => 'sistema',
      };
}
