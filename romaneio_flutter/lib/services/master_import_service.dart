import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/master_data.dart';

class MasterImportException implements Exception {
  const MasterImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MasterImportService {
  static const sheetMap = <String, String>{
    'romaneadores': 'romaneadores',
    'compradores': 'compradores',
    'empreiteiros': 'empreiteiros',
    'proprietarios': 'proprietarios',
    'municipios': 'municipios',
    'carregadores': 'carregadores',
    'medidores': 'medidores',
    'motoristas': 'motoristas',
    'munk': 'operadores',
    'localidades': 'localidades',
    'placas': 'placas',
  };

  MasterData parse(
    Uint8List bytes, {
    required String fileName,
    DateTime? importedAt,
  }) {
    late Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const MasterImportException(
        'O arquivo não é uma planilha XLSX válida.',
      );
    }
    final normalizedSheets = <String, String>{};
    for (final name in workbook.tables.keys) {
      normalizedSheets[name.trim().toLowerCase()] = name;
    }
    final lists = <String, List<String>>{};
    final compradoresDetalhados = <CompradorMaster>[];
    for (final entry in sheetMap.entries) {
      final actualName = normalizedSheets[entry.key];
      if (actualName == null) {
        throw MasterImportException('Aba obrigatória ausente: ${entry.key}.');
      }
      final sheet = workbook.tables[actualName]!;
      final header = _cellText(
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)),
      );
      if (header.trim().toLowerCase() != 'nome') {
        throw MasterImportException(
          'Cabeçalho inválido na aba ${entry.key}, célula A1: esperado “Nome”.',
        );
      }
      final values = <String>[];
      final seen = <String>{};
      for (var row = 1; row < sheet.maxRows; row++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        );
        if (cell.value is FormulaCellValue) continue;
        final value = _cellText(cell).trim();
        if (value.isEmpty) continue;
        if (entry.value == 'compradores') {
          values.add(value);
          compradoresDetalhados.add(
            CompradorMaster(
              chaveOrigem: 'compradores:linha:${row + 1}',
              nome: value,
            ),
          );
        } else if (seen.add(value.toLowerCase())) {
          values.add(value);
        }
      }
      if (values.isEmpty) {
        throw MasterImportException(
          'A aba ${entry.key} não possui registros válidos a partir da linha 2.',
        );
      }
      lists[entry.value] = values;
    }
    return MasterData(
      romaneadores: lists['romaneadores']!,
      compradores: lists['compradores']!,
      compradoresDetalhados: compradoresDetalhados,
      empreiteiros: lists['empreiteiros']!,
      proprietarios: lists['proprietarios']!,
      municipios: lists['municipios']!,
      carregadores: lists['carregadores']!,
      medidores: lists['medidores']!,
      motoristas: lists['motoristas']!,
      operadores: lists['operadores']!,
      localidades: lists['localidades']!,
      placas: lists['placas']!,
      fileName: fileName,
      importedAt: importedAt ?? DateTime.now(),
    );
  }

  String _cellText(Data cell) => cell.value?.toString() ?? '';
}
