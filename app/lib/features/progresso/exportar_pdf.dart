import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/rede/download_arquivo.dart';
import '../../theme/theme_tokens.dart';
import 'progresso_repository.dart';

/// Baixa o PDF do progresso e dispara o download no navegador (PBI-89). Mostra
/// um aviso curto de erro se algo falhar. [atletaId] não nulo é o modo educador
/// (o aluno). [diasPeriodo] define o período (padrão 90 dias, como o gráfico).
///
/// Devolve true quando o download foi disparado. O chamador controla o estado
/// de "gerando…" do botão (desabilita enquanto aguarda).
Future<bool> exportarProgressoPdf(
  BuildContext context,
  WidgetRef ref, {
  String? atletaId,
  int diasPeriodo = 90,
  String nomeArquivo = 'progresso.pdf',
}) async {
  final hoje = DateTime.now();
  final de = DateTime(hoje.year, hoje.month, hoje.day)
      .subtract(Duration(days: diasPeriodo));

  // O ScaffoldMessenger é capturado antes do await: usá-lo depois não depende
  // de ter o BuildContext "atravessando" o gap assíncrono (evita o lint
  // use_build_context_synchronously e o risco de context desmontado).
  final mensageiro = ScaffoldMessenger.of(context);

  try {
    final bytes = await ref.read(progressoRepositoryProvider).baixarProgressoPdf(
          de: de,
          ate: hoje,
          atletaId: atletaId,
        );
    await baixarBytes(nomeArquivo, bytes, mimeType: 'application/pdf');
    return true;
  } on ProgressoException catch (e) {
    _avisar(mensageiro, e.mensagem);
    return false;
  } catch (_) {
    _avisar(mensageiro, 'Não foi possível baixar o PDF. Tente novamente.');
    return false;
  }
}

void _avisar(ScaffoldMessengerState mensageiro, String msg) {
  mensageiro
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Botão de AppBar "Exportar PDF" (PBI-89), reusado pela aba Progresso (atleta)
/// e pela tela do aluno (educador). Fica desabilitado, com spinner, enquanto o
/// PDF é gerado e baixado. [atletaId] não nulo é o modo educador.
class BotaoExportarPdf extends ConsumerStatefulWidget {
  const BotaoExportarPdf({super.key, this.atletaId, this.diasPeriodo = 90});

  final String? atletaId;
  final int diasPeriodo;

  @override
  ConsumerState<BotaoExportarPdf> createState() => _BotaoExportarPdfState();
}

class _BotaoExportarPdfState extends ConsumerState<BotaoExportarPdf> {
  bool _gerando = false;

  Future<void> _exportar() async {
    setState(() => _gerando = true);
    await exportarProgressoPdf(
      context,
      ref,
      atletaId: widget.atletaId,
      diasPeriodo: widget.diasPeriodo,
    );
    if (mounted) setState(() => _gerando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_gerando) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.x16),
        child: Center(
          child: SizedBox(
            width: AppSizes.iconeMd,
            height: AppSizes.iconeMd,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return IconButton(
      onPressed: _exportar,
      icon: const Icon(LucideIcons.download, size: AppSizes.iconeMd),
      tooltip: 'Exportar progresso em PDF',
    );
  }
}
