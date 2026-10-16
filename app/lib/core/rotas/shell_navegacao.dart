import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Casca com a navegação inferior (Início / Planos / Progresso), que envolve as
/// três abas principais. Mantém o estado de cada aba via StatefulShellRoute.
class ShellNavegacao extends StatelessWidget {
  const ShellNavegacao({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
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
