import 'dart:io';

class BluetoothPrinter {
  const BluetoothPrinter({
    required this.name,
    required this.address,
    this.paired = false,
  });

  final String name;
  final String address;
  final bool paired;
}

class BluetoothPrintException implements Exception {
  const BluetoothPrintException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Boundary for the platform-specific Bluetooth printer implementation.
///
/// The app deliberately does not write PDF bytes directly to a socket: the
/// eventual Android adapter must translate the PDF to the printer protocol.
abstract class BluetoothPrintService {
  Future<bool> get isSupported;
  Future<bool> get isEnabled;
  Future<void> requestPermissions();
  Future<void> openBluetoothSettings();
  Future<List<BluetoothPrinter>> findPrinters();
  Future<void> connect(BluetoothPrinter printer);
  Future<void> printPdf(String pdfPath);
  Future<void> disconnect();
}

/// Safe fallback until a physical-printer adapter is configured for Android.
class UnavailableBluetoothPrintService implements BluetoothPrintService {
  const UnavailableBluetoothPrintService();

  @override
  Future<bool> get isSupported async => Platform.isAndroid;

  @override
  Future<bool> get isEnabled async => false;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> openBluetoothSettings() async {}

  @override
  Future<List<BluetoothPrinter>> findPrinters() async => const [];

  @override
  Future<void> connect(BluetoothPrinter printer) async {
    throw const BluetoothPrintException(
      'A integração Bluetooth ainda não está configurada neste dispositivo.',
    );
  }

  @override
  Future<void> printPdf(String pdfPath) async {
    throw const BluetoothPrintException(
      'A integração Bluetooth ainda não está configurada neste dispositivo.',
    );
  }

  @override
  Future<void> disconnect() async {}
}
