part of '../main.dart';

class FinalizadosScreen extends StatefulWidget {
  const FinalizadosScreen({
    super.key,
    required this.finalizados,
    required this.onBack,
    required this.onOpen,
  });

  final List<Romaneio> finalizados;
  final VoidCallback onBack;
  final ValueChanged<Romaneio> onOpen;

  @override
  State<FinalizadosScreen> createState() => _FinalizadosScreenState();
}

class _FinalizadosScreenState extends State<FinalizadosScreen> {
  List<Romaneio> get _sorted {
    final result = List<Romaneio>.of(widget.finalizados);
    result.sort((a, b) {
      final byDate = _completion(b).compareTo(_completion(a));
      if (byDate != 0) return byDate;
      return (b.idInterno.isEmpty ? b.id : b.idInterno).compareTo(
        a.idInterno.isEmpty ? a.id : a.idInterno,
      );
    });
    return result;
  }

  String _number(Romaneio item) =>
      item.numeroRomaneio > 0 ? '${item.numeroRomaneio}' : '-';

  String _date(Romaneio item) {
    final value = _completion(item);
    if (value.millisecondsSinceEpoch == 0) return '-';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year.toString().padLeft(4, '0')}';
  }

  DateTime _completion(Romaneio item) {
    if (item.finalizadoEm != null) return item.finalizadoEm!;
    final date = DateTime.tryParse('${item.data}T${item.hora}');
    return date ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _volume(Romaneio item) =>
      (item.summary()['volToras'] as double).toStringAsFixed(3);

  String _balance(Romaneio item, int quantity) =>
      item.tipoBalanceamento == TipoBalanceamento.metroCubico
      ? '${_volume(item)} m${String.fromCharCode(0xB3)}'
      : '$quantity ${quantity == 1 ? 'tora' : 'toras'}';

  @override
  Widget build(BuildContext context) {
    final items = _sorted;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text('Romaneios Finalizados'),
        backgroundColor: const Color(0xFF0B5D4C),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: .22,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/images/floresta_rodape_transparente.png',
                    key: const ValueKey('finalizados-forest-background'),
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            const Center(child: Text('Nenhum romaneio finalizado.'))
          else
            ListView.separated(
              key: const ValueKey('finalizados-list'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final summary = item.summary();
                final quantity = summary['numToras'] as int;
                return Material(
                  color: Colors.white.withValues(alpha: .94),
                  child: InkWell(
                    key: ValueKey('finalizados-item-${item.id}'),
                    onTap: () => widget.onOpen(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_number(item)} - ${item.comprador}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _date(item) +
                                      ' - ' +
                                      _balance(item, quantity),
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                                /* Text(
                                  '${_date(item)} - ${_volume(item)} m³ - '
                                  '$quantity ${quantity == 1 ? 'tora' : 'toras'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 14,
                                  ),
                                ), */
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
