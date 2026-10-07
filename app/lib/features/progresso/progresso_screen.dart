import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';

/// Placeholder da aba Progresso. O conteúdo real chega nos PBIs 20 a 22.
class ProgressoScreen extends StatelessWidget {
  const ProgressoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progresso')),
      body: Center(
        child: Text('Em breve', style: AppText.title),
      ),
    );
  }
}
