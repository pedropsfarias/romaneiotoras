import 'dart:math' as math;

import 'tora.dart';

export 'tora.dart';

enum TipoBalanceamento { numeroDeToras, metroCubico }

class Romaneio {
  const Romaneio({
    this.id = '',
    this.idInterno = '',
    this.numeroRomaneio = 0,
    this.romaneador = '',
    this.comprador = '',
    this.compradorId = '',
    this.compradorChaveOrigem = '',
    this.empreiteiros = const [],
    this.proprietario = '',
    this.placas = const [],
    this.localidade = '',
    this.municipio = '',
    this.data = '',
    this.hora = '',
    this.carregador = '',
    this.medidor = '',
    this.motorista = '',
    this.operador = '',
    this.observacoes = '',
    this.comprimento = 0,
    this.toras = const [],
    this.precosPorClasse = const {},
    this.tipoBalanceamento = TipoBalanceamento.numeroDeToras,
    this.balanceamentoToras = const {},
    this.balanceamentoVolume = const {},
    this.comNo = false,
    this.doPe = false,
    this.segundaTora = false,
    this.fotos = const [],
    this.romaneioAberto = true,
    this.finalizadoEm,
    this.pdfPath = '',
  });

  final String id;

  /// Stable internal identifier. `id` remains as a legacy compatibility alias.
  final String idInterno;
  final int numeroRomaneio;
  final String romaneador;
  final String comprador;
  final String compradorId;
  final String compradorChaveOrigem;
  final List<String> empreiteiros;
  final String proprietario;
  final List<String> placas;
  final String localidade;
  final String municipio;
  final String data;
  final String hora;
  final String carregador;
  final String medidor;
  final String motorista;
  final String operador;
  final String observacoes;
  final double comprimento;
  final List<Tora> toras;
  final Map<String, double> precosPorClasse;
  final TipoBalanceamento tipoBalanceamento;
  final Map<String, int> balanceamentoToras;
  final Map<String, double> balanceamentoVolume;
  final bool comNo;
  final bool doPe;
  final bool segundaTora;
  final List<String> fotos;
  final bool romaneioAberto;
  final DateTime? finalizadoEm;
  final String pdfPath;

  Romaneio copyWith({
    String? id,
    String? idInterno,
    int? numeroRomaneio,
    String? romaneador,
    String? comprador,
    String? compradorId,
    String? compradorChaveOrigem,
    List<String>? empreiteiros,
    String? proprietario,
    List<String>? placas,
    String? localidade,
    String? municipio,
    String? data,
    String? hora,
    String? carregador,
    String? medidor,
    String? motorista,
    String? operador,
    String? observacoes,
    double? comprimento,
    List<Tora>? toras,
    Map<String, double>? precosPorClasse,
    TipoBalanceamento? tipoBalanceamento,
    Map<String, int>? balanceamentoToras,
    Map<String, double>? balanceamentoVolume,
    bool? comNo,
    bool? doPe,
    bool? segundaTora,
    List<String>? fotos,
    bool? romaneioAberto,
    DateTime? finalizadoEm,
    String? pdfPath,
  }) {
    return Romaneio(
      id: id ?? this.id,
      idInterno: idInterno ?? this.idInterno,
      numeroRomaneio: numeroRomaneio ?? this.numeroRomaneio,
      romaneador: romaneador ?? this.romaneador,
      comprador: comprador ?? this.comprador,
      compradorId: compradorId ?? this.compradorId,
      compradorChaveOrigem: compradorChaveOrigem ?? this.compradorChaveOrigem,
      empreiteiros: empreiteiros ?? this.empreiteiros,
      proprietario: proprietario ?? this.proprietario,
      placas: placas ?? this.placas,
      localidade: localidade ?? this.localidade,
      municipio: municipio ?? this.municipio,
      data: data ?? this.data,
      hora: hora ?? this.hora,
      carregador: carregador ?? this.carregador,
      medidor: medidor ?? this.medidor,
      motorista: motorista ?? this.motorista,
      operador: operador ?? this.operador,
      observacoes: observacoes ?? this.observacoes,
      comprimento: comprimento ?? this.comprimento,
      toras: toras ?? this.toras,
      precosPorClasse: precosPorClasse ?? this.precosPorClasse,
      tipoBalanceamento: tipoBalanceamento ?? this.tipoBalanceamento,
      balanceamentoToras: balanceamentoToras ?? this.balanceamentoToras,
      balanceamentoVolume: balanceamentoVolume ?? this.balanceamentoVolume,
      comNo: comNo ?? this.comNo,
      doPe: doPe ?? this.doPe,
      segundaTora: segundaTora ?? this.segundaTora,
      fotos: fotos ?? this.fotos,
      romaneioAberto: romaneioAberto ?? this.romaneioAberto,
      finalizadoEm: finalizadoEm ?? this.finalizadoEm,
      pdfPath: pdfPath ?? this.pdfPath,
    );
  }

  double _volumeUnitario(int diametro) {
    final d = diametro.toDouble();
    return ((d * d * math.pi) / 40000) * comprimento;
  }

  double volumeDaTora(Tora tora) => tora.volumeTotal > 0
      ? tora.volumeTotal
      : _volumeUnitario(tora.diametro) * tora.quantidade;

  static const priceClassKeys = <String>[
    '18-24',
    '25-29',
    '30-34',
    '35-39',
    '40-ACIMA',
  ];

  static String priceClassForDiameter(int diametro) {
    if (diametro <= 24) return '18-24';
    if (diametro <= 29) return '25-29';
    if (diametro <= 34) return '30-34';
    if (diametro <= 39) return '35-39';
    return '40-ACIMA';
  }

  Romaneio addTora(int diametro, int quantidade) {
    final novaLista = List<Tora>.from(toras);
    novaLista.add(
      Tora(
        diametro: diametro,
        quantidade: quantidade,
        volumeTotal: _volumeUnitario(diametro) * quantidade,
      ),
    );
    return copyWith(toras: novaLista);
  }

  Romaneio removeTora(Tora tora) {
    final novaLista = List<Tora>.from(toras);
    final index = novaLista.indexWhere((item) => identical(item, tora));
    if (index >= 0) {
      novaLista.removeAt(index);
    } else {
      final matchingIndex = novaLista.indexWhere(
        (item) =>
            item.diametro == tora.diametro &&
            item.quantidade == tora.quantidade &&
            item.volumeTotal == tora.volumeTotal,
      );
      if (matchingIndex >= 0) novaLista.removeAt(matchingIndex);
    }
    return copyWith(toras: novaLista);
  }

  Romaneio updateQuantity(int diametro, int novaQuantidade) {
    if (novaQuantidade <= 0) {
      return removeTora(Tora(diametro: diametro, quantidade: 1));
    }
    final novaLista = List<Tora>.from(toras);
    final index = novaLista.indexWhere((item) => item.diametro == diametro);
    if (index >= 0) {
      final atual = novaLista[index];
      novaLista[index] = atual.copyWith(
        quantidade: novaQuantidade,
        volumeTotal: _volumeUnitario(diametro) * novaQuantidade,
      );
      return copyWith(toras: novaLista);
    }
    return addTora(diametro, novaQuantidade);
  }

  Map<String, dynamic> summary() {
    var numToras = 0;
    var volTotal = 0.0;
    for (final tora in toras) {
      final volume = volumeDaTora(tora);
      numToras += tora.quantidade;
      volTotal += volume;
    }
    return {'numToras': numToras, 'volToras': volTotal};
  }

  Map<String, double> groupedVolumeByRange() {
    final result = {
      '<= 24': 0.0,
      '25 a 29': 0.0,
      '30 a 34': 0.0,
      '35 a 39': 0.0,
      '> 39': 0.0,
    };
    for (final tora in toras) {
      final volume = volumeDaTora(tora);
      final range = tora.diametro <= 24
          ? '<= 24'
          : tora.diametro <= 29
          ? '25 a 29'
          : tora.diametro <= 34
          ? '30 a 34'
          : tora.diametro <= 39
          ? '35 a 39'
          : '> 39';
      result[range] = (result[range] ?? 0) + volume;
    }
    return result;
  }

  double averageDiameter() {
    if (toras.isEmpty) return 0;
    final totalQuant = toras.fold<int>(0, (sum, item) => sum + item.quantidade);
    final totalDiam = toras.fold<double>(
      0,
      (sum, item) => sum + (item.diametro * item.quantidade),
    );
    return totalQuant == 0 ? 0 : totalDiam / totalQuant;
  }

  double totalPrice() {
    if (toras.isEmpty) return 0;
    if (precosPorClasse.isEmpty) {
      return (summary()['volToras'] as double) * 120.0;
    }
    var total = 0.0;
    for (final tora in toras) {
      final price = precosPorClasse[priceClassForDiameter(tora.diametro)];
      if (price != null) total += volumeDaTora(tora) * price;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'idInterno': idInterno.isEmpty ? id : idInterno,
    'numeroRomaneio': numeroRomaneio,
    'romaneador': romaneador,
    'comprador': comprador,
    'compradorId': compradorId,
    'compradorChaveOrigem': compradorChaveOrigem,
    'empreiteiros': empreiteiros,
    'proprietario': proprietario,
    'placas': placas,
    'localidade': localidade,
    'municipio': municipio,
    'data': data,
    'hora': hora,
    'carregador': carregador,
    'medidor': medidor,
    'motorista': motorista,
    'operador': operador,
    'observacoes': observacoes,
    'comprimento': comprimento,
    'toras': toras.map((item) => item.toJson()).toList(),
    'precosPorClasse': precosPorClasse,
    'tipoBalanceamento': tipoBalanceamento.name,
    'balanceamentoToras': balanceamentoToras,
    'balanceamentoVolume': balanceamentoVolume,
    'comNo': comNo,
    'doPe': doPe,
    'segundaTora': segundaTora,
    'fotos': fotos,
    'romaneioAberto': romaneioAberto,
    'finalizadoEm': finalizadoEm?.toIso8601String(),
    'pdfPath': pdfPath,
  };

  factory Romaneio.fromJson(Map<String, dynamic> json) => Romaneio(
    id: json['id'] as String? ?? '',
    idInterno: json['idInterno'] as String? ?? json['id'] as String? ?? '',
    numeroRomaneio: (json['numeroRomaneio'] as num?)?.toInt() ?? 0,
    romaneador: json['romaneador'] as String? ?? '',
    comprador: json['comprador'] as String? ?? '',
    compradorId: json['compradorId'] as String? ?? '',
    compradorChaveOrigem: json['compradorChaveOrigem'] as String? ?? '',
    empreiteiros: (json['empreiteiros'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    proprietario: json['proprietario'] as String? ?? '',
    placas: (json['placas'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    localidade: json['localidade'] as String? ?? '',
    municipio: json['municipio'] as String? ?? '',
    data: json['data'] as String? ?? '',
    hora: json['hora'] as String? ?? '',
    carregador: json['carregador'] as String? ?? '',
    medidor: json['medidor'] as String? ?? '',
    motorista: json['motorista'] as String? ?? '',
    operador: json['operador'] as String? ?? '',
    observacoes: json['observacoes'] as String? ?? '',
    comprimento: (json['comprimento'] as num?)?.toDouble() ?? 0,
    toras: (json['toras'] as List<dynamic>? ?? const [])
        .map((item) => Tora.fromJson(item as Map<String, dynamic>))
        .toList(),
    precosPorClasse: (json['precosPorClasse'] as Map? ?? const {}).map(
      (key, value) => MapEntry(
        key.toString(),
        value is num
            ? value.toDouble()
            : double.tryParse(value.toString()) ?? 0,
      ),
    ),
    tipoBalanceamento: switch (json['tipoBalanceamento'] as String?) {
      'metroCubico' || 'm3' || 'volume' => TipoBalanceamento.metroCubico,
      _ => TipoBalanceamento.numeroDeToras,
    },
    balanceamentoToras: (json['balanceamentoToras'] as Map? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    ),
    balanceamentoVolume: (json['balanceamentoVolume'] as Map? ?? const {}).map(
      (key, value) =>
          MapEntry(key.toString(), (value as num?)?.toDouble() ?? 0),
    ),
    comNo: json['comNo'] as bool? ?? false,
    doPe: json['doPe'] as bool? ?? false,
    segundaTora: json['segundaTora'] as bool? ?? false,
    fotos: (json['fotos'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    romaneioAberto: json['romaneioAberto'] as bool? ?? true,
    finalizadoEm: DateTime.tryParse(json['finalizadoEm'] as String? ?? ''),
    pdfPath: json['pdfPath'] as String? ?? '',
  );
}
