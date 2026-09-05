part of '../main.dart';

class ImpressaoScreen extends StatefulWidget {
  const ImpressaoScreen({
    super.key,
    required this.romaneio,
    required this.pdfPath,
    required this.onBackToSummary,
    this.onFinalizados,
    required this.bluetoothService,
    this.showPdfMissingNotice = false,
  });

  final Romaneio romaneio;
  final String? pdfPath;
  final VoidCallback onBackToSummary;
  final VoidCallback? onFinalizados;
  final BluetoothPrintService bluetoothService;
  final bool showPdfMissingNotice;

  @override
  State<ImpressaoScreen> createState() => _ImpressaoScreenState();
}

class _ImpressaoScreenState extends State<ImpressaoScreen> {
  bool _opening = false;

  Future<void> _openPrinters() async {
    if (_opening) return;
    setState(() => _opening = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BluetoothPrinterSheet(
        service: widget.bluetoothService,
        pdfPath: widget.pdfPath,
      ),
    );
    if (mounted) setState(() => _opening = false);
  }

  Widget _buttons(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Excel salvo em Downloads:\nromaneio_R-${widget.romaneio.numeroRomaneio}.xlsx',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (widget.showPdfMissingNotice &&
            (widget.pdfPath == null || !File(widget.pdfPath!).existsSync()))
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'O arquivo PDF não foi encontrado',
              style: TextStyle(color: Colors.red),
            ),
          ),
        if (widget.onFinalizados != null)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('view-finalizados-button'),
                  onPressed: widget.onFinalizados,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('VER FINALIZADOS'),
                  style: _buttonStyle(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('print-button'),
                  onPressed: _opening ? null : _openPrinters,
                  icon: const Icon(Icons.print),
                  label: const Text('IMPRIMIR'),
                  style: _buttonStyle(),
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const ValueKey('print-button'),
              onPressed: _opening ? null : _openPrinters,
              icon: const Icon(Icons.print),
              label: const Text('IMPRIMIR'),
              style: _buttonStyle(),
            ),
          ),
      ],
    ),
  );

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF26A69A),
    foregroundColor: Colors.white,
    minimumSize: const Size(0, 52),
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) widget.onBackToSummary();
    },
    child: RomaneioScreen(
      romaneio: widget.romaneio,
      onBack: widget.onBackToSummary,
      onFinalize: (value) async => value,
      onFinished: () {},
      onChanged: (_) {},
      showFinalize: false,
      footerBuilder: _buttons,
    ),
  );
}

enum _PrinterPhase { loading, ready, connecting, sending, success }

class _BluetoothPrinterSheet extends StatefulWidget {
  const _BluetoothPrinterSheet({required this.service, required this.pdfPath});
  final BluetoothPrintService service;
  final String? pdfPath;

  @override
  State<_BluetoothPrinterSheet> createState() => _BluetoothPrinterSheetState();
}

class _BluetoothPrinterSheetState extends State<_BluetoothPrinterSheet> {
  _PrinterPhase _phase = _PrinterPhase.loading;
  List<BluetoothPrinter> _printers = const [];
  BluetoothPrinter? _selected;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _PrinterPhase.loading;
      _error = null;
    });
    try {
      if (!await widget.service.isSupported)
        throw const BluetoothPrintException(
          'Bluetooth não disponível neste dispositivo',
        );
      await widget.service.requestPermissions();
      if (!await widget.service.isEnabled)
        throw const BluetoothPrintException('Bluetooth está desligado');
      final found = List<BluetoothPrinter>.of(
        await widget.service.findPrinters(),
      );
      found.sort((a, b) {
        if (a.paired == b.paired) return 0;
        return a.paired ? -1 : 1;
      });
      if (mounted)
        setState(() {
          _printers = found;
          _phase = _PrinterPhase.ready;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _phase = _PrinterPhase.ready;
          _error = _message(error);
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is BluetoothPrintException
      ? error.message
      : 'Falha ao procurar impressoras: $error';

  Future<void> _print(BluetoothPrinter printer) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _selected = printer;
      _error = null;
      _phase = _PrinterPhase.connecting;
    });
    try {
      final path = widget.pdfPath;
      if (path == null || !File(path).existsSync())
        throw const BluetoothPrintException('O arquivo PDF não foi encontrado');
      await widget.service.connect(printer);
      if (mounted) setState(() => _phase = _PrinterPhase.sending);
      await widget.service.printPdf(path);
      if (mounted) {
        setState(() => _phase = _PrinterPhase.success);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impressão enviada com sucesso')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _phase = _PrinterPhase.ready;
          _error = _message(error);
        });
    } finally {
      await widget.service.disconnect();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_phase) {
      _PrinterPhase.loading => 'Procurando impressoras…',
      _PrinterPhase.connecting => 'Conectando à impressora…',
      _PrinterPhase.sending => 'Enviando para impressão…',
      _PrinterPhase.success => 'Impressão enviada com sucesso',
      _PrinterPhase.ready => null,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escolher impressora Bluetooth',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    if (_phase != _PrinterPhase.success)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(status)),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_error == 'Bluetooth está desligado')
              OutlinedButton.icon(
                onPressed: _busy ? null : widget.service.openBluetoothSettings,
                icon: const Icon(Icons.settings_bluetooth),
                label: const Text('ATIVAR BLUETOOTH'),
              ),
            if (_phase == _PrinterPhase.ready && _printers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Nenhuma impressora encontrada',
                  textAlign: TextAlign.center,
                ),
              ),
            if (_phase == _PrinterPhase.ready)
              ..._printers.map(
                (printer) => ListTile(
                  leading: Icon(
                    _selected == printer
                        ? Icons.radio_button_checked
                        : Icons.print,
                    color: const Color(0xFF26A69A),
                  ),
                  title: Text(printer.name),
                  subtitle: Text(printer.address),
                  onTap: _busy ? null : () => _print(printer),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('ATUALIZAR'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('CANCELAR'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
