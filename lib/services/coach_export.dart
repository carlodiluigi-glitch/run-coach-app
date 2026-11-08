import '../models/athlete_profile.dart';
import '../models/daily_checkin.dart';
import '../models/effort.dart';
import '../models/lap.dart';
import '../models/running_activity.dart';
import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../utils/giorni.dart';
import 'cadence.dart';
import 'elevation_service.dart';
import 'pace_zone_engine.dart';
import 'session_classifier.dart';
import 'training_load_engine.dart';

/// Il testo da incollare in una chat con un'intelligenza artificiale, per
/// discutere gli allenamenti e preparare la settimana dopo.
///
/// PERCHE' UN TESTO E NON UN COLLEGAMENTO
/// --------------------------------------
/// Perche' cosi' l'app non ha bisogno di internet, non custodisce chiavi,
/// non costa niente a ogni conversazione e non manda dati a nessuno: e' chi
/// corre a decidere cosa copiare e dove. Il prezzo una tantum regge, e
/// "nessun dato raccolto" resta vero.
///
/// Il giro si chiude con il blocco di risposta descritto in fondo al testo
/// ([formatVersion]): l'AI lo scrive, l'atleta lo incolla in Falcata, e
/// Falcata lo controlla prima di accettarlo. Il giorno che ci sara' un
/// collegamento diretto cambiera' solo il trasporto, non il formato.
///
/// TRE TIPI DI DATO, SEMPRE DISTINGUIBILI
/// --------------------------------------
/// Ogni riga dice da dove viene:
///
///   [misurato]   GPS, cronometro, contapassi;
///   [dichiarato] detto dall'atleta;
///   [calcolato]  ricavato dall'app con i suoi modelli.
///
/// Quello che manca si scrive "non noto". Mai uno zero al posto di un dato
/// assente: un'AI che legge "fatica 0" conclude che era una passeggiata.
class CoachExport {
  const CoachExport();

  /// Il nome del formato di risposta. Cambia se cambia la struttura, cosi'
  /// l'importazione puo' riconoscere un blocco scritto per una versione
  /// diversa invece di leggerlo male.
  static const String formatVersion = 'FALCATA-SETTIMANA-1';

  static const String inizioBlocco = '===$formatVersion===';
  static const String fineBlocco = '===FINE===';

  /// Quanti giorni raccontare seduta per seduta.
  static const int giorniInDettaglio = 14;

  /// Quante settimane riassumere in chilometri.
  static const int settimaneDiStorico = 8;

  String build({
    required DateTime now,
    required List<RunningActivity> activities,
    List<DailyCheckIn> checkIns = const <DailyCheckIn>[],
    AthleteProfile? profile,
    double? fitnessIndex,
    TrainingZones? zones,
    TrainingLoadState? load,
    TrainingPlan? plan,
    Map<DateTime, int> dailySteps = const <DateTime, int>{},
  }) {
    final StringBuffer b = StringBuffer();
    final DateTime oggi = soloGiorno(now);
    final DateTime lunediProssimo =
        piuGiorni(oggi, 8 - oggi.weekday); // sempre il prossimo lunedi'

    b.writeln('FALCATA - DATI PER IL COACH');
    b.writeln('Esportati il ${_data(now)} alle ${_ora(now)}.');
    b.writeln();
    b.writeln('Legenda: [misurato] = GPS, cronometro o contapassi. '
        '[dichiarato] = detto dall\'atleta. [calcolato] = ricavato dall\'app. '
        '"non noto" = il dato non c\'e\': non va stimato.');
    b.writeln('Passi in min:sec al km, distanze in km.');
    b.writeln();

    _atleta(b, profile, fitnessIndex, zones, load, plan, oggi);
    _storico(b, activities, oggi);
    _dettaglio(b, activities, checkIns, zones, plan, oggi, dailySteps);
    _prossimaSettimana(b, plan, lunediProssimo);
    _istruzioni(b, lunediProssimo);

    return b.toString();
  }

  // ------------------------------------------------------------------ atleta
  void _atleta(
    StringBuffer b,
    AthleteProfile? profile,
    double? indice,
    TrainingZones? zones,
    TrainingLoadState? load,
    TrainingPlan? plan,
    DateTime oggi,
  ) {
    b.writeln('== ATLETA ==');
    final PlanConfig? config = plan?.config;
    if (config != null) {
      b.writeln('Obiettivo [dichiarato]: ${config.goal.label}.');
      final RaceEvent? gara = config.goalRace;
      if (gara != null) {
        b.writeln('Gara obiettivo [dichiarato]: ${gara.name}, '
            '${_km(gara.meters)} km, il ${_data(gara.date)} '
            '(fra ${giorniFra(oggi, gara.date)} giorni).');
      }
      for (final RaceEvent r in config.races) {
        if (r.isGoal || r.date.isBefore(oggi)) continue;
        b.writeln('Altra gara in calendario [dichiarato]: ${r.name}, '
            '${_km(r.meters)} km, il ${_data(r.date)}.');
      }
    } else {
      b.writeln('Obiettivo: non noto (nessun piano attivo).');
    }

    if (profile != null) {
      final int? eta = profile.age;
      if (eta != null) b.writeln('Eta\' [dichiarato]: $eta anni.');
      if (profile.runningYears != null) {
        b.writeln('Corre da [dichiarato]: ${profile.runningYears} anni.');
      }
      if (profile.inactiveSinceWeeks != null) {
        b.writeln('Stop recente [dichiarato]: '
            '${profile.inactiveSinceWeeks} settimane.');
      }
      for (final PersonalBest pb in profile.personalBests) {
        b.writeln('Personale [dichiarato]: ${_km(pb.meters)} km in '
            '${_durata(pb.seconds)}'
            '${pb.date == null ? '' : ', il ${_data(pb.date!)}'}.');
      }
    }

    b.writeln(indice == null
        ? 'Indice di forma (VDOT) [calcolato]: non noto.'
        : 'Indice di forma (VDOT) [calcolato]: ${indice.toStringAsFixed(1)}. '
            'Viene da gare, test, ripetute e tratti tirati; non scende '
            'per le corse lente.');

    if (zones != null) {
      b.writeln('Zone di passo [calcolato, dall\'indice]:');
      for (final ZonePace z in zones.all) {
        b.writeln('  - ${z.label}: ${_passo(z.range.low)}-'
            '${_passo(z.range.high)}');
      }
    }

    if (load != null && load.historyDays > 0) {
      b.writeln('Carico [calcolato]: fatica (media 7 giorni) '
          '${load.fatigue.toStringAsFixed(0)}, condizione (media 28 giorni) '
          '${load.fitness.toStringAsFixed(0)}. 100 punti = un\'ora a ritmo '
          'soglia.');
    }
    b.writeln();
  }

  // ----------------------------------------------------------------- storico
  void _storico(
    StringBuffer b,
    List<RunningActivity> activities,
    DateTime oggi,
  ) {
    b.writeln('== ULTIME $settimaneDiStorico SETTIMANE [misurato] ==');
    final DateTime lunedi = piuGiorni(oggi, -(oggi.weekday - 1));
    for (int i = settimaneDiStorico - 1; i >= 0; i--) {
      final DateTime da = piuGiorni(lunedi, -7 * i);
      final DateTime a = piuGiorni(da, 7);
      double metri = 0;
      int uscite = 0;
      double lungo = 0;
      for (final RunningActivity x in activities) {
        if (x.startTime.isBefore(da) || !x.startTime.isBefore(a)) continue;
        metri += x.distanceMeters;
        uscite++;
        if (x.distanceMeters > lungo) lungo = x.distanceMeters;
      }
      final String quale = i == 0 ? ' (in corso)' : '';
      b.writeln('Settimana dal ${_data(da)}$quale: ${_km(metri)} km, '
          '$uscite uscite'
          '${uscite == 0 ? '' : ', la piu\' lunga ${_km(lungo)} km'}.');
    }
    b.writeln();
  }

  // ---------------------------------------------------------------- dettaglio
  void _dettaglio(
    StringBuffer b,
    List<RunningActivity> activities,
    List<DailyCheckIn> checkIns,
    TrainingZones? zones,
    TrainingPlan? plan,
    DateTime oggi,
    Map<DateTime, int> passi,
  ) {
    b.writeln('== ULTIMI $giorniInDettaglio GIORNI, GIORNO PER GIORNO ==');
    b.writeln('Per ogni giorno: cosa prevedeva il piano, cosa e\' stato '
        'fatto, come stava l\'atleta.');
    b.writeln();

    for (int g = giorniInDettaglio - 1; g >= 0; g--) {
      final DateTime giorno = piuGiorni(oggi, -g);
      final List<RunningActivity> corse = activities
          .where((RunningActivity x) => giorniFra(x.startTime, giorno) == 0)
          .toList()
        ..sort((RunningActivity x, RunningActivity y) =>
            x.startTime.compareTo(y.startTime));
      final List<PlannedSession> previste =
          plan?.sessionsOn(giorno) ?? const <PlannedSession>[];
      DailyCheckIn? check;
      for (final DailyCheckIn c in checkIns) {
        if (giorniFra(c.date, giorno) == 0) check = c;
      }

      b.writeln('--- ${_giornoSettimana(giorno)} ${_data(giorno)} ---');
      if (plan != null) {
        b.writeln(previste.isEmpty
            ? 'Piano: riposo.'
            : 'Piano: ${previste.map(_previstaBreve).join('; ')}.');
      }
      if (check != null) {
        b.writeln('Mattino [dichiarato]: sonno ${check.sleep}/5, gambe '
            '${check.legs}/5, voglia ${check.motivation}/5'
            '${check.hasPain ? ', DOLORE${check.painNote == null ? '' : ': ${check.painNote}'}' : ''}.');
      }
      int? passiGiorno;
      passi.forEach((DateTime k, int v) {
        if (giorniFra(k, giorno) == 0) passiGiorno = v;
      });
      if (passiGiorno != null) {
        b.writeln('Passi in tutta la giornata [misurato, stima]: '
            '$passiGiorno (lavoro e vita, corse comprese).');
      }
      if (corse.isEmpty) {
        b.writeln('Fatto: niente.');
      }
      for (final RunningActivity x in corse) {
        _corsa(b, x, zones);
      }
      b.writeln();
    }
  }

  void _corsa(StringBuffer b, RunningActivity x, TrainingZones? zones) {
    final String tipo = switch (x.type) {
      ActivityType.free => 'corsa libera',
      ActivityType.workout => 'allenamento a fasi',
      ActivityType.treadmill => 'tapis roulant (inserito a mano)',
    };
    b.writeln('Corsa id ${x.id} - "${x.name}", $tipo, ore ${_ora(x.startTime)}.');
    b.writeln('  [misurato] ${_km(x.distanceMeters)} km in '
        '${_durata(x.durationSeconds)}, passo medio '
        '${_passo(x.averagePaceSecondsPerKm)} (media dell\'intera uscita, '
        'recuperi compresi).');
    if (x.type == ActivityType.treadmill) {
      b.writeln('  Nota: distanza dichiarata dal nastro, nessun tracciato. '
          'I nastri sbagliano del 5-10%.');
    }

    final ElevationSummary quota = const ElevationService().of(x.route);
    if (quota.isKnown) {
      b.writeln('  [misurato] dislivello +${quota.gainMeters.round()} m / '
          '-${quota.lossMeters.round()} m.');
    }
    final double? cadenza = Cadence.average(x.route);
    if (cadenza != null) {
      b.writeln('  [misurato] cadenza media ${cadenza.round()} passi/min.');
    }
    if (x.heartRateAverage != null) {
      b.writeln('  [misurato] frequenza cardiaca media ${x.heartRateAverage}'
          '${x.heartRateMax == null ? '' : ', massima ${x.heartRateMax}'}.');
    } else {
      b.writeln('  Frequenza cardiaca: non nota (nessuna fascia).');
    }

    _fasi(b, x);

    if (zones != null && x.route.length >= 2) {
      final SessionAnalysis a = const SessionClassifier().analyse(x, zones);
      b.writeln('  [calcolato] intensita\' reale: ${a.intensity.label}, '
          '${a.qualityMinutes.round()} minuti continui a ritmo soglia o piu\' '
          'veloce.');
    }

    if (x.declared != null) {
      b.writeln('  [dichiarato] era ${x.declared == EffortKind.race ? 'una gara' : 'un test'}.');
    }
    final SessionFeedback? f = x.feedback;
    if (f == null) {
      b.writeln('  [dichiarato] fatica percepita: non nota.');
    } else {
      b.writeln('  [dichiarato] fatica percepita ${f.rpe}/10 '
          '(${PerceivedEffort.label(f.rpe).toLowerCase()})'
          '${f.legs == null ? '' : ', gambe ${f.legs!.label.toLowerCase()}'}'
          '${f.hasPain ? ', DOLORE${f.painNote == null ? '' : ': ${f.painNote}'}' : ''}.');
      if (_pieno(f.note)) {
        b.writeln('  [dichiarato] commento: "${f.note!.trim()}"');
      }
    }
    if (_pieno(x.note)) {
      b.writeln('  [dichiarato] note: "${x.note!.trim()}"');
    }
    if (_pieno(x.coachSummary)) {
      b.writeln('  [interpretazione AI, da una conversazione precedente] '
          '"${x.coachSummary!.trim()}"');
    }
    if (x.temperature != null) {
      b.writeln('  [dichiarato] tempo, come l\'ha sentito: '
          '${x.temperature!.label.toLowerCase()}.');
    }
  }

  /// I giri o le fasi, separando il lavoro dai recuperi.
  ///
  /// E' la parte che conta di piu' per un'AI, e quella dove sbaglierebbe da
  /// sola: il passo medio di una seduta di ripetute mescola tratti veloci e
  /// recuperi, e non dice ne' l'uno ne' l'altro.
  void _fasi(StringBuffer b, RunningActivity x) {
    if (x.laps.isEmpty) return;
    final bool aFasi = x.laps.any((Lap l) => l.stepKind != null);

    if (!aFasi) {
      final List<String> parziali = <String>[
        for (final Lap l in x.laps)
          l.distanceMeters >= 900
              ? _passo(l.paceSecondsPerKm)
              : '${_passo(l.paceSecondsPerKm)} (${(l.distanceMeters).round()} m)',
      ];
      b.writeln('  [misurato] parziali: ${parziali.join(', ')}.');
      return;
    }

    b.writeln('  [misurato] fasi, nell\'ordine:');
    double metriLavoro = 0;
    int secondiLavoro = 0;
    for (final Lap l in x.laps) {
      final String ruolo = _ruolo(l.stepKind);
      b.writeln('    - ${l.stepLabel ?? 'Fase'} ($ruolo): '
          '${_distanza(l.distanceMeters)} in ${_durata(l.durationSeconds)}, '
          'passo ${_passo(l.paceSecondsPerKm)}.');
      if (l.stepKind == StepType.interval.storageKey) {
        metriLavoro += l.distanceMeters;
        secondiLavoro += l.durationSeconds;
      }
    }
    if (metriLavoro > 0 && secondiLavoro > 0) {
      b.writeln('  [misurato] solo i tratti di lavoro: '
          '${_km(metriLavoro)} km, passo medio '
          '${_passo(secondiLavoro / (metriLavoro / 1000.0))}.');
    }
  }

  // ------------------------------------------------------ settimana prossima
  void _prossimaSettimana(
    StringBuffer b,
    TrainingPlan? plan,
    DateTime lunedi,
  ) {
    b.writeln('== SETTIMANA DAL ${_data(lunedi)} ==');
    if (plan == null) {
      b.writeln('Nessun piano attivo: non c\'e\' una settimana prevista.');
      b.writeln();
      return;
    }
    final PlanWeek? settimana = plan.weekFor(lunedi);
    if (settimana == null) {
      b.writeln('Il piano attivo non arriva fino a questa settimana.');
      b.writeln();
      return;
    }

    b.writeln('Settimana ${settimana.number} di ${plan.weeks.length}, fase '
        '${settimana.phase.label}'
        '${_pieno(settimana.note) ? ' (${settimana.note})' : ''}. '
        'Previsti ${_km(settimana.plannedKm * 1000)} km.');

    b.writeln('Giorni disponibili [dichiarato]:');
    final WeeklyAvailability disp =
        plan.config.availabilityForWeek(settimana.number);
    for (int d = 1; d <= 7; d++) {
      final int minuti = disp.minutesOn(d);
      final bool corre = disp.runsOn(d);
      b.writeln('  - ${_giornoSettimana(piuGiorni(lunedi, d - 1))}: '
          '${corre ? '$minuti minuti' : 'niente'}');
    }

    b.writeln('Sedute previste dal piano [calcolato]:');
    if (settimana.sessions.isEmpty) b.writeln('  nessuna.');
    for (final PlannedSession s in settimana.sessions) {
      b.writeln('  - ${_giornoSettimana(s.date)} ${_data(s.date)}: '
          '${s.kind.label} - ${s.title}. ${s.detail}');
      final Workout? w = s.workout;
      if (w != null) {
        for (final WorkoutBlock blocco in w.blocks) {
          final String passi = blocco.steps.map(_passoProgrammato).join(' + ');
          b.writeln(blocco.repeat > 1
              ? '      ${blocco.repeat} x ($passi)'
              : '      $passi');
        }
      }
    }
    b.writeln();
  }

  String _passoProgrammato(WorkoutStep s) {
    final String quanto = s.isDistanceBased
        ? _distanza(s.goalDistanceMeters)
        : _durata(s.goalSeconds);
    final PaceTarget? t = s.paceTarget;
    final String ritmo = t == null
        ? ''
        : ' a ${_passo(t.fastestSecPerKm)}-${_passo(t.slowestSecPerKm)}';
    return '${s.type.label.toLowerCase()} $quanto$ritmo';
  }

  // --------------------------------------------------------------- istruzioni
  void _istruzioni(StringBuffer b, DateTime lunedi) {
    final String dal = _iso(lunedi);
    b.writeln('== ISTRUZIONI PER IL COACH ==');
    b.writeln('''
Sei il coach di questo atleta. Leggi i dati sopra, poi parlane con lui.

Come leggere i dati:
- Il passo medio di un allenamento a fasi mescola lavoro e recuperi: per
  giudicare la qualita' usa le fasi e la riga "solo i tratti di lavoro".
- Tieni separati [misurato], [dichiarato] e [calcolato]. Quello che e'
  "non noto" resta non noto: non stimarlo e non riempirlo.
- Non ricavare tempi di gara da ripetute brevi o da una seduta sola.
  Se una conclusione richiede altri dati, dillo.

Come parlare:
- L'atleta racconta come sono andate le sedute. Fai poche domande, solo
  quelle che servono: cosa lo limitava (fiato o gambe), se il passo era
  regolare, se avrebbe potuto continuare, come stava il giorno dopo,
  sonno, stress, fatica del lavoro.
- Poi proponi la settimana dal ${_data(lunedi)}: confermare il piano,
  alleggerirlo o aumentarlo. Spiega perche'. Confermare va benissimo:
  non serve aumentare ogni settimana.
- Rispetta i giorni disponibili e i minuti di ogni giorno.
- Se l'atleta dichiara dolore, niente qualita' finche' non passa.

Quando l'atleta conferma la settimana, scrivi il blocco qui sotto, una volta
sola, senza altro testo dentro. L'atleta lo incollera' in Falcata, che lo
controlla prima di usarlo. Fuori dal blocco scrivi quello che vuoi.

$inizioBlocco
{
  "settimana_dal": "$dal",
  "decisione": "conferma | alleggerisci | aumenta | cambia",
  "motivo": "due o tre frasi per l'atleta",
  "sedute": [
    {
      "data": "AAAA-MM-GG",
      "tipo": "lento | lungo | soglia | ripetute | veloci | passo_gara | fartlek | gara",
      "titolo": "breve, es. 5 x 1000",
      "fasi": [
        { "ripeti": 1, "passi": [
          { "tipo": "riscaldamento", "secondi": 900 }
        ]},
        { "ripeti": 5, "passi": [
          { "tipo": "lavoro", "metri": 1000, "passo_da": "4:15", "passo_a": "4:20" },
          { "tipo": "recupero", "secondi": 120 }
        ]},
        { "ripeti": 1, "passi": [
          { "tipo": "defaticamento", "secondi": 600 }
        ]}
      ]
    }
  ],
  "riepiloghi": [
    {
      "corsa": "id della corsa, come scritto sopra",
      "sensazioni": "quello che ha detto l'atleta, con le sue sfumature",
      "limite": "fiato | gambe | niente | non noto",
      "avrebbe_continuato": "si | no | non noto"
    }
  ]
}
$fineBlocco

Regole del blocco:
- Solo i giorni in cui si corre; i giorni di riposo non si scrivono.
- "tipo" dei passi: riscaldamento, corsa, lavoro, recupero, defaticamento.
- Ogni passo ha "metri" oppure "secondi", non tutti e due.
- "passo_da" e "passo_a" sono facoltativi, in min:sec al km.
- Un lento o un lungo possono avere un solo passo "corsa".
- "riepiloghi": una voce per ogni corsa di cui avete parlato; quello che
  non e' stato detto resta "non noto".''');
  }

  // ---------------------------------------------------------------- utilita'
  String _previstaBreve(PlannedSession s) => '${s.kind.label} - ${s.title}';

  String _ruolo(String? kind) {
    if (kind == StepType.interval.storageKey) return 'lavoro';
    if (kind == StepType.recovery.storageKey) return 'recupero';
    if (kind == StepType.warmup.storageKey) return 'riscaldamento';
    if (kind == StepType.cooldown.storageKey) return 'defaticamento';
    return 'corsa';
  }

  static bool _pieno(String? s) => s != null && s.trim().isNotEmpty;

  static String _km(double metri) => (metri / 1000.0).toStringAsFixed(2);

  static String _distanza(double metri) =>
      metri < 1000 ? '${metri.round()} m' : '${_km(metri)} km';

  static String _passo(double? secondiAlKm) {
    if (secondiAlKm == null ||
        !secondiAlKm.isFinite ||
        secondiAlKm <= 0 ||
        secondiAlKm > 3600) {
      return 'non noto';
    }
    final int s = secondiAlKm.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String _durata(int secondi) {
    final int h = secondi ~/ 3600;
    final int m = (secondi % 3600) ~/ 60;
    final String s = (secondi % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  static String _due(int n) => n.toString().padLeft(2, '0');

  static String _data(DateTime d) => '${_due(d.day)}/${_due(d.month)}/${d.year}';

  static String _iso(DateTime d) => '${d.year}-${_due(d.month)}-${_due(d.day)}';

  static String _ora(DateTime d) => '${_due(d.hour)}:${_due(d.minute)}';

  static const List<String> _giorni = <String>[
    'lunedi\'',
    'martedi\'',
    'mercoledi\'',
    'giovedi\'',
    'venerdi\'',
    'sabato',
    'domenica',
  ];

  static String _giornoSettimana(DateTime d) => _giorni[d.weekday - 1];
}
