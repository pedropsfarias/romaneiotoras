part of '../main.dart';

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final saved = value.toString().trim();
    final unique = <String>[];
    final seen = <String>{};
    for (final item in items) {
      if (seen.add(item.toLowerCase())) unique.add(item);
    }
    final historical = saved.isNotEmpty && !unique.contains(saved);
    if (historical) unique.insert(0, saved);
    final String? selected = saved.isNotEmpty && unique.contains(saved)
        ? saved
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        hint: Text(
          unique.isEmpty ? 'Importe um arquivo mestre válido' : 'Selecione',
        ),
        items: unique
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  historical && item == saved
                      ? '$item (fora do mestre atual)'
                      : item,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        readOnly: true,
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
