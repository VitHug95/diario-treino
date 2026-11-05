// Download de um arquivo gerado em memória (PBI-89). A implementação real é
// web (cria um Blob e dispara o clique num link invisível); fora do web há só
// o stub, porque o app roda no navegador. O import condicional escolhe a
// implementação certa em tempo de compilação sem quebrar os testes (que rodam
// na VM do Dart, não no web).
export 'download_arquivo_stub.dart'
    if (dart.library.js_interop) 'download_arquivo_web.dart';
