import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/romaneio.dart';
import '../models/master_data.dart';

class StoredRomaneios {
  const StoredRomaneios({required this.abertos, required this.fechados});

  final List<Romaneio> abertos;
  final List<Romaneio> fechados;
}

class RomaneioStorage {
  static const _stateKey = 'romaneio_flutter_state';
  static const _romaneadorKey = 'romaneio_selected_romaneador';
  static const _masterKey = 'romaneio_master_data';
  static const _templatePathKey = 'romaneio_template_path';
  static const _masterFileNameKey = 'romaneio_master_file_name';

  Future<String?> loadMasterFileName() async =>
      (await SharedPreferences.getInstance()).getString(_masterFileNameKey);

  Future<void> saveMasterFileName(String name) async {
    await (await SharedPreferences.getInstance()).setString(
      _masterFileNameKey,
      name,
    );
  }

  Future<String?> loadTemplatePath() async =>
      (await SharedPreferences.getInstance()).getString(_templatePathKey);

  Future<void> saveTemplatePath(String path) async {
    await (await SharedPreferences.getInstance()).setString(
      _templatePathKey,
      path,
    );
  }

  Future<MasterData?> loadMasterData() async {
    final raw = (await SharedPreferences.getInstance()).getString(_masterKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return MasterData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMasterData(MasterData master) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _masterKey,
      jsonEncode(master.toJson()),
    );
    if (!saved) throw StateError('Não foi possível salvar o arquivo mestre.');
  }

  Future<String?> loadSelectedRomaneador() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_romaneadorKey);
  }

  Future<StoredRomaneios?> loadRomaneios() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final abertos = (decoded['abertos'] as List? ?? const [])
        .map((item) => Romaneio.fromJson(item as Map<String, dynamic>))
        .toList();
    final fechados = (decoded['fechados'] as List? ?? const [])
        .map((item) => Romaneio.fromJson(item as Map<String, dynamic>))
        .toList();
    if (_migrateNumbers(abertos, fechados)) {
      await _savePayload(prefs, abertos: abertos, fechados: fechados);
    }
    return StoredRomaneios(abertos: abertos, fechados: fechados);
  }

  bool _migrateNumbers(List<Romaneio> abertos, List<Romaneio> fechados) {
    final legacy = fechados.where((item) => item.numeroRomaneio <= 0).toList()
      ..sort((a, b) => _completion(a).compareTo(_completion(b)));
    final existing = <int>{
      for (final item in [...abertos, ...fechados])
        if (item.numeroRomaneio > 0) item.numeroRomaneio,
    };
    var next = existing.isEmpty
        ? 1
        : existing.reduce((a, b) => a > b ? a : b) + 1;
    var changed = false;
    for (final item in legacy) {
      final index = fechados.indexWhere((value) => value.id == item.id);
      if (index >= 0) {
        fechados[index] = item.copyWith(numeroRomaneio: next++);
        changed = true;
      }
    }
    for (var i = 0; i < abertos.length; i++) {
      if (abertos[i].numeroRomaneio <= 0) {
        abertos[i] = abertos[i].copyWith(numeroRomaneio: next++);
        changed = true;
      }
    }
    return changed;
  }

  DateTime _completion(Romaneio item) {
    if (item.finalizadoEm != null) return item.finalizadoEm!;
    return DateTime.tryParse('${item.data}T${item.hora}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> saveRomaneios({
    required List<Romaneio> abertos,
    required List<Romaneio> fechados,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _savePayload(prefs, abertos: abertos, fechados: fechados);
  }

  Future<void> _savePayload(
    SharedPreferences prefs, {
    required List<Romaneio> abertos,
    required List<Romaneio> fechados,
  }) async {
    final payload = {
      'abertos': abertos.map((item) => item.toJson()).toList(),
      'fechados': fechados.map((item) => item.toJson()).toList(),
    };
    final saved = await prefs.setString(_stateKey, jsonEncode(payload));
    if (!saved) {
      throw StateError('Não foi possível salvar os romaneios.');
    }
  }

  Future<void> saveSelectedRomaneador(String? romaneador) async {
    final prefs = await SharedPreferences.getInstance();
    if (romaneador == null || romaneador.trim().isEmpty) {
      await prefs.remove(_romaneadorKey);
      return;
    }
    await prefs.setString(_romaneadorKey, romaneador);
  }
}
