class Tora {
  const Tora({
    required this.diametro,
    required this.quantidade,
    this.volumeTotal = 0,
  });

  final int diametro;
  final int quantidade;
  final double volumeTotal;

  Tora copyWith({int? diametro, int? quantidade, double? volumeTotal}) {
    return Tora(
      diametro: diametro ?? this.diametro,
      quantidade: quantidade ?? this.quantidade,
      volumeTotal: volumeTotal ?? this.volumeTotal,
    );
  }

  Map<String, dynamic> toJson() => {
    'diametro': diametro,
    'quantidade': quantidade,
    'volumeTotal': volumeTotal,
  };

  factory Tora.fromJson(Map<String, dynamic> json) {
    return Tora(
      diametro: (json['diametro'] as num).toInt(),
      quantidade: (json['quantidade'] as num).toInt(),
      volumeTotal: (json['volumeTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
