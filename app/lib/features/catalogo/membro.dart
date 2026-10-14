/// Membro (região) e seus músculos, de GET /api/v1/membros (PBI-31).
class Membro {
  const Membro({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.ordem,
    required this.musculos,
  });

  final int id;
  final String codigo;
  final String nome;
  final int ordem;
  final List<Musculo> musculos;

  factory Membro.doJson(Map<String, dynamic> json) => Membro(
        id: (json['id'] as num).toInt(),
        codigo: json['codigo'] as String,
        nome: json['nome'] as String,
        ordem: (json['ordem'] as num).toInt(),
        musculos: (json['musculos'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(Musculo.doJson)
            .toList(),
      );
}

/// Músculo dentro de um membro.
class Musculo {
  const Musculo({required this.id, required this.codigo, required this.nome});

  final int id;
  final String codigo;
  final String nome;

  factory Musculo.doJson(Map<String, dynamic> json) => Musculo(
        id: (json['id'] as num).toInt(),
        codigo: json['codigo'] as String,
        nome: json['nome'] as String,
      );
}
