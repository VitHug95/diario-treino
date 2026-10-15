/// Tag de série (TV-1): "como" a série foi feita. Lista fixa de 10 itens,
/// aprovada pelo PO. É só identificação — não entra em cálculo nem no gráfico.
///
/// No app a tag trafega como [String] (convenção do projeto para enums de
/// domínio). Esta classe guarda os metadados de exibição (rótulo, descrição e
/// se o chip usa a cor primary suave) para o seletor e o chip reaproveitarem a
/// mesma fonte. As cores concretas vêm do tema (tokens), resolvidas no widget.
library;

/// Metadados de exibição de um marcador de série.
class TagSerieInfo {
  const TagSerieInfo({
    required this.codigo,
    required this.rotulo,
    required this.descricao,
    required this.primary,
  });

  /// Código do enum (igual ao backend), ex.: 'AQUECIMENTO'.
  final String codigo;

  /// Rótulo exibido na tela, ex.: 'Aquecimento'.
  final String rotulo;

  /// Descrição mostrada no seletor.
  final String descricao;

  /// true = chip com a cor primary suave; false = chip neutro.
  final bool primary;
}

/// Catálogo das tags de série. Fonte única de exibição no front.
abstract final class TagsSerie {
  const TagsSerie._();

  static const String valida = 'VALIDA';

  /// Lista fixa, na ordem do protótipo (Válida primeiro).
  static const List<TagSerieInfo> lista = [
    TagSerieInfo(
      codigo: 'VALIDA',
      rotulo: 'Válida',
      descricao: 'Série de trabalho, a padrão',
      primary: false,
    ),
    TagSerieInfo(
      codigo: 'AQUECIMENTO',
      rotulo: 'Aquecimento',
      descricao: 'Carga leve, prepara articulação e músculo',
      primary: false,
    ),
    TagSerieInfo(
      codigo: 'PREPARATORIA',
      rotulo: 'Preparatória',
      descricao: 'Aproximação de carga antes das válidas',
      primary: false,
    ),
    TagSerieInfo(
      codigo: 'TOP_SET',
      rotulo: 'Top set',
      descricao: 'A série mais pesada do dia',
      primary: true,
    ),
    TagSerieInfo(
      codigo: 'BACK_OFF',
      rotulo: 'Back-off',
      descricao: 'Depois do top set, com carga reduzida',
      primary: true,
    ),
    TagSerieInfo(
      codigo: 'FALHA',
      rotulo: 'Até a falha',
      descricao: 'Até não conseguir outra repetição',
      primary: true,
    ),
    TagSerieInfo(
      codigo: 'DROP_SET',
      rotulo: 'Drop set',
      descricao: 'Reduz a carga e segue sem descanso',
      primary: true,
    ),
    TagSerieInfo(
      codigo: 'REST_PAUSE',
      rotulo: 'Rest-pause',
      descricao: 'Pausa curta e mais repetições',
      primary: true,
    ),
    TagSerieInfo(
      codigo: 'NEGATIVA',
      rotulo: 'Negativa',
      descricao: 'Ênfase na fase excêntrica',
      primary: true,
    ),
    TagSerieInfo(
      codigo: 'PARCIAIS',
      rotulo: 'Parciais',
      descricao: 'Amplitude reduzida no fim da série',
      primary: true,
    ),
  ];

  static final Map<String, TagSerieInfo> _porCodigo = {
    for (final t in lista) t.codigo: t,
  };

  /// Metadados de um código; cai em Válida se vier algo desconhecido (robustez).
  static TagSerieInfo info(String codigo) => _porCodigo[codigo] ?? lista.first;

  /// Rótulo de exibição de um código, ex.: 'AQUECIMENTO' -> 'Aquecimento'.
  static String rotulo(String codigo) => info(codigo).rotulo;

  /// true quando o código é a tag padrão (não mostra chip no modo leitura).
  static bool ehValida(String codigo) => codigo == valida;
}
