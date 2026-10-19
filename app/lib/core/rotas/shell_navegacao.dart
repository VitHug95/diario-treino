import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Casca com a navegação inferior (Início / Planos / Progresso), que envolve as
/// três abas principais.
///
/// Tocar numa aba sempre abre a RAIZ dela (PBI-80): mesmo que o atleta tenha
/// entrado num plano/ficha e saído, voltar à aba mostra a lista, não a tela em
/// que parou. As telas de tela cheia (registro e treino ao vivo) ficam no
/// navigator raiz, acima desta barra, então trocar de aba nunca as descarta.
class ShellNavegacao extends StatelessWidget {
  const ShellNavegacao({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // initialLocation: true SEMPRE — tocar numa aba volta à raiz dela,
        // trocando de aba ou não (PBI-80), em vez de restaurar a pilha guardada.
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: true,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            label: 'Início',
          ),
          // A aba Fichas virou Planos (PBI-45): a lista de planos, e as fichas
          // ficam dentro de cada plano.
          NavigationDestination(
            icon: Icon(LucideIcons.calendar),
            label: 'Planos',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.lineChart),
            label: 'Progresso',
          ),
        ],
      ),
    );
  }
}
