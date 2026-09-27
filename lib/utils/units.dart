/// Chilometri o miglia: un posto solo dove sta la differenza.
///
/// LA REGOLA CHE NON SI TOCCA
/// --------------------------
/// Dentro l'app **tutto resta in metri e in secondi al chilometro**. Il GPS
/// misura in metri, lo storico e' salvato in metri, il motore di forma
/// ragiona in metri. Le miglia esistono solo nell'ultimo centimetro, quando
/// un numero viene scritto sullo schermo o detto ad alta voce.
///
/// E' il motivo per cui si puo' cambiare unita' quando si vuole senza
/// rovinare niente: non viene convertito nessun dato salvato, cambia solo
/// come lo si legge. Se un giorno l'unita' finisse dentro i file, il primo
/// cambio di impostazione trasformerebbe dieci chilometri in dieci miglia e
/// lo storico sarebbe da buttare.
///
/// PERCHE' UNA VARIABILE GLOBALE
/// -----------------------------
/// Le funzioni di formattazione sono chiamate in 57 punti dell'app. Passare
/// l'unita' a mano in tutti e 57 vuol dire 57 occasioni di dimenticarsene, e
/// una dimenticanza non da' errore: da' semplicemente un numero sbagliato,
/// che e' il tipo di bug peggiore. Quindi l'unita' sta qui, la impostano le
/// impostazioni, e chi formatta la legge. Chi vuole essere esplicito - i test
/// soprattutto - puo' sempre passarla come parametro.
library;

import '../models/user_settings.dart';

/// Metri in un miglio terrestre.
const double metersPerMile = 1609.344;

/// L'unita' scelta dall'utente.
///
/// La imposta [SettingsProvider] all'avvio e a ogni cambio. Non va letta per
/// fare calcoli: serve solo a scrivere e a parlare.
UnitSystem activeUnits = UnitSystem.metric;

extension UnitSystemMeasures on UnitSystem {
  bool get isImperial => this == UnitSystem.imperial;

  /// Quanti metri in una unita' di distanza "lunga".
  double get metersPerUnit => isImperial ? metersPerMile : 1000.0;

  String get distanceUnit => isImperial ? 'mi' : 'km';
  String get paceUnit => isImperial ? '/mi' : '/km';
  String get speedUnit => isImperial ? 'mph' : 'km/h';

  /// Come si dice ad alta voce.
  String get spokenOne => isImperial ? 'un miglio' : 'un chilometro';
  String get spokenMany => isImperial ? 'miglia' : 'chilometri';
  String get spokenPer => isImperial ? 'al miglio' : 'al chilometro';
  String get spokenSpeed => isImperial ? 'miglia orarie' : 'chilometri orari';

  /// Metri -> unita' scelta.
  double distanceFrom(double meters) => meters / metersPerUnit;

  /// Unita' scelta -> metri. Serve quando l'utente digita una distanza.
  double distanceToMeters(double value) => value * metersPerUnit;

  /// Secondi al chilometro -> secondi all'unita' scelta.
  double paceFrom(double secondsPerKm) =>
      isImperial ? secondsPerKm * (metersPerMile / 1000.0) : secondsPerKm;

  /// Secondi all'unita' scelta -> secondi al chilometro.
  double paceToSecondsPerKm(double pace) =>
      isImperial ? pace / (metersPerMile / 1000.0) : pace;

  /// Metri al secondo -> km/h oppure mph.
  double speedFrom(double metersPerSecond) =>
      metersPerSecond * (isImperial ? 3600.0 / metersPerMile : 3.6);
}

/// Le distanze corte restano in metri in tutti e due i sistemi.
///
/// Non e' una dimenticanza: le ripetute in pista sono metriche in tutto il
/// mondo, Stati Uniti compresi. Nessuno corre "437 iarde": corre i 400.
const double shortDistanceLimitMeters = 1000;
