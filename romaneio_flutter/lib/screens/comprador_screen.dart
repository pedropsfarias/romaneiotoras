part of '../main.dart';

class _InlineCompradorField extends StatefulWidget {
  const _InlineCompradorField({
    required this.value,
    required this.source,
    required this.onChanged,
    this.onAddCadastro,
  });
  final String value;
  final List<CompradorMaster> source;
  final ValueChanged<CompradorMaster?> onChanged;
  final Future<void> Function(String category, String value)? onAddCadastro;

  @override
  State<_InlineCompradorField> createState() => _InlineCompradorFieldState();
}

class _InlineCompradorFieldState extends State<_InlineCompradorField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _clean(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');
  void _select(CompradorMaster value) {
    if (value.chaveOrigem.startsWith('manual:')) {
      widget.onAddCadastro?.call('Comprador', value.nome);
    }
    widget.onChanged(value);
    _controller.text = value.nome;
    _controller.selection = TextSelection.collapsed(offset: value.nome.length);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<CompradorMaster>(
    textEditingController: _controller,
    focusNode: _focusNode,
    optionsBuilder: (value) {
      final query = _normalizeSearch(value.text);
      final matches = widget.source
          .where(
            (item) =>
                query.isEmpty || _normalizeSearch(item.nome).contains(query),
          )
          .toList();
      final clean = _clean(value.text);
      final exists = widget.source.any(
        (item) => _normalizeSearch(item.nome) == _normalizeSearch(clean),
      );
      if (clean.isNotEmpty && !exists) {
        matches.add(CompradorMaster(chaveOrigem: 'manual:$query', nome: clean));
      }
      return matches;
    },
    onSelected: _select,
    optionsViewBuilder: (context, onSelected, options) => Material(
      elevation: 4,
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: [
          for (final option in options)
            ListTile(
              title: Text(
                option.chaveOrigem.startsWith('manual:')
                    ? 'Adicionar “${option.nome}”'
                    : option.nome,
              ),
              onTap: () => onSelected(option),
            ),
        ],
      ),
    ),
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        TextFormField(
          key: const ValueKey('comprador-inline-field'),
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (value) {
            final clean = _clean(value);
            if (clean.isEmpty) return;
            final found = widget.source.where(
              (item) => _normalizeSearch(item.nome) == _normalizeSearch(clean),
            );
            _select(
              found.isEmpty
                  ? CompradorMaster(
                      chaveOrigem: 'manual:${_normalizeSearch(clean)}',
                      nome: clean,
                    )
                  : found.first,
            );
          },
          decoration: InputDecoration(
            hintText: 'Digite ou selecione',
            border: const UnderlineInputBorder(),
            suffixIcon: IconButton(
              key: const ValueKey('clear-comprador'),
              tooltip: 'Limpar comprador',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                controller.clear();
                widget.onChanged(null);
                focusNode.requestFocus();
              },
            ),
          ),
        ),
  );
}

class CompradorScreen extends StatefulWidget {
  const CompradorScreen({
    super.key,
    required this.romaneio,
    required this.compradores,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
    this.onAddCadastro,
    this.isLoading = false,
    this.errorMessage,
  });

  final Romaneio romaneio;
  final List<CompradorMaster> compradores;
  final ValueChanged<Romaneio> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Future<void> Function(String category, String value)? onAddCadastro;
  final bool isLoading;
  final String? errorMessage;

  @override
  State<CompradorScreen> createState() => _CompradorScreenState();
}

class _CompradorScreenState extends State<CompradorScreen> {
  CompradorMaster? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _selectionFrom(widget.romaneio);
  }

  @override
  void didUpdateWidget(covariant CompradorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected = _selectionFrom(widget.romaneio);
  }

  CompradorMaster? _selectionFrom(Romaneio romaneio) {
    if (romaneio.compradorChaveOrigem.startsWith('manual:') &&
        romaneio.comprador.trim().isNotEmpty) {
      return CompradorMaster(
        chaveOrigem: romaneio.compradorChaveOrigem,
        nome: romaneio.comprador,
      );
    }
    if (romaneio.compradorChaveOrigem.isNotEmpty) {
      return widget.compradores.cast<CompradorMaster?>().firstWhere(
        (item) => item!.chaveOrigem == romaneio.compradorChaveOrigem,
        orElse: () => null,
      );
    }
    final matching = widget.compradores
        .where((item) => item.nome == romaneio.comprador)
        .toList();
    return matching.length == 1 ? matching.single : null;
  }

  bool get _canAdvance =>
      _selected != null &&
      _selected!.nome.trim().isNotEmpty &&
      (_selected!.chaveOrigem.startsWith('manual:') ||
          widget.compradores.any(
            (item) => item.chaveOrigem == _selected!.chaveOrigem,
          ));

  void _setSelection(CompradorMaster? comprador) {
    setState(() => _selected = comprador);
    widget.onChanged(
      widget.romaneio.copyWith(
        comprador: comprador?.nome ?? '',
        compradorId: comprador?.identificador ?? '',
        compradorChaveOrigem: comprador?.chaveOrigem ?? '',
      ),
    );
  }

  Future<void> _openPicker() async {
    if (widget.isLoading || widget.errorMessage != null) return;
    final selected = await showModalBottomSheet<CompradorMaster>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompradorPicker(compradores: widget.compradores),
    );
    if (selected != null && mounted) _setSelection(selected);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSystemInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarDividerColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          leading: BackButton(onPressed: widget.onBack),
          title: const Text('Comprador'),
          backgroundColor: const Color(0xFF0B5D4C),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomSystemInset),
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const forestAspectRatio = 1774 / 887;
                final footerHeight = constraints.maxWidth / forestAspectRatio;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        footerHeight + 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Comprador',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _InlineCompradorField(
                            value: widget.romaneio.comprador,
                            source: widget.compradores,
                            onChanged: _setSelection,
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                key: const ValueKey('comprador-next-button'),
                                onPressed: _canAdvance ? widget.onNext : null,
                                iconAlignment: IconAlignment.end,
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: const Text('AVANÇAR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF26A69A),
                                  disabledBackgroundColor: const Color(
                                    0xFFD6D6D6,
                                  ),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: const Color(
                                    0xFF757575,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: SizedBox(
                          key: const ValueKey('comprador-forest-footer'),
                          height: footerHeight,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/floresta_rodape.png',
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                              const _BrandSignature(
                                widthFactor: .52,
                                showDoubleRules: true,
                                bottomOffset: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField() {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Carregando compradores...'),
          ],
        ),
      );
    }
    if (widget.errorMessage != null) {
      return Text(
        'Falha ao carregar compradores: ${widget.errorMessage}',
        style: const TextStyle(color: Colors.red),
      );
    }
    if (widget.compradores.isEmpty) {
      return const Text('Nenhum comprador disponível na base mestre.');
    }
    return InkWell(
      key: const ValueKey('comprador-field'),
      onTap: _openPicker,
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Digite ou selecione',
          hintStyle: const TextStyle(color: Color(0xFF757575)),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFBDBDBD)),
          ),
          suffixIcon: _selected == null
              ? const Icon(Icons.search, color: Color(0xFF757575))
              : IconButton(
                  key: const ValueKey('clear-comprador'),
                  tooltip: 'Limpar comprador',
                  onPressed: () => _setSelection(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        child: _selected == null
            ? null
            : Text(
                _selected!.nome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}

class _CompradorPicker extends StatefulWidget {
  const _CompradorPicker({required this.compradores});
  final List<CompradorMaster> compradores;

  @override
  State<_CompradorPicker> createState() => _CompradorPickerState();
}

class _CompradorPickerState extends State<_CompradorPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CompradorMaster> get _available {
    final seen = <String>{};
    return widget.compradores.where((item) {
      final key = _normalizeSearch(item.nome);
      return key.isNotEmpty && seen.add(key);
    }).toList();
  }

  String get _normalizedQuery => _normalizeSearch(_query);

  String get _newBuyerName => _query.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get _canAddNewBuyer =>
      _newBuyerName.isNotEmpty &&
      !_available.any(
        (item) => _normalizeSearch(item.nome) == _normalizedQuery,
      );

  List<CompradorMaster> get _filtered => _available
      .where((item) => _normalizeSearch(item.nome).contains(_normalizedQuery))
      .toList();

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSystemInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF000000),
        systemNavigationBarDividerColor: Color(0xFF000000),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomSystemInset,
            child: const ColoredBox(color: Color(0xFF000000)),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: bottomSystemInset),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: .92,
                widthFactor: 1,
                child: Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      keyboardInset + 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            key: const ValueKey('close-comprador-picker'),
                            tooltip: 'Fechar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        const Text(
                          'Comprador',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextField(
                          key: const ValueKey('comprador-search'),
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Pesquisar comprador',
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF26A69A)),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0xFF26A69A),
                                width: 2,
                              ),
                            ),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    key: const ValueKey(
                                      'clear-comprador-search',
                                    ),
                                    tooltip: 'Limpar pesquisa',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _filtered.isEmpty && !_canAddNewBuyer
                              ? const Center(
                                  child: Text('Nenhum comprador encontrado.'),
                                )
                              : ListView.separated(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount:
                                      _filtered.length +
                                      (_canAddNewBuyer ? 1 : 0),
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    color: Color(0xFFE0E0E0),
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == _filtered.length &&
                                        _canAddNewBuyer) {
                                      final nome = _newBuyerName;
                                      return ListTile(
                                        key: const ValueKey(
                                          'comprador-add-new',
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 6,
                                            ),
                                        leading: const Icon(Icons.add),
                                        title: Text('Adicionar "$nome"'),
                                        onTap: () => Navigator.pop(
                                          context,
                                          CompradorMaster(
                                            chaveOrigem:
                                                'manual:${_normalizeSearch(nome)}',
                                            nome: nome,
                                          ),
                                        ),
                                      );
                                    }
                                    final comprador = _filtered[index];
                                    return ListTile(
                                      key: ValueKey(
                                        'comprador-option-${comprador.chaveOrigem}',
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                      title: Text(comprador.nome),
                                      onTap: () =>
                                          Navigator.pop(context, comprador),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizeSearch(String value) {
  const accented = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const plain = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  final canonical = lower
      .replaceAll('\u00E1', 'a')
      .replaceAll('\u00E0', 'a')
      .replaceAll('\u00E2', 'a')
      .replaceAll('\u00E3', 'a')
      .replaceAll('\u00E9', 'e')
      .replaceAll('\u00EA', 'e')
      .replaceAll('\u00ED', 'i')
      .replaceAll('\u00F3', 'o')
      .replaceAll('\u00F4', 'o')
      .replaceAll('\u00F5', 'o')
      .replaceAll('\u00FA', 'u')
      .replaceAll('\u00FC', 'u')
      .replaceAll('\u00E7', 'c')
      .replaceAll('\u00F1', 'n');
  final buffer = StringBuffer();
  for (final rune in canonical.runes) {
    final character = String.fromCharCode(rune);
    final index = accented.indexOf(character);
    buffer.write(index < 0 ? character : plain[index]);
  }
  return buffer.toString();
}
