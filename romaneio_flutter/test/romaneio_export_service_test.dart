import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/main.dart';
import 'package:romaneio_flutter/services/romaneio_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'preenche o template sem perder imagens, desenho ou placeholders',
    () async {
      final bytes = await RomaneioExportService().generateXlsx(
        const Romaneio(
          id: 'R-1',
          romaneador: 'Jo\u00E3o',
          comprador: 'Madeiras Brasil',
          empreiteiros: ['Empreiteiro \u00C1', 'Empreiteiro B'],
          placas: ['ABC-1234', 'DEF-5678', 'GHI-9012'],
          toras: [
            Tora(diametro: 20, quantidade: 2, volumeTotal: 4),
            Tora(diametro: 32, quantidade: 1, volumeTotal: 3),
          ],
          precosPorClasse: {'18-24': 10, '30-34': 12},
        ),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
      expect(archive.findFile('xl/styles.xml'), isNotNull);
      expect(archive.findFile('xl/drawings/drawing1.xml'), isNotNull);
      expect(archive.findFile('xl/media/image1.png'), isNotNull);
      expect(archive.findFile('xl/media/image2.png'), isNotNull);
      expect(archive.findFile('xl/media/image3.png'), isNotNull);
      final sheet = utf8.decode(
        archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      final strings = utf8.decode(
        archive.findFile('xl/sharedStrings.xml')!.content as List<int>,
      );
      expect(sheet.contains(r'${'), isFalse);
      expect(strings.contains(r'${'), isFalse);
      expect(sheet, contains('Empreiteiro \u00C1'));
      expect(sheet, contains('ABC-1234'));
      expect(sheet, contains('Empreiteiro \u00C1'));
      expect(sheet, contains('\u2192'));
      expect(sheet, contains('mergeCell ref="A2:A37"'));
      final directory = Directory('.dart_tool/export_validation_xlsx_only');
      if (directory.existsSync()) await directory.delete(recursive: true);
      final batch =
          await RomaneioExportService(exportDirectory: () async => directory)
              .exportAll(
                const Romaneio(
                  id: 'R-validacao',
                  empreiteiros: ['E1'],
                  toras: [Tora(diametro: 20, quantidade: 1, volumeTotal: 1)],
                ),
              );
      expect(batch.allSucceeded, isTrue);
      expect(batch[RomaneioExportFormat.xlsx]!.succeeded, isTrue);
      expect(batch[RomaneioExportFormat.pdf], isNull);
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.pdf'),
        ),
        isEmpty,
      );
    },
  );

  test('mantém as colunas legadas disponíveis', () {
    expect(RomaneioExportService.spreadsheetColumns.first.header, 'ID');
    expect(
      RomaneioExportService.spreadsheetColumns.last.header,
      'Observa\u00E7\u00F5es',
    );
  });

  test(
    'gera PDF completo em uma única página sem interpolação literal',
    () async {
      final bytes = await RomaneioExportService().generatePdf(
        const Romaneio(
          id: 'R-PDF-1',
          romaneador: 'João',
          comprador: 'Comprador',
          proprietario: 'Proprietário',
          medidor: 'Medidor',
          motorista: 'Motorista',
          carregador: 'Operador',
          operador: 'Munk 01',
          municipio: 'Mallet',
          localidade: 'Linha A',
          data: '03/09/2026',
          hora: '10:30',
          empreiteiros: ['E1', 'E2'],
          placas: ['ABC-1234'],
          toras: [
            Tora(diametro: 20, quantidade: 1, volumeTotal: 1),
            Tora(diametro: 32, quantidade: 2, volumeTotal: 2),
          ],
          doPe: true,
          comNo: true,
          segundaTora: false,
        ),
      );
      final text = utf8.decode(bytes, allowMalformed: true);
      await File('.dart_tool/export_validation_pdf_only/full.pdf')
          .writeAsBytes(bytes);
      expect(bytes, isNotEmpty);
      expect(text, contains('/Count 1'));
      expect(text.toLowerCase(), isNot(contains('instance of')));
      expect(text.toLowerCase(), isNot(contains('nan')));
    },
  );
}
