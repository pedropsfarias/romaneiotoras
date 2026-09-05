import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/romaneio.dart';
import 'balanceamento_service.dart';

enum RomaneioExportFormat { pdf, xlsx }

class RomaneioExportResult {
  const RomaneioExportResult._({required this.format, this.file, this.error});
  factory RomaneioExportResult.success(
    RomaneioExportFormat format,
    File file,
  ) => RomaneioExportResult._(format: format, file: file);
  factory RomaneioExportResult.failure(
    RomaneioExportFormat format,
    Object error,
  ) => RomaneioExportResult._(format: format, error: error);
  final RomaneioExportFormat format;
  final File? file;
  final Object? error;
  bool get succeeded => file != null;
}

class RomaneioExportBatchResult {
  const RomaneioExportBatchResult(this.results);
  final Map<RomaneioExportFormat, RomaneioExportResult> results;
  RomaneioExportResult? operator [](RomaneioExportFormat format) =>
      results[format];
  bool get allSucceeded => results.values.every((result) => result.succeeded);
}

class RomaneioSpreadsheetColumn {
  const RomaneioSpreadsheetColumn(this.header, this.value);
  final String header;
  final Object Function(Romaneio romaneio) value;
}

class RomaneioExportService {
  RomaneioExportService({
    Future<Directory> Function()? exportDirectory,
    this.templatePath,
  }) : _exportDirectory = exportDirectory ?? _defaultExportDirectory;
  static const _templateAsset = 'assets/templates/romaneio_template.xlsx';
  final Future<Directory> Function() _exportDirectory;
  final String? templatePath;
  static const _downloadsChannel = MethodChannel('romaneio_flutter/downloads');

  static String _balanceText(Romaneio r, BalanceamentoRow row) {
    if (r.tipoBalanceamento == TipoBalanceamento.metroCubico) {
      return '${row.empreiteiro} → ${row.volume.toStringAsFixed(3)} m³';
    }
    final label = row.quantidade == 1 ? 'tora' : 'toras';
    return '${row.empreiteiro} → ${row.quantidade} $label';
  }

  static String _balanceTextSafe(Romaneio r, BalanceamentoRow row) {
    final arrow = String.fromCharCode(0x2192);
    if (r.tipoBalanceamento == TipoBalanceamento.metroCubico) {
      return '${row.empreiteiro} $arrow ${row.volume.toStringAsFixed(3)} m${String.fromCharCode(0xB3)}';
    }
    final label = row.quantidade == 1 ? 'tora' : 'toras';
    return '${row.empreiteiro} $arrow ${row.quantidade} $label';
  }

  static String _visibleNumber(Romaneio r) =>
      r.numeroRomaneio > 0 ? '${r.numeroRomaneio}' : '-';

  static String _balanceType(Romaneio r) =>
      r.tipoBalanceamento == TipoBalanceamento.metroCubico
      ? 'Por metro cúbico'
      : 'Por número de toras';

  static final List<RomaneioSpreadsheetColumn> spreadsheetColumns = [
    RomaneioSpreadsheetColumn('ID', _visibleNumber),
    RomaneioSpreadsheetColumn('Romaneador', (r) => r.romaneador),
    RomaneioSpreadsheetColumn('Comprador', (r) => r.comprador),
    RomaneioSpreadsheetColumn('ProprietÃƒÆ’Ã‚Â¡rio', (r) => r.proprietario),
    RomaneioSpreadsheetColumn('Localidade', (r) => r.localidade),
    RomaneioSpreadsheetColumn('MunicÃƒÆ’Ã‚Â­pio', (r) => r.municipio),
    RomaneioSpreadsheetColumn('Data', (r) => r.data),
    RomaneioSpreadsheetColumn('Hora', (r) => r.hora),
    RomaneioSpreadsheetColumn(
      'Quantidade total',
      (r) => r.summary()['numToras']!,
    ),
    RomaneioSpreadsheetColumn(
      'Volume total (m\\u00B3)',
      (r) => r.summary()['volToras']!,
    ),
    RomaneioSpreadsheetColumn('PreÃƒÆ’Ã‚Â§o estimado', (r) => r.totalPrice()),
    RomaneioSpreadsheetColumn('Observa\u00E7\u00F5es', (r) => r.observacoes),
  ];

  static Future<Directory> _defaultExportDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/romaneio_exports');
  }

  Future<Archive> _template() async {
    final bytes = templatePath == null
        ? (await rootBundle.load(_templateAsset)).buffer.asUint8List()
        : await File(templatePath!).readAsBytes();
    return ZipDecoder().decodeBytes(bytes);
  }

  static ArchiveFile _file(Archive archive, String name) =>
      archive.findFile(name) ?? (throw StateError('Template sem $name.'));

  static void _replaceArchiveFile(
    Archive archive,
    String name,
    List<int> bytes,
  ) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static void _validateXlsx(Uint8List bytes) {
    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4b ||
        (bytes[2] != 0x03 && bytes[2] != 0x05 && bytes[2] != 0x07)) {
      throw const FormatException(
        'O arquivo gerado não possui assinatura ZIP.',
      );
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((file) => file.name).toSet();
    const required = [
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
    ];
    if (required.any((name) => !names.contains(name))) {
      throw const FormatException('O arquivo Excel está incompleto.');
    }
    for (final name in [
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/worksheets/sheet1.xml',
    ]) {
      final content = utf8.decode(_file(archive, name).content as List<int>);
      if (content.contains(r'${') ||
          content.contains('#REF!') ||
          content.contains('Instance of') ||
          content.contains('NaN')) {
        throw const FormatException('O arquivo Excel contém dados inválidos.');
      }
      if (!content.trimLeft().startsWith('<?xml') && name != '_rels/.rels') {
        throw const FormatException('XML inválido no arquivo Excel.');
      }
    }
  }

  static String _xml(String value) =>
      const HtmlEscape(HtmlEscapeMode.element).convert(value);
  static String _safe(String value) => value.trim();
  static String _yes(bool value) => value ? 'Sim' : 'N\u00E3o';
  static double _finite(num value) => value.isFinite ? value.toDouble() : 0;
  static String _money(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  static String formatPdfValue(Object? value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  static void _validatePdfText(Iterable<String> values) {
    for (final value in values) {
      final lower = value.toLowerCase();
      if (value.contains(r'${') ||
          value.contains('}') ||
          lower.contains('value') ||
          lower == 'null' ||
          lower.contains('instance of') ||
          lower.contains('nan')) {
        throw StateError('Texto inválido no PDF: $value');
      }
    }
  }

  static String _replaceCell(
    String xml,
    String ref,
    Object value, {
    required bool number,
  }) {
    final pattern = RegExp('<c[^>]*\\br="$ref"[^>]*>.*?</c>', dotAll: true);
    return xml.replaceFirstMapped(pattern, (match) {
      var attrs = RegExp(r'<c([^>]*)>')
          .firstMatch(match.group(0)!)!
          .group(1)!
          .replaceAll(RegExp(r'\s+t="[^"]*"'), '');
      attrs = attrs.replaceFirst(RegExp(r'/\s*$'), '');
      attrs = attrs.replaceAll(RegExp(r'\s+r="[^"]*"'), '');
      if (number) {
        final numberValue = value is double
            ? value.toStringAsFixed(12)
            : '$value';
        return '<c r="$ref"$attrs><v>$numberValue</v></c>';
      }
      return '<c r="$ref"$attrs t="inlineStr"><is><t>${_xml('$value')}</t></is></c>';
    });
  }

  static String _setRowCell(
    String row,
    String column,
    int rowNumber,
    Object value, {
    required bool number,
  }) => _replaceCell(row, '$column$rowNumber', value, number: number);

  static String _row(String template, int number, Map<String, Object> values) {
    var row = template.replaceFirst(
      RegExp(r'<row r="\d+"'),
      '<row r="$number"',
    );
    final oldNumber = int.parse(
      RegExp(r'<row r="(\d+)"').firstMatch(template)!.group(1)!,
    );
    row = row.replaceAllMapped(
      RegExp('(<c[^>]*\\br=")([A-Z]+)$oldNumber(")'),
      (match) => '${match.group(1)}${match.group(2)}$number${match.group(3)}',
    );
    for (final entry in values.entries)
      row = _setRowCell(
        row,
        entry.key,
        number,
        entry.value,
        number: entry.value is num,
      );
    return row;
  }

  static String _shiftRows(String xml, int after, int amount) {
    if (amount == 0) return xml;
    var shifted = xml.replaceAllMapped(RegExp(r'<row r="(\d+)"'), (m) {
      final row = int.parse(m.group(1)!);
      return row > after ? '<row r="${row + amount}"' : m.group(0)!;
    });
    shifted = shifted.replaceAllMapped(
      RegExp(r'(<c[^>]*\br=")([A-Z]+)(\d+)(")'),
      (m) {
        final row = int.parse(m.group(3)!);
        return row > after
            ? '${m.group(1)}${m.group(2)}${row + amount}${m.group(4)}'
            : m.group(0)!;
      },
    );
    return shifted;
  }

  static String _shiftDrawing(String xml, int after, int amount) => amount == 0
      ? xml
      : xml.replaceAllMapped(
          RegExp(
            r'(<xdr:(?:from|to)>.*?<xdr:row>)(\d+)(</xdr:row>)',
            dotAll: true,
          ),
          (m) {
            final row = int.parse(m.group(2)!);
            return '${m.group(1)}${row > after ? row + amount : row}${m.group(3)}';
          },
        );

  Map<String, Object> _fields(Romaneio r) {
    final summary = r.summary();
    final total = summary['numToras'] as int;
    final average = total == 0
        ? 0.0
        : r.toras.fold<int>(0, (s, t) => s + t.diametro * t.quantidade) / total;
    return {
      r'${id}': _visibleNumber(r),
      r'${romaneador}': _safe(r.romaneador),
      r'${comprador}': _safe(r.comprador),
      r'${proprietario}': _safe(r.proprietario),
      r'${medidor}': _safe(r.medidor),
      r'${motorista}': _safe(r.motorista),
      r'${carregador}': _safe(r.carregador),
      r'${operador}': _safe(r.operador),
      r'${municipio}': _safe(r.municipio),
      r'${localidade}': _safe(r.localidade),
      r'${data}': _safe(r.data),
      r'${hora}': _safe(r.hora),
      r'${comprimento}': _finite(r.comprimento),
      r'${numToras}': total,
      r'${diamMedio}': _finite(average),
      r'${volToras}': _finite(summary['volToras'] as double),
      r'${doPe}': _yes(r.doPe),
      r'${comNo}': _yes(r.comNo),
      r'${tora2}': _yes(r.segundaTora),
    };
  }

  static String _replaceShared(String xml, Map<String, Object> fields) =>
      xml.replaceAllMapped(RegExp(r'<t([^>]*)>(.*?)</t>', dotAll: true), (m) {
        final value = m.group(2)!;
        final replacement = fields[value];
        if (replacement != null)
          return '<t${m.group(1)!}>${_xml('$replacement')}</t>';
        if (value.startsWith(r'${')) return '<t${m.group(1)!}></t>';
        return m.group(0)!;
      });

  Future<Uint8List> generateXlsx(Romaneio r) async {
    final archive = await _template();
    final sheetFile = _file(archive, 'xl/worksheets/sheet1.xml');
    final stringsFile = _file(archive, 'xl/sharedStrings.xml');
    final drawingFile = _file(archive, 'xl/drawings/drawing1.xml');
    var sheet = utf8.decode(sheetFile.content as List<int>);
    final fields = _fields(r);
    String templateRow(int number) => RegExp(
      '<row r="$number"[^>]*>.*?</row>',
      dotAll: true,
    ).firstMatch(sheet)!.group(0)!;
    final contractorTemplate = templateRow(10);
    final logTemplate = templateRow(16);
    final balanceTemplate = templateRow(31);
    final contractorCount = [
      r.empreiteiros.length,
      r.placas.length,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final logCount = r.toras.isEmpty ? 1 : r.toras.length;
    final balances = const BalanceamentoService().rows(r);
    final balanceCount = balances.isEmpty ? 1 : balances.length;
    final contractorExtra = contractorCount - 1;
    final logStart = 16 + contractorExtra;
    final logExtra = logCount - 1;
    final balanceStart = 31 + contractorExtra + logExtra;
    final balanceExtra = balanceCount - 1;
    sheet = _shiftRows(sheet, 10, contractorExtra);
    sheet = _shiftRows(sheet, logStart, logExtra);
    sheet = _shiftRows(sheet, balanceStart, balanceExtra);
    final contractors = [
      for (var i = 0; i < contractorCount; i++)
        _row(contractorTemplate, 10 + i, {
          'B': i == 0 ? 'Empreiteiro(s):' : '',
          'C': i < r.empreiteiros.length ? r.empreiteiros[i] : '',
          'E': i == 0 ? 'Placa(s):' : '',
          'F': i < r.placas.length ? r.placas[i] : '',
        }),
    ];
    final logs = [
      for (var i = 0; i < logCount; i++)
        () {
          final tora = r.toras.isEmpty
              ? const Tora(diametro: 0, quantidade: 0)
              : r.toras[i];
          final total = _finite(r.volumeDaTora(tora));
          return _row(logTemplate, logStart + i, {
            'B': tora.diametro,
            'C': tora.quantidade,
            'D': _finite(tora.quantidade == 0 ? 0 : total / tora.quantidade),
            'E': total,
          });
        }(),
    ];
    final balanceRows = [
      for (var i = 0; i < balanceCount; i++)
        _row(balanceTemplate, balanceStart + i, {
          'B': i < balances.length ? _balanceTextSafe(r, balances[i]) : '',
        }),
    ];
    sheet = sheet.replaceFirst(templateRow(10), contractors.join());
    sheet = sheet.replaceFirst(templateRow(logStart), logs.join());
    sheet = sheet.replaceFirst(templateRow(balanceStart), balanceRows.join());
    final simple = <String, Object>{
      'C3': fields[r'${id}']!,
      'F3': fields[r'${romaneador}']!,
      'C5': fields[r'${comprador}']!,
      'F5': fields[r'${medidor}']!,
      'C6': fields[r'${proprietario}']!,
      'F6': fields[r'${motorista}']!,
      'C7': fields[r'${carregador}']!,
      'F7': fields[r'${operador}']!,
      'C8': fields[r'${municipio}']!,
      'F8': fields[r'${data}']!,
      'C9': fields[r'${localidade}']!,
      'F9': fields[r'${hora}']!,
      'D12': fields[r'${comprimento}']!,
      'F12': fields[r'${numToras}']!,
      'C13': fields[r'${diamMedio}']!,
      'C17': fields[r'${numToras}']!,
      'E17': fields[r'${volToras}']!,
      'C25': fields[r'${numToras}']!,
      'D25': fields[r'${volToras}']!,
      'E25': '-',
      'F25': _finite(r.totalPrice()),
      'C27': fields[r'${doPe}']!,
      'C28': fields[r'${comNo}']!,
      'C29': fields[r'${tora2}']!,
    };
    for (var i = 0; i < 5; i++) {
      final key = i + 1;
      final classItems = r.toras.where(
        (t) =>
            Romaneio.priceClassForDiameter(t.diametro) ==
            Romaneio.priceClassKeys[i],
      );
      final quantity = classItems.fold(0, (sum, t) => sum + t.quantidade);
      final volume = _finite(
        classItems.fold(0.0, (sum, t) => sum + r.volumeDaTora(t)),
      );
      final price = r.precosPorClasse[Romaneio.priceClassKeys[i]];
      final total = price == null ? 0.0 : volume * price;
      simple['C${19 + key}'] = quantity == 0 ? '-' : quantity;
      simple['D${19 + key}'] = volume == 0 ? '-' : volume;
      simple['E${19 + key}'] = price == null ? '-' : price;
      simple['F${19 + key}'] = total == 0 ? '-' : total;
    }
    for (final entry in simple.entries) {
      final original = int.parse(
        RegExp(r'\d+').firstMatch(entry.key)!.group(0)!,
      );
      var row = original;
      if (row > 10) row += contractorExtra;
      if (row > logStart) row += logExtra;
      if (row > balanceStart) row += balanceExtra;
      final ref = entry.key.replaceFirst(RegExp(r'\d+'), '$row');
      sheet = _replaceCell(sheet, ref, entry.value, number: entry.value is num);
    }
    final end = 33 + contractorExtra + logExtra + balanceExtra;
    sheet = sheet.replaceFirst(
      RegExp(r'<dimension ref="A1:I\d+"/>'),
      '<dimension ref="A1:I$end"/>',
    );
    sheet = sheet.replaceFirst(
      RegExp(r'<mergeCell ref="A2:A\d+"/>'),
      '<mergeCell ref="A2:A$end"/>',
    );
    var drawing = utf8.decode(drawingFile.content as List<int>);
    drawing = _shiftDrawing(drawing, 10, contractorExtra);
    drawing = _shiftDrawing(drawing, logStart, logExtra);
    drawing = _shiftDrawing(drawing, balanceStart, balanceExtra);
    _replaceArchiveFile(
      archive,
      'xl/sharedStrings.xml',
      utf8.encode(
        _replaceShared(
          utf8
              .decode(stringsFile.content as List<int>)
              .replaceAll('ROMANEIO DE TORAS', 'ROMANEIO TORAS MIERZVA'),
          fields,
        ),
      ),
    );
    _replaceArchiveFile(
      archive,
      'xl/worksheets/sheet1.xml',
      utf8.encode(sheet),
    );
    _replaceArchiveFile(
      archive,
      'xl/drawings/drawing1.xml',
      utf8.encode(drawing),
    );
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null || bytes.isEmpty)
      throw StateError('N\\u00E3o foi poss\\u00EDvel gerar o arquivo Excel.');
    final output = Uint8List.fromList(bytes);
    _validateXlsx(output);
    final outputArchive = ZipDecoder().decodeBytes(output);
    final outputSheet = utf8.decode(
      _file(outputArchive, 'xl/worksheets/sheet1.xml').content as List<int>,
    );
    final outputStrings = utf8.decode(
      _file(outputArchive, 'xl/sharedStrings.xml').content as List<int>,
    );
    if (outputSheet.contains(r'${') || outputStrings.contains(r'${'))
      throw StateError('O arquivo Excel ainda contÃƒÆ’Ã‚Â©m placeholders.');
    return output;
  }

  Future<Uint8List> generatePdf(Romaneio r) async {
    final archive = await _template();
    final logo = _file(archive, 'xl/media/image2.png').content as List<int>;
    final image = pw.MemoryImage(Uint8List.fromList(logo));
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/arial.ttf'));
    final summary = r.summary();
    final balances = const BalanceamentoService().rows(r);
    final border = pw.TableBorder.all(color: PdfColors.grey400, width: .5);
    _validatePdfText([
      _visibleNumber(r),
      r.romaneador,
      r.comprador,
      r.proprietario,
      r.medidor,
      r.motorista,
      r.carregador,
      r.operador,
      r.municipio,
      r.localidade,
      r.data,
      r.hora,
      ...r.empreiteiros,
      ...r.placas,
      for (final row in balances)
        '${row.empreiteiro} ${row.quantidade} ${row.volume}',
    ]);

    pw.Widget info(String label, Object? value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: formatPdfValue(value)),
          ],
        ),
      ),
    );

    pw.Widget table({
      required List<String> headers,
      required List<List<Object?>> data,
    }) => pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: border,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 9.5),
      cellPadding: const pw.EdgeInsets.all(5),
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: font, bold: font),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.topLeft,
          child: pw.SizedBox(
            width: 540,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Image(
                    image,
                    width: 180,
                    height: 75,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'ROMANEIO DE TORAS',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(),
                    1: pw.FlexColumnWidth(),
                  },
                  children: [
                    for (final pair in <List<List<Object?>>>[
                      [
                        ['N\u00BA', _visibleNumber(r)],
                        ['Romaneador', r.romaneador],
                      ],
                      [
                        ['Comprador', r.comprador],
                        ['Medidor', r.medidor],
                      ],
                      [
                        ['Propriet\u00E1rio', r.proprietario],
                        ['Motorista', r.motorista],
                      ],
                      [
                        ['Operador do Munk', r.carregador],
                        ['Munk', r.operador],
                      ],
                      [
                        ['Munic\u00EDpio', r.municipio],
                        ['Data', r.data],
                      ],
                      [
                        ['Localidade', r.localidade],
                        ['Hora', r.hora],
                      ],
                    ])
                      pw.TableRow(
                        children: [
                          info(pair[0][0] as String, pair[0][1]),
                          info(pair[1][0] as String, pair[1][1]),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 8),
                table(
                  headers: ['Empreiteiro(s)', 'Placa(s)'],
                  data: [
                    for (
                      var i = 0;
                      i <
                          [
                            r.empreiteiros.length,
                            r.placas.length,
                            1,
                          ].reduce((a, b) => a > b ? a : b);
                      i++
                    )
                      [
                        i < r.empreiteiros.length ? r.empreiteiros[i] : '-',
                        i < r.placas.length ? r.placas[i] : '-',
                      ],
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Dados das toras',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 18,
                  runSpacing: 4,
                  children: [
                    info('Comprimento da tora (m)', r.comprimento),
                    info('N\u00FAmero total de toras', summary['numToras']),
                    info(
                      'Di\u00E2metro m\u00E9dio',
                      r.toras.isEmpty
                          ? '-'
                          : (r.toras.fold<int>(
                                      0,
                                      (s, t) => s + t.diametro * t.quantidade,
                                    ) /
                                    (summary['numToras'] as int))
                                .toStringAsFixed(1),
                    ),
                  ],
                ),
                table(
                  headers: [
                    'Di\u00E2metro',
                    'N\u00BA de toras',
                    'C\u00FAbico unit\u00E1rio',
                    'Total (m\u00B3)',
                  ],
                  data: [
                    for (final tora in r.toras)
                      [
                        tora.diametro,
                        tora.quantidade,
                        (tora.quantidade == 0
                                ? 0
                                : r.volumeDaTora(tora) / tora.quantidade)
                            .toStringAsFixed(3),
                        r.volumeDaTora(tora).toStringAsFixed(3),
                      ],
                    [
                      'TOTAL',
                      summary['numToras'],
                      '-',
                      _finite(summary['volToras'] as double).toStringAsFixed(3),
                    ],
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Resumo por classe diam\u00E9trica',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                table(
                  headers: [
                    'Di\u00E2metros',
                    'Quantidade',
                    'Volume (m\u00B3)',
                    'Pre\u00E7o Unit\u00E1rio',
                    'Valor Total',
                  ],
                  data: [
                    for (final key in Romaneio.priceClassKeys)
                      () {
                        final items = r.toras.where(
                          (t) =>
                              Romaneio.priceClassForDiameter(t.diametro) == key,
                        );
                        final q = items.fold(0, (s, t) => s + t.quantidade);
                        final v = items.fold(
                          0.0,
                          (s, t) => s + r.volumeDaTora(t),
                        );
                        final p = r.precosPorClasse[key];
                        return [
                          key.replaceAll('-', ' a '),
                          q == 0 ? '-' : '$q',
                          v == 0 ? '-' : v.toStringAsFixed(3),
                          p == null ? '-' : _money(p),
                          v == 0 || p == null ? '-' : _money(v * p),
                        ];
                      }(),
                    [
                      'TOTAL',
                      summary['numToras'],
                      _finite(summary['volToras'] as double).toStringAsFixed(3),
                      '-',
                      _money(r.totalPrice()),
                    ],
                  ],
                ),
                pw.SizedBox(height: 16),
                table(
                  headers: ['Do p\u00E9', 'Com n\u00F3', '2\u00AA tora'],
                  data: [
                    [_yes(r.doPe), _yes(r.comNo), _yes(r.segundaTora)],
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Balanceamento',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Tipo: ${_balanceType(r)}'),
                pw.SizedBox(height: 4),
                table(
                  headers: const ['Empreiteiro', 'Balanceamento'],
                  data: [
                    for (final row in balances)
                      [row.empreiteiro, _balanceTextSafe(r, row)],
                    r.tipoBalanceamento == TipoBalanceamento.metroCubico
                        ? [
                            'TOTAL',
                            '${_finite(summary['volToras'] as double).toStringAsFixed(3)} m³',
                          ]
                        : [
                            'TOTAL',
                            '${summary['numToras']} ${summary['numToras'] == 1 ? 'tora' : 'toras'}',
                          ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return pdf.save();
  }

  Future<RomaneioExportResult> export(
    Romaneio r,
    RomaneioExportFormat format,
  ) async {
    File? temporary;
    try {
      final directory = await _exportDirectory();
      await directory.create(recursive: true);
      final safeId = r.numeroRomaneio > 0
          ? 'R-${r.numeroRomaneio}'
          : r.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${directory.path}/romaneio_$safeId.${format.name}');
      temporary = File('${file.path}.tmp');
      final bytes = format == RomaneioExportFormat.pdf
          ? await generatePdf(r)
          : await generateXlsx(r);
      await temporary.writeAsBytes(bytes, flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      if (Platform.isAndroid) {
        await _downloadsChannel.invokeMethod<void>('saveToDownloads', {
          'filename': file.uri.pathSegments.last,
          'bytes': bytes,
        });
      }
      return RomaneioExportResult.success(format, file);
    } catch (error) {
      if (temporary != null && await temporary.exists())
        await temporary.delete();
      return RomaneioExportResult.failure(format, error);
    }
  }

  Future<RomaneioExportBatchResult> exportAll(
    Romaneio r, {
    Set<RomaneioExportFormat> formats = const {RomaneioExportFormat.xlsx},
  }) async {
    final entries = await Future.wait(
      formats.map((format) async => MapEntry(format, await export(r, format))),
    );
    return RomaneioExportBatchResult(Map.fromEntries(entries));
  }
}
