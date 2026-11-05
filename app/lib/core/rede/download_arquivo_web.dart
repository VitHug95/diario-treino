import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dispara o download de [bytes] como um arquivo no navegador (PBI-89). Cria um
/// Blob, gera uma URL temporária (object URL) e simula o clique num link
/// `<a download>`. A URL é revogada logo depois para liberar a memória.
Future<void> baixarBytes(
  String nomeArquivo,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  final dados = Uint8List.fromList(bytes);
  final partes = [dados.toJS].toJS;
  final blob = web.Blob(partes, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);

  final ancora = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nomeArquivo
    ..style.display = 'none';
  web.document.body!.appendChild(ancora);
  ancora.click();
  ancora.remove();

  web.URL.revokeObjectURL(url);
}
