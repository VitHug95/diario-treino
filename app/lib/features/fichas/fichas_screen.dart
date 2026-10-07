import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';

/// Placeholder da aba Fichas. O conteúdo real chega nos PBIs 12 a 14.
class FichasScreen extends StatelessWidget {
  const FichasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas')),
      body: Center(
        child: Text('Em breve', style: AppText.title),
      ),
    );
  }
}
