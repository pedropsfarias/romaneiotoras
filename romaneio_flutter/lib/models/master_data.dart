class CompradorMaster {
  const CompradorMaster({
    required this.chaveOrigem,
    required this.nome,
    this.identificador,
  });

  final String chaveOrigem;
  final String nome;
  final String? identificador;

  Map<String, dynamic> toJson() => {
    'chaveOrigem': chaveOrigem,
    'nome': nome,
    if (identificador != null) 'identificador': identificador,
  };

  factory CompradorMaster.fromJson(Map<String, dynamic> json) =>
      CompradorMaster(
        chaveOrigem: json['chaveOrigem']?.toString() ?? '',
        nome: json['nome']?.toString() ?? '',
        identificador: json['identificador']?.toString(),
      );
}

class MasterData {
  const MasterData({
    required this.romaneadores,
    required this.compradores,
    required this.empreiteiros,
    required this.proprietarios,
    required this.municipios,
    required this.carregadores,
    required this.medidores,
    required this.motoristas,
    required this.operadores,
    required this.localidades,
    required this.placas,
    required this.fileName,
    required this.importedAt,
    this.compradoresDetalhados = const [],
  });

  static const version = 1;
  final List<String> romaneadores;
  final List<String> compradores;
  final List<CompradorMaster> compradoresDetalhados;
  final List<String> empreiteiros;
  final List<String> proprietarios;
  final List<String> municipios;
  final List<String> carregadores;
  final List<String> medidores;
  final List<String> motoristas;
  final List<String> operadores;
  final List<String> localidades;
  final List<String> placas;
  final String fileName;
  final DateTime importedAt;

  List<CompradorMaster> get cadastroCompradores {
    if (compradoresDetalhados.isNotEmpty) return compradoresDetalhados;
    return [
      for (var index = 0; index < compradores.length; index++)
        CompradorMaster(
          chaveOrigem: 'compradores:linha:${index + 2}',
          nome: compradores[index],
        ),
    ];
  }

  bool get isValid => [
    romaneadores,
    compradores,
    empreiteiros,
    proprietarios,
    municipios,
    carregadores,
    medidores,
    motoristas,
    operadores,
    localidades,
    placas,
  ].every((items) => items.isNotEmpty);

  Map<String, dynamic> toJson() => {
    'version': version,
    'fileName': fileName,
    'importedAt': importedAt.toIso8601String(),
    'romaneadores': romaneadores,
    'compradores': compradores,
    'compradoresDetalhados': cadastroCompradores
        .map((item) => item.toJson())
        .toList(),
    'empreiteiros': empreiteiros,
    'proprietarios': proprietarios,
    'municipios': municipios,
    'carregadores': carregadores,
    'medidores': medidores,
    'motoristas': motoristas,
    'operadores': operadores,
    'localidades': localidades,
    'placas': placas,
  };

  factory MasterData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version) {
      throw const FormatException('Versão do mestre incompatível.');
    }
    List<String> list(String key) =>
        (json[key] as List? ?? const []).map((e) => e.toString()).toList();
    final result = MasterData(
      romaneadores: list('romaneadores'),
      compradores: list('compradores'),
      compradoresDetalhados:
          (json['compradoresDetalhados'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (item) =>
                    CompradorMaster.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.nome.trim().isNotEmpty)
              .toList(),
      empreiteiros: list('empreiteiros'),
      proprietarios: list('proprietarios'),
      municipios: list('municipios'),
      carregadores: list('carregadores'),
      medidores: list('medidores'),
      motoristas: list('motoristas'),
      operadores: list('operadores'),
      localidades: list('localidades'),
      placas: list('placas'),
      fileName: json['fileName']?.toString() ?? '',
      importedAt: DateTime.parse(json['importedAt']?.toString() ?? ''),
    );
    if (!result.isValid) {
      throw const FormatException('Mestre salvo está incompleto.');
    }
    return result;
  }
}
