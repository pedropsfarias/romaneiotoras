part of '../main.dart';

const dadosGeraisBackground = Color(0xFFF7FBFA);

class DadosGeraisScreen extends StatefulWidget {
  const DadosGeraisScreen({
    super.key,
    required this.romaneio,
    required this.onNext,
    required this.onBack,
    required this.compradores,
    required this.empreiteiros,
    required this.proprietarios,
    required this.municipios,
    required this.localidades,
    required this.carregadores,
    required this.medidores,
    required this.motoristas,
    required this.operadores,
    required this.placas,
    required this.onChanged,
    this.onAddCadastro,
  });
  final Romaneio romaneio;
  final VoidCallback onNext, onBack;
  final ValueChanged<Romaneio> onChanged;
  final Future<void> Function(String category, String value)? onAddCadastro;
  final List<String> compradores,
      empreiteiros,
      proprietarios,
      municipios,
      localidades,
      carregadores,
      medidores,
      motoristas,
      operadores,
      placas;
  @override
  State<DadosGeraisScreen> createState() => _DadosGeraisScreenState();
}

class _MultiCadastroField extends StatefulWidget {
  const _MultiCadastroField({
    required this.label,
    required this.selected,
    required this.source,
    required this.normalize,
    required this.onChanged,
    this.onAdd,
  });

  final String label;
  final List<String> selected;
  final List<String> source;
  final String Function(String) normalize;
  final ValueChanged<List<String>> onChanged;
  final Future<void> Function(String category, String value)? onAdd;

  @override
  State<_MultiCadastroField> createState() => _MultiCadastroFieldState();
}

class _MultiCadastroFieldState extends State<_MultiCadastroField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final List<String> _catalog;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _catalog = [...widget.source];
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _clean(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _add(String value) {
    final clean = _clean(value);
    if (clean.isEmpty) return;
    final key = widget.normalize(clean);
    final match = _catalog.where((item) => widget.normalize(item) == key);
    final canonical = match.isEmpty ? clean : match.first;
    if (match.isEmpty) {
      _catalog.add(clean);
      widget.onAdd?.call(widget.label, clean);
    }
    final values = [...widget.selected];
    if (!values.any((item) => widget.normalize(item) == key)) {
      values.add(canonical);
      widget.onChanged(values);
    }
    _controller.clear();
    _focusNode.requestFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final query = widget.normalize(value.text);
        final matches = _catalog
            .where(
              (item) => query.isEmpty || widget.normalize(item).contains(query),
            )
            .toList();
        final clean = _clean(value.text);
        final exists = _catalog.any(
          (item) => widget.normalize(item) == widget.normalize(clean),
        );
        if (clean.isNotEmpty && !exists) matches.add(clean);
        return matches;
      },
      onSelected: _add,
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 600),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                final isNew = !_catalog.any(
                  (item) => widget.normalize(item) == widget.normalize(option),
                );
                return ListTile(
                  dense: true,
                  title: Text(isNew ? 'Adicionar “$option”' : option),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ),
      ),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: _add,
                decoration: InputDecoration(
                  hintText: 'Digite ou selecione',
                  border: const UnderlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Limpar campo',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.clear();
                      focusNode.requestFocus();
                    },
                  ),
                ),
              ),
              if (widget.selected.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in widget.selected)
                      InputChip(
                        label: Text(item),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => widget.onChanged(
                          widget.selected
                              .where((value) => value != item)
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
    ),
  );
}

class _DadosGeraisScreenState extends State<DadosGeraisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final TextEditingController _obs;
  final Map<String, List<String>> _catalogs = <String, List<String>>{};
  @override
  void initState() {
    super.initState();
    _obs = TextEditingController(text: widget.romaneio.observacoes);
  }

  @override
  void dispose() {
    _obs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> _items(List<String> source, String current) => {
    ...source,
    if (current.isNotEmpty) current,
  }.where((e) => e.trim().isNotEmpty).toList();
  void _set(Romaneio value) => widget.onChanged(value);
  String _date(String value) {
    final d = DateTime.tryParse(value);
    return d == null
        ? value
        : d.day.toString().padLeft(2, '0') +
              '/' +
              d.month.toString().padLeft(2, '0') +
              '/' +
              d.year.toString();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(widget.romaneio.data) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null)
      _set(
        widget.romaneio.copyWith(
          data:
              d.year.toString().padLeft(4, '0') +
              '-' +
              d.month.toString().padLeft(2, '0') +
              '-' +
              d.day.toString().padLeft(2, '0'),
        ),
      );
    if (mounted) setState(() {});
  }

  Future<void> _pickTime() async {
    final p = widget.romaneio.hora.split(':');
    final initial = p.length == 2
        ? TimeOfDay(
            hour: int.tryParse(p[0]) ?? 0,
            minute: int.tryParse(p[1]) ?? 0,
          )
        : TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null)
      _set(
        widget.romaneio.copyWith(
          hora:
              t.hour.toString().padLeft(2, '0') +
              ':' +
              t.minute.toString().padLeft(2, '0'),
        ),
      );
    if (mounted) setState(() {});
  }

  Future<void> _advance() async {
    if (widget.romaneio.empreiteiros.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ao menos um empreiteiro.')),
      );
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      widget.onNext();
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencher todos os valores.',
            style: TextStyle(color: Colors.black87),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.romaneio;
    return Scaffold(
      backgroundColor: dadosGeraisBackground,
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Dados Gerais'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          children: [
            _drop(
              'Comprador',
              r.comprador,
              widget.compradores,
              (v) => _set(r.copyWith(comprador: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _multiCadastroField(
              label: 'Empreiteiro(s)',
              selected: r.empreiteiros,
              source: widget.empreiteiros,
              onChanged: (values) => _set(r.copyWith(empreiteiros: values)),
            ),
            _drop(
              'Propriet\u00e1rio',
              r.proprietario,
              widget.proprietarios,
              (v) => _set(r.copyWith(proprietario: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _multiCadastroField(
              label: 'Placa(s)',
              selected: r.placas,
              source: widget.placas,
              onChanged: (values) => _set(r.copyWith(placas: values)),
            ),
            _drop(
              'Localidade',
              r.localidade,
              widget.localidades,
              (v) => _set(r.copyWith(localidade: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _drop(
              'Munic\u00edpio',
              r.municipio,
              widget.municipios,
              (v) => _set(r.copyWith(municipio: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _dateField('Data', _date(r.data), _pickDate),
            _dateField('Hora', r.hora, _pickTime),
            _drop(
              'Operador do Munk',
              r.carregador,
              widget.carregadores,
              (v) => _set(r.copyWith(carregador: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _drop(
              'Medidor',
              r.medidor,
              widget.medidores,
              (v) => _set(r.copyWith(medidor: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _drop(
              'Motorista',
              r.motorista,
              widget.motoristas,
              (v) => _set(r.copyWith(motorista: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            _drop(
              'Munk',
              r.operador,
              widget.operadores,
              (v) => _set(r.copyWith(operador: v ?? '')),
              onAdd: widget.onAddCadastro,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Observa\u00e7\u00f5es',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  TextFormField(
                    controller: _obs,
                    maxLines: 3,
                    onChanged: (v) => _set(r.copyWith(observacoes: v)),
                    decoration: InputDecoration(
                      hintText: 'Observa\u00e7\u00f5es',
                      border: UnderlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.backspace, size: 17),
                        onPressed: () {
                          _obs.clear();
                          _set(r.copyWith(observacoes: ''));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 204,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ForestFooter(),
                  Align(
                    alignment: Alignment.topRight,
                    child: ElevatedButton.icon(
                      onPressed: _advance,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('AVAN\u00c7AR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26A69A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drop(
    String label,
    String value,
    List<String> source,
    ValueChanged<String?> onChanged, {
    Future<void> Function(String category, String value)? onAdd,
  }) {
    final catalog = _catalogs[label] ??= [...source];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: value),
        optionsBuilder: (textEditingValue) {
          final query = _normalizeCadastro(textEditingValue.text);
          if (query.isEmpty) return catalog;
          return catalog.where(
            (item) => _normalizeCadastro(item).contains(query),
          );
        },
        onSelected: (selected) => onChanged(selected),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: false,
                  enabled: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  validator: (text) => text == null || text.trim().isEmpty
                      ? 'Obrigat\u00f3rio'
                      : null,
                  onTap: () => focusNode.requestFocus(),
                  onChanged: (_) {},
                  onFieldSubmitted: (text) {
                    final normalized = text.trim().replaceAll(
                      RegExp(r'\s+'),
                      ' ',
                    );
                    if (normalized.isEmpty) return;
                    final existing = catalog
                        .where(
                          (item) =>
                              _normalizeCadastro(item) ==
                              _normalizeCadastro(normalized),
                        )
                        .toList();
                    final selected = existing.isEmpty
                        ? normalized
                        : existing.first;
                    if (existing.isEmpty) {
                      catalog.add(normalized);
                      onAdd?.call(label, normalized);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cadastro adicionado: ' + normalized),
                        ),
                      );
                    }
                    controller.value = TextEditingValue(
                      text: selected,
                      selection: TextSelection.collapsed(
                        offset: selected.length,
                      ),
                    );
                    onChanged(selected);
                    onFieldSubmitted();
                  },
                  decoration: InputDecoration(
                    hintText: 'Digite ou selecione',
                    border: const UnderlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Limpar',
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.backspace,
                        size: 17,
                        color: Colors.black87,
                      ),
                      onPressed: () {
                        controller.clear();
                        onChanged(null);
                        focusNode.requestFocus();
                      },
                    ),
                    suffixIconConstraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contractorField(Romaneio r) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: InkWell(
      onTap: () async {
        final selected = Set<String>.from(r.empreiteiros);
        await showDialog<void>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Empreiteiro(s)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final name in widget.empreiteiros)
                      CheckboxListTile(
                        value: selected.contains(name),
                        title: Text(name),
                        onChanged: (value) => setDialogState(() {
                          value == true
                              ? selected.add(name)
                              : selected.remove(name);
                        }),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    _set(r.copyWith(empreiteiros: selected.toList()));
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Empreiteiro(s)',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          r.empreiteiros.isEmpty
              ? 'Digite ou selecione'
              : r.empreiteiros.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: r.empreiteiros.isEmpty ? Colors.grey : Colors.black87,
          ),
        ),
      ),
    ),
  );

  Widget _multiCadastroField({
    required String label,
    required List<String> selected,
    required List<String> source,
    required ValueChanged<List<String>> onChanged,
  }) => _MultiCadastroField(
    label: label,
    selected: selected,
    source: source,
    normalize: _normalizeCadastro,
    onChanged: onChanged,
    onAdd: widget.onAddCadastro,
  );

  String _normalizeCadastro(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const to = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    var normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    for (var i = 0; i < from.length; i++) {
      normalized = normalized.replaceAll(
        from[i].toLowerCase(),
        to[i].toLowerCase(),
      );
    }
    return normalized;
  }

  Widget _dateField(String label, String value, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: TextFormField(
            readOnly: true,
            controller: TextEditingController(text: value),
            validator: (_) => value.trim().isEmpty ? 'Obrigat\u00f3rio' : null,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: label == 'Data' ? 'dd/MM/yyyy' : 'HH:mm',
              border: const UnderlineInputBorder(),
              suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 36,
                maxWidth: 36,
                minHeight: 36,
                maxHeight: 36,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
