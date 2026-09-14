import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/user_settings.dart';
import '../models/workout_step.dart';
import 'coach_phrases.dart';

/// Priorita' dei messaggi vocali.
///
/// I messaggi ad alta priorita' (countdown, cambio fase) non vengono scartati;
/// quelli informativi possono essere saltati se la coda e' gia' piena.
enum SpeechPriority { high, normal, low }

/// Coach vocale basato su Text To Speech.
///
/// Gestisce:
///  - una coda interna, per non sovrapporre le frasi;
///  - un cooldown sugli avvisi di ritmo, per non ripeterli di continuo;
///  - le impostazioni utente (audio on/off, volume, personalita').
class AudioCoachService {
  AudioCoachService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final Queue<String> _queue = Queue<String>();

  bool _initialized = false;
  bool _speaking = false;
  bool _disposed = false;

  bool _enabled = true;
  double _volume = 1.0;
  double _speechRate = 0.5;

  CoachPhrases _phrases = CoachPhrases(CoachPersonality.normal);

  /// Ultimo stato di ritmo annunciato e quando.
  PaceStatus _lastPaceStatus = PaceStatus.unknown;
  DateTime? _lastPaceAlertAt;
  int _paceCooldownSeconds = 20;

  CoachPhrases get phrases => _phrases;
  bool get isEnabled => _enabled;

  /// Inizializza il motore TTS. Sicuro da chiamare piu' volte.
  Future<void> init() async {
    if (_initialized || _disposed) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('it-IT');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (error) {
      // Se il TTS non e' disponibile sul dispositivo l'app continua a
      // funzionare, semplicemente senza voce.
      debugPrint('AudioCoachService: TTS non disponibile ($error)');
      _initialized = false;
    }
  }

  /// Applica le impostazioni utente correnti.
  Future<void> applySettings(UserSettings settings) async {
    _enabled = settings.audioCoachEnabled;
    _volume = settings.coachVolume.clamp(0.0, 1.0).toDouble();
    _speechRate = settings.speechRate.clamp(0.1, 1.0).toDouble();
    _paceCooldownSeconds = settings.paceAlertCooldownSeconds;
    if (_phrases.personality != settings.coachPersonality) {
      _phrases = CoachPhrases(settings.coachPersonality);
    }
    if (!_enabled) {
      await stop();
      return;
    }
    if (!_initialized) {
      await init();
    }
    try {
      await _tts.setVolume(_volume);
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {
      // Ignorato: alcune implementazioni TTS non supportano tutti i setter.
    }
  }

  /// Mette una frase in coda.
  Future<void> speak(String text, {SpeechPriority priority = SpeechPriority.normal}) async {
    if (_disposed || !_enabled) return;
    final String message = text.trim();
    if (message.isEmpty) return;

    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    // Con la coda troppo lunga i messaggi poco importanti vengono scartati:
    // durante la corsa e' meglio saltare un annuncio che sentirlo in ritardo.
    if (_queue.length >= 4 && priority != SpeechPriority.high) return;
    if (_queue.length >= 8) {
      if (priority == SpeechPriority.high) {
        _queue.clear();
      } else {
        return;
      }
    }

    _queue.add(message);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_speaking) return;
    _speaking = true;
    try {
      while (_queue.isNotEmpty && !_disposed && _enabled) {
        final String next = _queue.removeFirst();
        try {
          await _tts.speak(next);
        } catch (error) {
          debugPrint('AudioCoachService: errore speak ($error)');
        }
      }
    } finally {
      _speaking = false;
    }
  }

  /// Interrompe la riproduzione e svuota la coda.
  Future<void> stop() async {
    _queue.clear();
    try {
      await _tts.stop();
    } catch (_) {
      // Ignorato.
    }
  }

  /// Azzera lo stato degli avvisi di ritmo (inizio attivita' o cambio fase).
  void resetPaceAlerts() {
    _lastPaceStatus = PaceStatus.unknown;
    _lastPaceAlertAt = null;
  }

  /// Valuta il ritmo e, se serve, pronuncia un avviso.
  ///
  /// Il cooldown evita che il messaggio venga ripetuto in continuazione: un
  /// avviso al massimo ogni [UserSettings.paceAlertCooldownSeconds] secondi.
  Future<void> announcePaceStatus(PaceStatus status, {DateTime? now}) async {
    if (!_enabled || status == PaceStatus.unknown) return;

    final DateTime moment = now ?? DateTime.now();
    final DateTime? last = _lastPaceAlertAt;
    final bool changed = status != _lastPaceStatus;
    final bool cooldownElapsed = last == null ||
        moment.difference(last).inSeconds >= _paceCooldownSeconds;

    // Si parla solo se lo stato e' cambiato E il cooldown e' scaduto.
    if (!changed || !cooldownElapsed) {
      if (changed) _lastPaceStatus = status;
      return;
    }

    _lastPaceStatus = status;
    _lastPaceAlertAt = moment;

    switch (status) {
      case PaceStatus.tooSlow:
        await speak(_phrases.tooSlow());
        break;
      case PaceStatus.tooFast:
        await speak(_phrases.tooFast());
        break;
      case PaceStatus.onTarget:
        await speak(_phrases.backOnTarget());
        break;
      case PaceStatus.unknown:
        break;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }
}
