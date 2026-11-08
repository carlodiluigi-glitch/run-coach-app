import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../services/daily_steps.dart';
import '../services/native_bridge.dart';
import '../services/storage_service.dart';
import '../utils/giorni.dart';

/// I passi della giornata: legge il contatore del telefono quando l'app si
/// apre o torna in primo piano, salva la lettura e ricalcola i giorni.
///
/// Vedi [DailySteps] per come si passa dalle letture ai giorni.
class DailyStepsProvider extends ChangeNotifier with WidgetsBindingObserver {
  DailyStepsProvider({
    required StorageService storage,
    required NativeBridge nativeBridge,
  })  : _storage = storage,
        _native = nativeBridge;

  final StorageService _storage;
  final NativeBridge _native;

  /// Quante letture tenere: abbastanza per un paio di mesi aprendo l'app
  /// anche dieci volte al giorno.
  static const int maxSamples = 600;

  /// Due letture piu' vicine di cosi' non aggiungono niente.
  static const Duration minGap = Duration(minutes: 5);

  List<StepSample> _samples = <StepSample>[];
  Map<DateTime, DaySteps> _days = <DateTime, DaySteps>{};
  bool _available = true;
  bool _reading = false;

  /// `false` se il telefono non ha il contatore o il permesso manca.
  bool get available => _available;

  Map<DateTime, DaySteps> get days => _days;

  DaySteps? stepsOn(DateTime day) => _days[soloGiorno(day)];

  /// L'ultima lettura: "aggiornato alle 18:40".
  DateTime? get lastReadingAt => _samples.isEmpty ? null : _samples.last.at;

  /// I passi giorno per giorno, come numeri: per il testo del coach.
  Map<DateTime, int> get stepsByDay => _days
      .map((DateTime k, DaySteps v) => MapEntry<DateTime, int>(k, v.steps));

  Future<void> load() async {
    final String? raw = await _storage.readExtra(StorageService.stepsFileName);
    if (raw != null) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is List) {
          _samples = decoded
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> e) =>
                  StepSample.fromJson(e.cast<String, dynamic>()))
              .whereType<StepSample>()
              .toList()
            ..sort((StepSample a, StepSample b) => a.at.compareTo(b.at));
        }
      } catch (_) {
        _samples = <StepSample>[];
      }
    }
    _days = DailySteps.perDay(_samples);
    WidgetsBinding.instance.addObserver(this);
    await refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Legge il contatore adesso. Si puo' chiamare quante volte si vuole:
  /// letture troppo vicine si sostituiscono invece di accumularsi.
  Future<void> refresh() async {
    if (_reading) return;
    _reading = true;
    try {
      final SystemStepReading? r = await _native.systemSteps();
      if (r == null) {
        _available = false;
        notifyListeners();
        return;
      }
      _available = true;
      final StepSample nuova =
          StepSample(at: DateTime.now(), steps: r.steps, bootAt: r.bootAt);
      if (_samples.isNotEmpty &&
          nuova.at.difference(_samples.last.at) < minGap &&
          _samples.length >= 2) {
        // Si tiene la piu' recente: il conto fino a qui resta giusto.
        _samples[_samples.length - 1] = nuova;
      } else {
        _samples.add(nuova);
      }
      if (_samples.length > maxSamples) {
        _samples = _samples.sublist(_samples.length - maxSamples);
      }
      _days = DailySteps.perDay(_samples);
      await _storage.writeExtra(
        StorageService.stepsFileName,
        jsonEncode(_samples.map((StepSample s) => s.toJson()).toList()),
      );
      notifyListeners();
    } finally {
      _reading = false;
    }
  }

  /// Chiede il permesso del contapassi (lo stesso della cadenza).
  Future<void> askPermission() async {
    await _native.requestStepPermission();
    await refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
