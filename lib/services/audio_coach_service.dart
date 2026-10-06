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
  String _athleteName = '';

  /// La voce e il motore chiesti dall'utente (vuoti = sceglie l'app).
  String _voceVoluta = '';
  String _motoreVoluto = '';

  /// La voce effettivamente in uso.
  String _voceAttuale = '';

  /// Quanto deve dire a ogni chilometro.
  SpokenDetail _detail = SpokenDetail.completo;

  SpokenDetail get detail => _detail;

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
      await _scegliMotore();
      await _tts.setLanguage('it-IT');
      await _scegliVoce();
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

  // =========================== LA VOCE ===========================
  //
  // PERCHE' LA VOCE SI SCEGLIE, E PERCHE' NON BASTA DIRE "ITALIANO"
  // ---------------------------------------------------------------
  // Dire al telefono solo "parla italiano" e' quello che faceva l'app prima, e
  // vuol dire prendersi la voce che capita. Un telefono Android ne ha quasi
  // sempre piu' d'una: una di base, piccola e offline, che e' quella che suona
  // meccanica, e altre migliori installabili. Su molti telefoni il motore
  // vocale predefinito non e' nemmeno quello di Google, che e' il piu'
  // naturale.
  //
  // Qui l'app guarda cosa c'e' davvero sul telefono e sceglie il meglio. Non
  // puo' fare di piu': **la voce e' del telefono, non dell'app**. Se sul
  // telefono c'e' solo una voce brutta, l'unica cosa onesta e' dirlo e
  // spiegare come installarne una buona, che e' quello che fa la schermata
  // "La voce".
  //
  // PERCHE' QUESTE CHIAMATE PASSANO DA `dynamic`
  // --------------------------------------------
  // Perche' elencare voci e motori e' la parte del pacchetto TTS che cambia
  // da una versione all'altra e da una piattaforma all'altra, ed e' una
  // funzione **accessoria**: se non risponde, la voce deve continuare a
  // funzionare con quella predefinita. Passando da `dynamic` un metodo che non
  // c'e' finisce nel `catch` qui sotto invece di spegnere il coach.

  /// I pezzi di nome che indicano una voce povera: sono i motori di ripiego
  /// che Android installa quando non c'e' nient'altro.
  static const List<String> _vociPovere = <String>['espeak', 'pico'];

  /// I pezzi di nome che indicano una voce buona.
  ///
  /// Le voci Google sono nominate `it-it-x-...`; quelle che finiscono in
  /// `-network` sono le migliori perche' vengono sintetizzate dai server, ma
  /// hanno bisogno della rete - e durante una corsa la rete puo' non esserci.
  /// Per questo una voce di rete non viene MAI scelta da sola: la puo'
  /// scegliere l'utente, che sa se corre in un posto con campo.
  static const List<String> _vociBuone = <String>['-x-', 'google'];

  Future<void> _scegliMotore() async {
    final String voluto = _motoreVoluto.trim();
    try {
      final dynamic motore = _tts;
      final dynamic elenco = await motore.getEngines;
      if (elenco is! List || elenco.isEmpty) return;
      final List<String> disponibili =
          elenco.map((dynamic e) => '$e').toList(growable: false);

      if (voluto.isNotEmpty && disponibili.contains(voluto)) {
        await motore.setEngine(voluto);
        return;
      }
      // Senza una scelta dell'utente si preferisce il motore Google, che e'
      // quello con le voci migliori e c'e' sulla maggior parte dei telefoni.
      for (final String e in disponibili) {
        if (e.contains('com.google.android.tts')) {
          await motore.setEngine(e);
          return;
        }
      }
    } catch (error) {
      debugPrint('AudioCoachService: motori non elencabili ($error)');
    }
  }

  Future<void> _scegliVoce() async {
    try {
      final List<CoachVoice> voci = await availableVoices();
      if (voci.isEmpty) return;

      final String voluta = _voceVoluta.trim();
      if (voluta.isNotEmpty) {
        for (final CoachVoice v in voci) {
          if (v.name == voluta) {
            await _applicaVoce(v);
            return;
          }
        }
      }
      await _applicaVoce(_migliore(voci));
    } catch (error) {
      debugPrint('AudioCoachService: voce non selezionabile ($error)');
    }
  }

  /// La voce italiana migliore fra quelle installate.
  ///
  /// Niente voci di rete: suonano meglio ma tacciono dove non c'e' campo, e
  /// una voce che sparisce a meta' corsa e' peggio di una voce meno bella.
  static CoachVoice _migliore(List<CoachVoice> voci) {
    CoachVoice scelta = voci.first;
    int punteggioScelta = _punteggio(scelta);
    for (final CoachVoice v in voci) {
      final int p = _punteggio(v);
      if (p > punteggioScelta) {
        scelta = v;
        punteggioScelta = p;
      }
    }
    return scelta;
  }

  static int _punteggio(CoachVoice v) {
    final String nome = v.name.toLowerCase();
    int punti = 0;
    for (final String brutto in _vociPovere) {
      if (nome.contains(brutto)) punti -= 10;
    }
    for (final String buono in _vociBuone) {
      if (nome.contains(buono)) punti += 5;
    }
    if (v.needsNetwork) punti -= 3;
    return punti;
  }

  Future<void> _applicaVoce(CoachVoice voce) async {
    final dynamic motore = _tts;
    await motore.setVoice(<String, String>{
      'name': voce.name,
      'locale': voce.locale,
    });
    _voceAttuale = voce.name;
  }

  /// Le voci italiane installate sul telefono.
  ///
  /// Lista vuota quando non si possono elencare: in quel caso resta la voce
  /// predefinita e la schermata "La voce" lo dice, invece di mostrare un
  /// elenco vuoto senza spiegazione.
  Future<List<CoachVoice>> availableVoices() async {
    try {
      final dynamic motore = _tts;
      final dynamic elenco = await motore.getVoices;
      if (elenco is! List) return const <CoachVoice>[];

      final List<CoachVoice> out = <CoachVoice>[];
      for (final dynamic riga in elenco) {
        if (riga is! Map) continue;
        final String nome = '${riga['name'] ?? ''}';
        final String lingua = '${riga['locale'] ?? ''}';
        if (nome.isEmpty) continue;
        if (!lingua.toLowerCase().startsWith('it')) continue;
        out.add(CoachVoice(
          name: nome,
          locale: lingua,
          needsNetwork: nome.toLowerCase().contains('network'),
        ));
      }
      out.sort((CoachVoice a, CoachVoice b) =>
          _punteggio(b).compareTo(_punteggio(a)));
      return out;
    } catch (error) {
      debugPrint('AudioCoachService: voci non elencabili ($error)');
      return const <CoachVoice>[];
    }
  }

  /// Il nome della voce in uso, vuoto se e' quella predefinita.
  String get currentVoice => _voceAttuale;

  /// Prova una voce **senza salvarla**: serve a sentirla prima di sceglierla.
  Future<void> previewVoice(CoachVoice voce, String frase) async {
    if (_disposed) return;
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      await stop();
      await _applicaVoce(voce);
      await _tts.speak(frase);
    } catch (error) {
      debugPrint('AudioCoachService: prova voce fallita ($error)');
    }
  }

  /// Applica le impostazioni utente correnti.
  Future<void> applySettings(UserSettings settings) async {
    _enabled = settings.audioCoachEnabled;
    _detail = settings.spokenDetail;

    // Se la voce o il motore sono cambiati si riapplicano: sono le uniche due
    // impostazioni che non bastano a scriverle, vanno ridette al sistema.
    final bool voceCambiata = _voceVoluta != settings.ttsVoice ||
        _motoreVoluto != settings.ttsEngine;
    _voceVoluta = settings.ttsVoice;
    _motoreVoluto = settings.ttsEngine;
    _volume = settings.coachVolume.clamp(0.0, 1.0).toDouble();
    _speechRate = settings.speechRate.clamp(0.1, 1.0).toDouble();
    _paceCooldownSeconds = settings.paceAlertCooldownSeconds;
    // Si ricostruisce anche quando cambia il nome: le frasi di partenza se
    // lo portano dentro, e restare con quello vecchio vorrebbe dire salutare
    // la persona sbagliata.
    if (_phrases.personality != settings.coachPersonality ||
        _athleteName != settings.userName) {
      _athleteName = settings.userName;
      _phrases = CoachPhrases(
        settings.coachPersonality,
        athleteName: settings.userName,
      );
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
      if (voceCambiata) {
        await _scegliMotore();
        await _tts.setLanguage('it-IT');
        await _scegliVoce();
      }
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

/// Una voce installata sul telefono.
class CoachVoice {
  const CoachVoice({
    required this.name,
    required this.locale,
    this.needsNetwork = false,
  });

  /// Il nome tecnico con cui il sistema la identifica (es. `it-it-x-kda-local`).
  final String name;

  /// La lingua, es. `it-IT`.
  final String locale;

  /// `true` per le voci sintetizzate dai server di Google.
  ///
  /// Suonano nettamente meglio, ma **tacciono dove non c'e' campo**. Per una
  /// app che si usa correndo e' un difetto grosso, quindi l'app non le sceglie
  /// mai da sola: le puo' scegliere l'utente, che sa dove corre.
  final bool needsNetwork;

  /// Un nome leggibile da una persona.
  ///
  /// I nomi veri sono sigle - `it-it-x-kda-local` - che non dicono niente a
  /// nessuno. Qui diventano "Voce 1", "Voce 2", con accanto l'avviso se
  /// servono i dati.
  String readableName(int index) => 'Voce $index';
}
