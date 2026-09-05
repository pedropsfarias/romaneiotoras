part of '../main.dart';

class ResumoScreen extends StatefulWidget {
  const ResumoScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.onChanged,
    required this.onPersist,
  });
  final Romaneio romaneio;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final ValueChanged<Romaneio> onChanged;
  final VoidCallback onPersist;
  @override
  State<ResumoScreen> createState() => _ResumoScreenState();
}

class _ResumoScreenState extends State<ResumoScreen> {
  List<DiameterClassSummary> get _rows {
    final result = {
      for (final key in Romaneio.priceClassKeys)
        key: DiameterClassSummary(key: key),
    };
    for (final tora in widget.romaneio.toras) {
      final key = Romaneio.priceClassForDiameter(tora.diametro);
      result[key] = result[key]!.add(
        quantity: tora.quantidade,
        volume: widget.romaneio.volumeDaTora(tora),
      );
    }
    return [for (final key in Romaneio.priceClassKeys) result[key]!];
  }

  double? _priceFor(String key) => widget.romaneio.precosPorClasse[key];

  void _onPriceConfirmed(String key, double value) {
    final prices = Map<String, double>.of(widget.romaneio.precosPorClasse)
      ..[key] = value;
    widget.onChanged(widget.romaneio.copyWith(precosPorClasse: prices));
    widget.onPersist();
    setState(() {});
  }

  Future<void> _openPriceEntry(DiameterClassSummary row) async {
    final value = await showDialog<double>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _PriceEntryDialog(
        classKey: row.key,
        volume: row.volume,
        currentPrice: _priceFor(row.key),
      ),
    );
    if (value != null && mounted) _onPriceConfirmed(row.key, value);
  }

  bool get _canAdvance {
    final usedRows = _rows.where((row) => row.quantity > 0);
    return usedRows.isNotEmpty &&
        usedRows.every((row) => (_priceFor(row.key) ?? 0) > 0);
  }

  Future<void> _advance() async {
    final optionsSelected =
        widget.romaneio.comNo ||
        widget.romaneio.doPe ||
        widget.romaneio.segundaTora;
    if (!_canAdvance || !optionsSelected) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alert'),
          content: const Text('Preencher todos os valores.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    widget.onNext();
  }

  void _onOptionChanged({required String key, required bool value}) {
    final updated = switch (key) {
      'comNo' => widget.romaneio.copyWith(comNo: value),
      'doPe' => widget.romaneio.copyWith(doPe: value),
      _ => widget.romaneio.copyWith(segundaTora: value),
    };
    widget.onChanged(updated);
    widget.onPersist();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.romaneio.summary();
    final totalToras = summary['numToras'] as int;
    final totalVolume = summary['volToras'] as double;
    final rows = _rows;
    final usedRows = rows.where((row) => row.quantity > 0);
    final allPricesPresent =
        usedRows.isNotEmpty &&
        usedRows.every((row) => (_priceFor(row.key) ?? 0) > 0);
    final totalValue = allPricesPresent
        ? usedRows.fold<double>(
            0,
            (total, row) => total + row.valueFor(_priceFor(row.key)),
          )
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Resumo e Preço'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: Colors.white,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 190),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTable(rows, totalToras, totalVolume, totalValue),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 57,
                          child: Column(
                            children: [
                              _option('Com nó', widget.romaneio.comNo, 'comNo'),
                              _option('Do pé', widget.romaneio.doPe, 'doPe'),
                              _option(
                                '2ª Tora',
                                widget.romaneio.segundaTora,
                                'segundaTora',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 43,
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Toras: ' + totalToras.toString(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  'Volume: ' +
                                      totalVolume.toStringAsFixed(3) +
                                      ' m³',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 160,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/floresta_rodape.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 174,
                child: ElevatedButton.icon(
                  key: const ValueKey('resumo-next-button'),
                  onPressed: _advance,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('AVANÇAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF26A69A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    List<DiameterClassSummary> rows,
    int totalToras,
    double totalVolume,
    double? totalValue,
  ) => Column(
    children: [
      _tableRow([
        'Classe\nDiamétrica\n(cm)',
        'Quantidade\n(toras)',
        'Volume\n(m³)',
        'Preço\nUnitário (R' + String.fromCharCode(36) + ')',
        'Valor\nTotal (R' + String.fromCharCode(36) + ')',
      ], header: true),
      ...rows.asMap().entries.map(
        (entry) => _tableRow(entry.value, stripe: entry.key.isEven),
      ),
      _tableRow([
        'TOTAL',
        '$totalToras',
        totalVolume.toStringAsFixed(3),
        '-',
        totalValue == null ? '-' : _formatMoney(totalValue),
      ], total: true),
    ],
  );

  Widget _tableRow(
    dynamic row, {
    bool header = false,
    bool stripe = false,
    bool total = false,
  }) {
    final cells = row is List<String>
        ? [
            for (var i = 0; i < row.length; i++)
              _cell(row[i], i, total, header: header),
          ]
        : [
            _cell(row.key, 0, false),
            _cell(row.quantity == 0 ? '-' : '${row.quantity}', 1, false),
            _cell(
              row.quantity == 0 ? '-' : row.volume.toStringAsFixed(3),
              2,
              false,
            ),
            _priceCell(row),
            _cell(
              row.quantity == 0
                  ? '-'
                  : (row.valueFor(_priceFor(row.key)) == 0
                        ? '-'
                        : _formatMoney(row.valueFor(_priceFor(row.key)))),
              4,
              false,
            ),
          ];
    return Container(
      color: header
          ? const Color(0xFFE7EFED)
          : (stripe ? const Color(0xFFF7F8F8) : Colors.white),
      constraints: BoxConstraints(minHeight: header ? 60 : (total ? 52 : 50)),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: const [21, 17, 16, 24, 22][i], child: cells[i]),
        ],
      ),
    );
  }

  Widget _cell(String value, int index, bool total, {bool header = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Text(
          value,
          textAlign: index == 0 ? TextAlign.left : TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: header ? 11 : 12.5,
            fontWeight: header
                ? FontWeight.w600
                : (total ? FontWeight.w700 : null),
            height: header ? 1.25 : 1.2,
          ),
        ),
      );

  Widget _priceCell(DiameterClassSummary row) {
    if (row.quantity == 0) return _cell('-', 3, false);
    final price = _priceFor(row.key);
    final content = price == null || price <= 0
        ? Container(
            width: 85,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE2E2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'Preencher',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7A3030),
                decoration: TextDecoration.underline,
              ),
            ),
          )
        : Text(
            _formatMoney(price),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          );
    return InkWell(
      key: ValueKey('resumo-price-${row.key}'),
      onTap: () => _openPriceEntry(row),
      child: SizedBox(height: 48, child: Center(child: content)),
    );
  }

  Widget _option(String label, bool value, String key) => SizedBox(
    height: 48,
    child: Material(
      type: MaterialType.transparency,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: false,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 14, height: 1.25)),
        value: value,
        onChanged: (next) => _onOptionChanged(key: key, value: next ?? false),
      ),
    ),
  );
}

class DiameterClassSummary {
  const DiameterClassSummary({
    required this.key,
    this.quantity = 0,
    this.volume = 0,
  });
  final String key;
  final int quantity;
  final double volume;
  DiameterClassSummary add({required int quantity, required double volume}) =>
      DiameterClassSummary(
        key: key,
        quantity: this.quantity + quantity,
        volume: this.volume + volume,
      );
  double valueFor(double? unitPrice) =>
      unitPrice == null ? 0 : volume * unitPrice;
}

class _PriceInputFormatter extends TextInputFormatter {
  const _PriceInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => RegExp(r'^\d*([.,]\d{0,2})?$').hasMatch(newValue.text)
      ? newValue
      : oldValue;
}

String _formatMoney(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'R' + String.fromCharCode(36) + ' ' + grouped + ',' + parts[1];
}

class _PriceEntryDialog extends StatefulWidget {
  const _PriceEntryDialog({
    required this.classKey,
    required this.volume,
    this.currentPrice,
  });
  final String classKey;
  final double volume;
  final double? currentPrice;
  @override
  State<_PriceEntryDialog> createState() => _PriceEntryDialogState();
}

class _PriceEntryDialogState extends State<_PriceEntryDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentPrice == null
          ? ''
          : _decimalInput(widget.currentPrice!),
    );
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final normalized = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (normalized.isEmpty || value == null || !value.isFinite || value <= 0) {
      setState(() => _error = 'Informe um valor maior que zero.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inserir o valor',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('price-entry-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: const [_PriceInputFormatter()],
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                hintText: 'Preço unitário por m³',
                errorText: _error,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF26A69A), width: 2),
                ),
                suffixIcon: IconButton(
                  key: const ValueKey('price-entry-clear'),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _error = null);
                  },
                  icon: Container(
                    color: Colors.black,
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                key: const ValueKey('price-entry-ok'),
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26A69A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(58, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _decimalInput(double value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
