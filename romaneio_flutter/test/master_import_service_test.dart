import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/main.dart';

void main() {
  Uint8List fixture({String? omit, String? empty}) {
    final book = Excel.createExcel();
    for (final name in MasterImportService.sheetMap.keys) {
      if (name == omit) continue;
      final sheet = book[name];
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(' Nome ');
      if (name != empty) {
        final value = name == 'munk' ? 'Munk José' : '$name Á';
        sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(value);
        sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
          '  ${value.toUpperCase()}  ',
        );
        if (name == 'placas') {
          sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
            'VARIAS',
          );
        }
      }
    }
    book.delete('Sheet1');
    return Uint8List.fromList(book.encode()!);
  }

  test('mapeia abas e preserva linhas distintas de compradores', () {
    final data = MasterImportService().parse(
      fixture(),
      fileName: 'mestre.xlsx',
    );
    expect(data.operadores, ['Munk José']);
    expect(data.carregadores, ['carregadores Á']);
    expect(data.compradores, ['compradores Á', 'COMPRADORES Á']);
    expect(data.cadastroCompradores.map((item) => item.chaveOrigem), [
      'compradores:linha:2',
      'compradores:linha:3',
    ]);
    expect(data.placas, ['placas Á', 'VARIAS']);
    expect(data.isValid, isTrue);
  });
  test('informa aba ausente ou vazia', () {
    expect(
      () => MasterImportService().parse(
        fixture(omit: 'municipios'),
        fileName: 'x.xlsx',
      ),
      throwsA(
        isA<MasterImportException>().having(
          (e) => e.message,
          'mensagem',
          contains('municipios'),
        ),
      ),
    );
    expect(
      () => MasterImportService().parse(
        fixture(empty: 'placas'),
        fileName: 'x.xlsx',
      ),
      throwsA(
        isA<MasterImportException>().having(
          (e) => e.message,
          'mensagem',
          contains('placas'),
        ),
      ),
    );
  });
  test('rejeita conteúdo que não é xlsx', () {
    expect(
      () => MasterImportService().parse(
        Uint8List.fromList([1, 2, 3]),
        fileName: 'falso.xlsx',
      ),
      throwsA(isA<MasterImportException>()),
    );
  });
}
