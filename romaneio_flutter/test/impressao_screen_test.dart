import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romaneio_flutter/main.dart';

class _FakeBluetoothPrintService implements BluetoothPrintService {
  _FakeBluetoothPrintService({this.printers = const []});
  final List<BluetoothPrinter> printers;
  int connectCalls = 0;
  int printCalls = 0;

  @override
  Future<bool> get isSupported async => true;
  @override
  Future<bool> get isEnabled async => true;
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> openBluetoothSettings() async {}
  @override
  Future<List<BluetoothPrinter>> findPrinters() async => List.of(printers);
  @override
  Future<void> connect(BluetoothPrinter printer) async => connectCalls++;
  @override
  Future<void> printPdf(String pdfPath) async => printCalls++;
  @override
  Future<void> disconnect() async {}
}

Widget _screen({
  required _FakeBluetoothPrintService service,
  VoidCallback? back,
  VoidCallback? finalizados,
}) => MaterialApp(
  home: ImpressaoScreen(
    romaneio: const Romaneio(
      id: 'R-TESTE',
      romaneador: 'Leon',
      toras: [Tora(diametro: 20, quantidade: 2, volumeTotal: 1)],
    ),
    pdfPath: null,
    onBackToSummary: back ?? () {},
    onFinalizados: finalizados ?? () {},
    bluetoothService: service,
  ),
);

void main() {
  testWidgets('mostra somente finalizados e imprimir', (tester) async {
    var openedFinalizados = false;
    await tester.pumpWidget(
      _screen(
        service: _FakeBluetoothPrintService(),
        finalizados: () => openedFinalizados = true,
      ),
    );
    expect(find.text('Romaneio'), findsOneWidget);
    expect(find.textContaining('Romaneador'), findsOneWidget);
    expect(find.byKey(const ValueKey('back-to-summary-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('view-finalizados-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('print-button')), findsOneWidget);
    final finalizadosButton = find.byKey(
      const ValueKey('view-finalizados-button'),
    );
    await tester.ensureVisible(finalizadosButton);
    await tester.tap(finalizadosButton);
    expect(openedFinalizados, isTrue);
  });

  testWidgets('minitela lista impressoras e não imprime sem PDF', (
    tester,
  ) async {
    final service = _FakeBluetoothPrintService(
      printers: const [BluetoothPrinter(name: 'Zebra', address: 'AA:BB')],
    );
    await tester.pumpWidget(_screen(service: service));
    final printButton = find.byKey(const ValueKey('print-button'));
    await tester.ensureVisible(printButton);
    await tester.tap(printButton);
    await tester.pumpAndSettle();
    expect(find.text('Escolher impressora Bluetooth'), findsOneWidget);
    expect(find.text('Zebra'), findsOneWidget);
    await tester.tap(find.text('Zebra'));
    await tester.pumpAndSettle();
    expect(find.text('O arquivo PDF não foi encontrado'), findsOneWidget);
    expect(service.connectCalls, 0);
    expect(service.printCalls, 0);
  });

  testWidgets('envia o mesmo PDF uma única vez com serviço falso', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/romaneio-test.pdf')
      ..writeAsBytesSync([37, 80, 68, 70]);
    final service = _FakeBluetoothPrintService(
      printers: const [BluetoothPrinter(name: 'Impressora', address: '11:22')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImpressaoScreen(
          romaneio: const Romaneio(id: 'R-PRINT'),
          pdfPath: file.path,
          onBackToSummary: () {},
          bluetoothService: service,
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('print-button')));
    await tester.tap(find.byKey(const ValueKey('print-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Impressora'));
    await tester.pumpAndSettle();
    expect(service.connectCalls, 1);
    expect(service.printCalls, 1);
    expect(find.text('Impressão enviada com sucesso'), findsOneWidget);
    file.deleteSync();
  });
}
