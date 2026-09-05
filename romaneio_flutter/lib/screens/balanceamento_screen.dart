part of '../main.dart';

class BalanceamentoScreen extends StatefulWidget {
  const BalanceamentoScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.onChanged,
    this.onPersist,
  });
  final Romaneio romaneio;
  final VoidCallback onNext, onBack;
  final ValueChanged<Romaneio> onChanged;
  final VoidCallback? onPersist;
  @override
  State<BalanceamentoScreen> createState() => _BalanceamentoScreenState();
}

class _BalanceamentoScreenState extends State<BalanceamentoScreen> {
  static const _service = BalanceamentoService();
  final _scroll = ScrollController();
  String? _message;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _set(Romaneio value) {
    widget.onChanged(value);
    widget.onPersist?.call();
    setState(() => _message = null);
  }

  bool get _byVolume =>
      widget.romaneio.tipoBalanceamento == TipoBalanceamento.metroCubico;

  String _typeLabel(TipoBalanceamento type) =>
      type == TipoBalanceamento.metroCubico
      ? 'Por metro cúbico'
      : 'Por número de toras';

  Future<void> _changeType(TipoBalanceamento? type) async {
    if (type == null || type == widget.romaneio.tipoBalanceamento) return;
    final hasValues =
        widget.romaneio.balanceamentoToras.isNotEmpty ||
        widget.romaneio.balanceamentoVolume.isNotEmpty;
    if (hasValues) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text(
            'Alterar o tipo de balanceamento limpará a distribuição atual. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONTINUAR'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _set(
      widget.romaneio.copyWith(
        tipoBalanceamento: type,
        balanceamentoToras: const {},
        balanceamentoVolume: const {},
      ),
    );
  }

  Future<void> _edit(String name) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BalanceValueDialog(
        initial: widget.romaneio.balanceamentoToras[name]?.toString(),
      ),
    );
    if (result == null || !mounted) return;
    final value = int.tryParse(result.trim());
    if (value == null || value < 0) return;
    final other = widget.romaneio.balanceamentoToras.entries
        .where((entry) => entry.key != name)
        .fold(0, (sum, entry) => sum + entry.value);
    if (value > _service.totalToras(widget.romaneio) - other) {
      setState(
        () => _message =
            'A quantidade informada excede o que ainda falta distribuir.',
      );
      return;
    }
    final quantities = Map<String, int>.from(widget.romaneio.balanceamentoToras)
      ..[name] = value;
    final updated = widget.romaneio.copyWith(
      tipoBalanceamento: TipoBalanceamento.numeroDeToras,
      balanceamentoToras: quantities,
    );
    _set(
      updated.copyWith(balanceamentoVolume: _service.derivedVolumes(updated)),
    );
  }

  Future<void> _clear() async {
    final hasValues = _byVolume
        ? widget.romaneio.balanceamentoVolume.isNotEmpty
        : widget.romaneio.balanceamentoToras.isNotEmpty;
    if (hasValues) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Limpar balanceamento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Limpar'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    _set(
      widget.romaneio.copyWith(
        balanceamentoToras: const {},
        balanceamentoVolume: const {},
      ),
    );
  }

  void _advance() {
    final validation = _service.validate(widget.romaneio);
    if (!validation.isValid) {
      setState(() => _message = validation.message);
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _service.rows(widget.romaneio);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: dadosGeraisBackground,
            child: Column(
              children: [
                Container(
                  height: 48,
                  color: const Color(0xFF004D40),
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onBack,
                      ),
                      const Text(
                        'Balanceamento',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(15, 16, 15, 225),
                        children: [
                          const Text(
                            'Tipo de Balanceamento',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<TipoBalanceamento>(
                            key: const ValueKey('balanceamento-type-dropdown'),
                            initialValue: widget.romaneio.tipoBalanceamento,
                            decoration: InputDecoration(isDense: true),
                            items: [
                              for (final type in TipoBalanceamento.values)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(_typeLabel(type)),
                                ),
                            ],
                            onChanged: _changeType,
                          ),
                          const SizedBox(height: 22),
                          _rowContainer(const [
                            Text('Empreiteiro'),
                            Text('Quantidade\n(toras)'),
                            Text('Volume\n(m³)'),
                          ], header: true),
                          for (var i = 0; i < rows.length; i++)
                            _dataRow(rows[i], i.isEven),
                          if (_message != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                _message!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton(
                                onPressed: _clear,
                                child: const Text(
                                  'LIMPAR',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Toras: ${_service.totalToras(widget.romaneio)}',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Volume: ${_service.totalVolume(widget.romaneio).toStringAsFixed(3)} m³',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 220,
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/images/floresta_rodape_transparente.png',
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 190,
                        child: ElevatedButton.icon(
                          key: const ValueKey('balanceamento-next-button'),
                          onPressed: _advance,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('AVANÇAR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF26A69A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(105, 38),
                            elevation: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataRow(BalanceamentoRow row, bool stripe) => _rowContainer([
    Text(row.empreiteiro, maxLines: 2, overflow: TextOverflow.ellipsis),
    _byVolume ? const Center(child: Text('-')) : _quantityCell(row),
    _byVolume ? _volumeCell(row) : _calculatedVolumeCell(row),
  ], stripe: stripe);

  Widget _calculatedVolumeCell(BalanceamentoRow row) => Center(
    child: Text(
      row.informado ? row.volume.toStringAsFixed(3) : '-',
      style: const TextStyle(fontSize: 14),
    ),
  );

  Widget _quantityCell(BalanceamentoRow row) => InkWell(
    onTap: () => _edit(row.empreiteiro),
    child: Center(
      child: row.informado
          ? Text('${row.quantidade}', style: const TextStyle(fontSize: 14))
          : Container(
              height: 42,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE2E2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Preencher',
                style: TextStyle(
                  color: Color(0xFF7A3030),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
    ),
  );

  Widget _volumeCell(BalanceamentoRow row) => InkWell(
    key: ValueKey('balanceamento-volume-${row.empreiteiro}'),
    onTap: () => _editVolume(row.empreiteiro),
    child: Center(
      child: row.informado
          ? Text(row.volume.toStringAsFixed(3))
          : _fillPlaceholder(),
    ),
  );

  Widget _fillPlaceholder() => Container(
    height: 42,
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFFDE2E2),
      border: Border.all(color: const Color(0xFFE57373)),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Text(
      'Preencher',
      style: TextStyle(
        color: Color(0xFF7A3030),
        decoration: TextDecoration.underline,
      ),
    ),
  );

  Future<void> _editVolume(String name) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BalanceValueDialog(
        title: 'Inserir volume (m³)',
        initial: widget.romaneio.balanceamentoVolume[name]?.toStringAsFixed(3),
        decimal: true,
      ),
    );
    if (result == null || !mounted) return;
    final value = double.tryParse(result.trim().replaceAll(',', '.'));
    if (value == null || value <= 0 || !value.isFinite) return;
    final volumes = Map<String, double>.from(
      widget.romaneio.balanceamentoVolume,
    )..[name] = (value * 1000).round() / 1000;
    _set(
      widget.romaneio.copyWith(
        tipoBalanceamento: TipoBalanceamento.metroCubico,
        balanceamentoVolume: volumes,
        balanceamentoToras: const {},
      ),
    );
  }

  Widget _rowContainer(
    List<Widget> cells, {
    bool header = false,
    bool stripe = false,
  }) => Container(
    constraints: BoxConstraints(minHeight: header ? 50 : 58),
    color: header
        ? const Color(0xFFE7EFED)
        : (stripe ? const Color(0xFFF7F8F8) : Colors.white),
    child: Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: const [40, 34, 26][i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: DefaultTextStyle.merge(
                textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  fontSize: header ? 13 : 14,
                  fontWeight: header ? FontWeight.bold : null,
                  height: 1.25,
                ),
                child: cells[i],
              ),
            ),
          ),
      ],
    ),
  );
}

class _BalanceValueDialog extends StatefulWidget {
  const _BalanceValueDialog({this.initial, this.title, this.decimal = false});
  final String? initial;
  final String? title;
  final bool decimal;
  @override
  State<_BalanceValueDialog> createState() => _BalanceValueDialogState();
}

class _BalanceValueDialogState extends State<_BalanceValueDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? 'Inserir quantidade de toras',
            style: TextStyle(fontSize: 17, color: Colors.black),
          ),
          TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimal,
            ),
            inputFormatters: widget.decimal
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))]
                : [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                onPressed: _controller.clear,
                icon: const Icon(Icons.close, color: Colors.black),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: _submit, child: const Text('OK')),
          ),
        ],
      ),
    ),
  );
  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      Navigator.pop(context, _controller.text.trim());
    }
  }
}
