/// Tipos de medida corporal (E12 / PBI-92), os mesmos 12 da API. O [codigo] é o
/// que trafega; o resto é só apresentação. A faixa é a do back (`TipoMedida` no
/// domínio): peso 30 a 300 kg; as demais 5 a 250 cm.
enum TipoMedida {
  peso('PESO', 'Peso', 'kg', GrupoMedida.corpoTodo),
  pescoco('PESCOCO', 'Pescoço', 'cm', GrupoMedida.tronco),
  ombros('OMBROS', 'Ombros', 'cm', GrupoMedida.tronco),
  peito('PEITO', 'Peito', 'cm', GrupoMedida.tronco),
  cintura('CINTURA', 'Cintura', 'cm', GrupoMedida.tronco),
  quadril('QUADRIL', 'Quadril', 'cm', GrupoMedida.tronco),
  bracoD('BRACO_D', 'Braço direito', 'cm', GrupoMedida.bracos),
  bracoE('BRACO_E', 'Braço esquerdo', 'cm', GrupoMedida.bracos),
  coxaD('COXA_D', 'Coxa direita', 'cm', GrupoMedida.pernas),
  coxaE('COXA_E', 'Coxa esquerda', 'cm', GrupoMedida.pernas),
  panturrilhaD('PANTURRILHA_D', 'Panturrilha direita', 'cm', GrupoMedida.pernas),
  panturrilhaE('PANTURRILHA_E', 'Panturrilha esquerda', 'cm', GrupoMedida.pernas);

  const TipoMedida(this.codigo, this.rotulo, this.unidade, this.grupo);

  final String codigo;
  final String rotulo;
  final String unidade;
  final GrupoMedida grupo;

  double get minimo => this == peso ? 30 : 5;
  double get maximo => this == peso ? 300 : 250;

  /// Unidade por extenso, para o leitor de tela ("centímetros", "quilos").
  String unidadePorExtenso({required bool plural}) => this == peso
      ? (plural ? 'quilos' : 'quilo')
      : (plural ? 'centímetros' : 'centímetro');

  /// Devolve o tipo do código da API, ou nulo se não for conhecido.
  static TipoMedida? doCodigo(String codigo) {
    for (final t in values) {
      if (t.codigo == codigo) return t;
    }
    return null;
  }
}

/// Grupos do formulário "Registrar medidas" (tela 25).
enum GrupoMedida {
  corpoTodo('Corpo todo'),
  tronco('Tronco'),
  bracos('Braços'),
  pernas('Pernas');

  const GrupoMedida(this.rotulo);
  final String rotulo;

  List<TipoMedida> get tipos =>
      TipoMedida.values.where((t) => t.grupo == this).toList();
}

/// Última medida de um tipo. [variacao] é a diferença para o registro anterior
/// do MESMO tipo (nula se só existe um).
class UltimaMedida {
  const UltimaMedida({
    required this.tipo,
    required this.valor,
    required this.data,
    this.variacao,
  });

  final TipoMedida tipo;
  final double valor;
  final DateTime data;
  final double? variacao;

  factory UltimaMedida.doJson(Map<String, dynamic> json, TipoMedida tipo) =>
      UltimaMedida(
        tipo: tipo,
        valor: (json['valor'] as num).toDouble(),
        data: dataDoJson(json['data'] as String),
        variacao: (json['variacao'] as num?)?.toDouble(),
      );
}

/// Um dia com medidas e quantas foram registradas nele.
class DiaHistoricoMedidas {
  const DiaHistoricoMedidas({required this.data, required this.quantidade});

  final DateTime data;
  final int quantidade;

  factory DiaHistoricoMedidas.doJson(Map<String, dynamic> json) =>
      DiaHistoricoMedidas(
        data: dataDoJson(json['data'] as String),
        quantidade: (json['quantidade'] as num).toInt(),
      );
}

class ResumoMedidas {
  const ResumoMedidas({required this.ultimas, required this.historico});

  /// Só os tipos que têm registro, já na ordem de [TipoMedida].
  final List<UltimaMedida> ultimas;

  /// Do dia mais recente ao mais antigo.
  final List<DiaHistoricoMedidas> historico;

  bool get vazio => ultimas.isEmpty && historico.isEmpty;

  UltimaMedida? ultimaDe(TipoMedida tipo) {
    for (final u in ultimas) {
      if (u.tipo == tipo) return u;
    }
    return null;
  }

  factory ResumoMedidas.doJson(Map<String, dynamic> json) {
    final ultimas = <UltimaMedida>[];
    for (final item in (json['ultimas'] as List<dynamic>? ?? [])) {
      final mapa = item as Map<String, dynamic>;
      final tipo = TipoMedida.doCodigo(mapa['tipo'] as String);
      // Tipo que o app ainda não conhece (back mais novo): ignora em vez de quebrar.
      if (tipo != null) ultimas.add(UltimaMedida.doJson(mapa, tipo));
    }
    ultimas.sort((a, b) => a.tipo.index.compareTo(b.tipo.index));
    final historico = (json['historico'] as List<dynamic>? ?? [])
        .map((e) => DiaHistoricoMedidas.doJson(e as Map<String, dynamic>))
        .toList();
    return ResumoMedidas(ultimas: ultimas, historico: historico);
  }
}

/// Valores medidos num dia, por tipo.
class DiaMedidas {
  const DiaMedidas(this.valores);

  final Map<TipoMedida, double> valores;

  factory DiaMedidas.doJson(Map<String, dynamic> json) {
    final valores = <TipoMedida, double>{};
    final bruto = json['valores'] as Map<String, dynamic>? ?? {};
    for (final entrada in bruto.entries) {
      final tipo = TipoMedida.doCodigo(entrada.key);
      if (tipo != null) valores[tipo] = (entrada.value as num).toDouble();
    }
    return DiaMedidas(valores);
  }
}

/// "2026-11-05" → 05/11/2026 à meia-noite local (a API manda só o dia).
DateTime dataDoJson(String texto) {
  final partes = texto.split('-');
  return DateTime(
      int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
}
