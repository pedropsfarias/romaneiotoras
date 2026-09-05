import '../models/romaneio.dart';

class BalanceamentoRow {
  const BalanceamentoRow({
    required this.empreiteiro,
    required this.quantidade,
    required this.volume,
    required this.informado,
  });
  final String empreiteiro;
  final int quantidade;
  final double volume;
  final bool informado;
}

class BalanceamentoValidation {
  const BalanceamentoValidation({this.message});
  final String? message;
  bool get isValid => message == null;
}

class BalanceamentoService {
  const BalanceamentoService();

  int totalToras(Romaneio r) =>
      r.toras.fold(0, (sum, tora) => sum + tora.quantidade);
  double totalVolume(Romaneio r) =>
      r.toras.fold(0.0, (sum, tora) => sum + r.volumeDaTora(tora));

  List<BalanceamentoRow> rows(Romaneio r) {
    if (r.tipoBalanceamento == TipoBalanceamento.metroCubico) {
      final volumes = Map<String, double>.from(r.balanceamentoVolume);
      final missing = r.empreiteiros
          .where((name) => !volumes.containsKey(name))
          .toList();
      if (missing.length == 1) {
        final totalMil = (totalVolume(r) * 1000).round();
        final informadoMil = volumes.values.fold<int>(
          0,
          (sum, value) => sum + (value * 1000).round(),
        );
        final restanteMil = totalMil - informadoMil;
        if (restanteMil > 0) {
          volumes[missing.single] = restanteMil / 1000;
        }
      }
      return [
        for (final name in r.empreiteiros)
          BalanceamentoRow(
            empreiteiro: name,
            quantidade: 0,
            volume: volumes[name] ?? 0,
            informado: volumes.containsKey(name),
          ),
      ];
    }
    final total = totalToras(r);
    final volume = totalVolume(r);
    final quantities = Map<String, int>.from(r.balanceamentoToras);
    final missing = r.empreiteiros
        .where((name) => !quantities.containsKey(name))
        .toList();
    if (missing.length == 1) {
      final restante =
          total - quantities.values.fold<int>(0, (sum, value) => sum + value);
      if (restante > 0) {
        quantities[missing.single] = restante;
      }
    }
    final average = total == 0 ? 0.0 : volume / total;
    final complete =
        r.empreiteiros.isNotEmpty &&
        r.empreiteiros.every((name) => quantities.containsKey(name));
    final last = complete
        ? r.empreiteiros.lastIndexWhere((name) => quantities.containsKey(name))
        : -1;
    var previousVolume = 0.0;
    return [
      for (var i = 0; i < r.empreiteiros.length; i++)
        () {
          final name = r.empreiteiros[i];
          final quantity = quantities[name];
          final calculated = quantity == null ? 0.0 : quantity * average;
          final rowVolume = i == last ? volume - previousVolume : calculated;
          if (quantity != null && i != last) previousVolume += calculated;
          return BalanceamentoRow(
            empreiteiro: name,
            quantidade: quantity ?? 0,
            volume: quantity == null ? 0 : rowVolume,
            informado: quantity != null,
          );
        }(),
    ];
  }

  Map<String, double> derivedVolumes(Romaneio r) => {
    for (final row in rows(r))
      if (row.informado) row.empreiteiro: row.volume,
  };

  BalanceamentoValidation validate(Romaneio r) {
    if (r.empreiteiros.isEmpty)
      return const BalanceamentoValidation(
        message: 'Informe ao menos um empreiteiro.',
      );
    final current = rows(r);
    if (r.tipoBalanceamento == TipoBalanceamento.metroCubico) {
      final informadoMil = r.balanceamentoVolume.values.fold<int>(
        0,
        (sum, value) => sum + (value * 1000).round(),
      );
      final totalMil = (totalVolume(r) * 1000).round();
      if (informadoMil > totalMil) {
        final amount = ((informadoMil - totalMil) / 1000).toStringAsFixed(3);
        return BalanceamentoValidation(
          message: 'O volume distribuído ultrapassa o total em $amount m³.',
        );
      }
      if (current.any((row) => !row.informado)) {
        return const BalanceamentoValidation(
          message: 'Informe o volume de todos os empreiteiros.',
        );
      }
      if (current.any((row) => row.volume <= 0 || !row.volume.isFinite)) {
        return const BalanceamentoValidation(
          message: 'O volume informado deve ser maior que zero.',
        );
      }
      final distributed = current.fold<int>(
        0,
        (sum, row) => sum + (row.volume * 1000).round(),
      );
      final total = (totalVolume(r) * 1000).round();
      final difference = distributed - total;
      if (difference == 0) return const BalanceamentoValidation();
      final amount = (difference.abs() / 1000).toStringAsFixed(3);
      return BalanceamentoValidation(
        message: difference > 0
            ? 'O volume distribuído ultrapassa o total em $amount m³.'
            : 'Ainda faltam $amount m³ para distribuir.',
      );
    }
    final rawQuantityTotal = r.balanceamentoToras.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (rawQuantityTotal > totalToras(r)) {
      return BalanceamentoValidation(
        message:
            'A quantidade informada excede o total em ${rawQuantityTotal - totalToras(r)} toras.',
      );
    }
    if (current.any((row) => !row.informado))
      return const BalanceamentoValidation(
        message: 'Informe a quantidade de todos os empreiteiros.',
      );
    if (current.any((row) => row.quantidade < 0))
      return const BalanceamentoValidation(
        message: 'A quantidade não pode ser negativa.',
      );
    final difference =
        current.fold(0, (sum, row) => sum + row.quantidade) - totalToras(r);
    if (difference == 0) return const BalanceamentoValidation();
    return BalanceamentoValidation(
      message: difference > 0
          ? 'A quantidade informada excede o total em $difference toras.'
          : 'Ainda faltam ${difference.abs()} toras para distribuir.',
    );
  }

  Romaneio assignSingle(Romaneio r) {
    if (r.empreiteiros.length != 1) return r;
    final name = r.empreiteiros.single;
    final result = r.copyWith(
      tipoBalanceamento: TipoBalanceamento.numeroDeToras,
      balanceamentoToras: {name: totalToras(r)},
    );
    return result.copyWith(balanceamentoVolume: derivedVolumes(result));
  }
}
