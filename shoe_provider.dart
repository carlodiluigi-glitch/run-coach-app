import 'package:flutter/foundation.dart';

import '../models/running_shoe.dart';
import '../services/storage_service.dart';

/// Stato delle scarpe da running.
class ShoeProvider extends ChangeNotifier {
  ShoeProvider({required StorageService storage}) : _storage = storage;

  final StorageService _storage;

  List<RunningShoe> _shoes = <RunningShoe>[];
  bool _loaded = false;
  String? _errorMessage;

  List<RunningShoe> get shoes => List<RunningShoe>.unmodifiable(_shoes);

  /// Scarpe selezionabili a fine attivita' (esclude quelle a riposo).
  List<RunningShoe> get activeShoes =>
      _shoes.where((RunningShoe s) => !s.retired).toList();

  bool get isLoaded => _loaded;
  bool get isEmpty => _shoes.isEmpty;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _shoes = await _storage.loadShoes();
    _sort();
    _loaded = true;
    _errorMessage = _storage.lastError;
    notifyListeners();
  }

  RunningShoe? byId(String? id) {
    if (id == null) return null;
    for (final RunningShoe shoe in _shoes) {
      if (shoe.id == id) return shoe;
    }
    return null;
  }

  Future<void> add(RunningShoe shoe) async {
    _shoes = <RunningShoe>[..._shoes, shoe];
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> update(RunningShoe shoe) async {
    _shoes = _shoes
        .map((RunningShoe s) => s.id == shoe.id ? shoe : s)
        .toList();
    _sort();
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _shoes = _shoes.where((RunningShoe s) => s.id != id).toList();
    notifyListeners();
    await _persist();
  }

  /// Aggiunge i metri di una attivita' alla scarpa indicata.
  Future<void> addActivityDistance({
    required String shoeId,
    required double meters,
    required DateTime when,
  }) async {
    final RunningShoe? shoe = byId(shoeId);
    if (shoe == null) return;
    await update(shoe.withActivityAdded(meters, when));
  }

  /// Toglie i metri di una attivita' eliminata dalla scarpa indicata.
  Future<void> removeActivityDistance({
    required String shoeId,
    required double meters,
  }) async {
    final RunningShoe? shoe = byId(shoeId);
    if (shoe == null) return;
    await update(shoe.withActivityRemoved(meters));
  }

  void _sort() {
    _shoes.sort((RunningShoe a, RunningShoe b) {
      if (a.retired != b.retired) return a.retired ? 1 : -1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  }

  Future<void> _persist() async {
    final bool ok = await _storage.saveShoes(_shoes);
    if (!ok) {
      _errorMessage = _storage.lastError;
      notifyListeners();
    }
  }
}
