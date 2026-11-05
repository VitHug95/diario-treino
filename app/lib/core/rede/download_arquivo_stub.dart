/// Stub do download para plataformas não-web (e para os testes na VM). O app é
/// web; se isto rodar, é sinal de uso fora do ambiente suportado.
Future<void> baixarBytes(
  String nomeArquivo,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  throw UnsupportedError(
      'Download de arquivo só é suportado no navegador (web).');
}
