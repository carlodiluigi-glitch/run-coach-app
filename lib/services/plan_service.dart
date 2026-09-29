import 'dart:math' as math;

import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../utils/formatters.dart';
import 'fitness_service.dart';

/// Il calendario di una settimana: dove va il lungo, dove va la qualita'.
class WeekSchedule {
  const WeekSchedule({
    required this.runDays,
    required this.longDay,
    required this.qualityDays,
  });

  /// Giorni in cui si corre. 1 = lunedi'.
  final List<int> runDays;

  /// Giorno del lungo.
  final int longDay;

  /// Giorni di qualita', in ordine.
  final List<int> qualityDays;

  /// I giorni che restano: corse lente.
  List<int> get easyDays => runDays
      .where((int d) => d != longDay && !qualityDays.contains(d))
      .toList();

  bool get isEmpty => runDays.isEmpty;
}

/// Generatore di piani di allenamento.
///
/// DA DOVE VENGONO LE REGOLE
/// -------------------------
/// Non sono invenzioni. Il piano applica quattro principi che in letteratura
/// sono fuori discussione:
///
/// 1. **Distribuzione polarizzata.** Circa l'80% del tempo va corso piano e
///    il 20% forte, con poco in mezzo (Seiler). Il "medio tutti i giorni" e'
///    l'errore piu' comune fra chi corre da solo: stanca come il forte senza
///    darne i benefici.
/// 2. **Passi ricavati dalla forma attuale.** Ogni seduta ha un passo
///    obiettivo derivato dal VDOT (Daniels), non una percentuale a caso.
/// 3. **Progressione con scarichi.** Il volume cresce di poco per volta e
///    ogni quarta settimana scende: l'adattamento avviene nel recupero, non
///    nel carico.
/// 4. **Periodizzazione.** Prima si costruisce il motore (lento e volume),
///    poi si aggiunge la soglia, poi il passo della gara scelta, e alla fine
///    si scarica per arrivare freschi.
///
/// Le singole sedute (ripetute da 1000, frazioni di soglia da 1600, richiami
/// brevi in scarico) sono quelle classiche dei manuali, con il numero di
/// ripetizioni che cresce settimana per settimana.
///
/// QUELLO CHE QUESTO PIANO NON PUO' SAPERE
/// ---------------------------------------
/// Se hai dormito male, se il ginocchio tira, se al lavoro e' una settimana
/// pesante. Un piano scritto un mese prima e' un'ipotesi: va corretto in
/// corsa. Quella parte arrivera' con il check-in giornaliero.
class PlanService {
  const PlanService({this.fitness = const FitnessService()});

  final FitnessService fitness;

  /// Giorni preferiti per la qualita' a parita' di tempo disponibile.
  ///
  /// Martedi' e giovedi' non hanno niente di fisiologico: sono la tradizione,
  /// e la tradizione vale come spareggio quando due giorni offrono lo stesso
  /// tempo. Il criterio vero e' quanto tempo c'e'.
  static const List<int> qualityDayPreference = <int>[2, 4];

  /// Decide il calendario della settimana a partire dal tempo disponibile.
  ///
  /// LE REGOLE, IN ORDINE DI IMPORTANZA
  /// ----------------------------------
  /// 1. Si corre solo nei giorni dichiarati.
  /// 2. Il lungo va dove c'e' piu' tempo. E' l'unica seduta che non si puo'
  ///    comprimere: un lungo da 18 km non entra in un'ora, e farlo a pezzi
  ///    non e' la stessa cosa.
  /// 3. La qualita' non va mai il giorno prima del lungo. Il lungo e' la
  ///    seduta piu' importante della settimana: arrivarci con le gambe piene
  ///    la rovina.
  /// 4. Due sedute di qualita' non vanno mai attaccate. L'adattamento avviene
  ///    nel recupero: due giorni forti di fila sono un giorno forte e un
  ///    giorno sprecato.
  /// 5. Fra i giorni che restano, la qualita' va dove c'e' piu' tempo: e' la
  ///    seduta che ne chiede di piu' fra riscaldamento, lavoro e defaticamento.
  ///
  /// La settimana e' circolare: la domenica e il lunedi' sono attaccati, e il
  /// conto lo tiene presente - altrimenti un lungo il lunedi' si porterebbe
  /// dietro una qualita' la domenica sera.
  ///
  /// Se le regole non permettono di piazzare tutte le sedute di qualita'
  /// richieste, se ne piazzano meno. Non si rompe una regola per far quadrare
  /// un numero.
  WeekSchedule scheduleFor(
    WeeklyAvailability availability, {
    required int qualityWanted,
  }) {
    final List<int> runDays = availability.runDays;
    if (runDays.isEmpty) {
      return const WeekSchedule(
        runDays: <int>[],
        longDay: 7,
        qualityDays: <int>[],
      );
    }

    final int longDay = availability.longestDay ?? runDays.last;
    final int dayBeforeLong = longDay == 1 ? 7 : longDay - 1;
    final int dayAfterLong = longDay == 7 ? 1 : longDay + 1;

    final List<int> candidates = runDays
        .where((int d) => d != longDay && d != dayBeforeLong)
        .toList()
      ..sort((int a, int b) {
        final int byTime =
            availability.minutesOn(b).compareTo(availability.minutesOn(a));
        if (byTime != 0) return byTime;
        final int pa = _classicRank(a);
        final int pb = _classicRank(b);
        if (pa != pb) return pa.compareTo(pb);
        return a.compareTo(b);
      });

    final List<int> picked = <int>[];
    // Due passate. La prima evita anche il giorno DOPO il lungo; se non
    // bastano i giorni, la seconda lo concede - correre forte il giorno dopo
    // un lungo e' meno grave che arrivare al lungo stanchi.
    for (int pass = 0; pass < 2 && picked.length < qualityWanted; pass++) {
      for (final int day in candidates) {
        if (picked.length >= qualityWanted) break;
        if (picked.contains(day)) continue;
        if (pass == 0 && day == dayAfterLong) continue;
        if (picked.any((int q) => _adjacent(q, day))) continue;
        picked.add(day);
      }
    }
    picked.sort();

    return WeekSchedule(
      runDays: runDays,
      longDay: longDay,
      qualityDays: picked,
    );
  }

  static int _classicRank(int weekday) {
    final int index = qualityDayPreference.indexOf(weekday);
    return index < 0 ? qualityDayPreference.length : index;
  }

  /// Due giorni attaccati, tenendo conto che la settimana gira.
  static bool _adjacent(int a, int b) {
    if (a == b) return true;
    final int diff = (a - b).abs();
    return diff == 1 || diff == 6;
  }

  /// Genera il piano. `null` se la forma non e' stimabile.
  TrainingPlan? generate(PlanConfig config) {
    final TrainingPaces? paces = fitness.pacesFor(config.vdot);
    if (paces == null) return null;

    final int weeks =
        config.weeks.clamp(config.goal.minWeeks, config.goal.maxWeeks);

    final List<PlanPhase> phases =
        phasesFor(weeks, config.goal, startPhase: config.startPhase);
    final List<double> volumes = volumesFor(
      weeks: weeks,
      phases: phases,
      startWeeklyKm: config.startWeeklyKm,
      goal: config.goal,
    );

    final List<PlanWeek> built = <PlanWeek>[];
    for (int i = 0; i < weeks; i++) {
      built.add(_buildWeek(
        index: i,
        phase: phases[i],
        targetKm: volumes[i],
        config: config,
        paces: paces,
        isDownWeek: _isDownWeek(i, phases[i]),
      ));
    }

    return _applyRaces(
      TrainingPlan(config: config, weeks: built),
      paces,
    );
  }

  // ------------------------------------------------------------------ fasi
  /// Divisione del piano in fasi.
  List<PlanPhase> phasesFor(
    int weeks,
    RaceGoal goal, {
    PlanPhase startPhase = PlanPhase.base,
  }) {
    if (weeks <= 0) return <PlanPhase>[];

    // SENZA GARA NON CI SONO FASI.
    //
    // Una fase e' un modo di distribuire il lavoro verso una data. Senza
    // quella data, "Costruzione" e "Sviluppo" sono due etichette: quello che
    // conta davvero e' la rotazione dei lavori e lo scarico ogni quarta
    // settimana, e quelli ci sono comunque.
    //
    // Quindi tutte le settimane sono uguali, ed e' onesto dirlo invece di
    // fingere una periodizzazione che non porta da nessuna parte.
    if (goal == RaceGoal.fitness) {
      return List<PlanPhase>.filled(weeks, PlanPhase.build);
    }

    // Partire dallo Specifico: si e' gia' in forma e manca poco. Tutto sul
    // passo di gara, con lo scarico finale.
    if (startPhase == PlanPhase.peak) {
      final int taperOnly = (weeks * 0.12).round().clamp(1, 3);
      return List<PlanPhase>.generate(
        weeks,
        (int i) => i < weeks - taperOnly ? PlanPhase.peak : PlanPhase.taper,
      );
    }

    int taper = (weeks * 0.10).round().clamp(1, 3);
    int peak = (weeks * 0.18).round().clamp(1, 4);
    int remaining = weeks - taper - peak;

    // Piani molto corti: si tiene una settimana per fase e il resto va in
    // sviluppo, che e' la fase che rende piu' in poco tempo.
    if (remaining < 2) {
      taper = 1;
      peak = 1;
      remaining = weeks - 2;
      if (remaining < 2) {
        return List<PlanPhase>.generate(
          weeks,
          (int i) => i == weeks - 1 ? PlanPhase.taper : PlanPhase.build,
        );
      }
    }

    // Le settimane di Costruzione saltate non si perdono: vanno a Sviluppo,
    // cioe' a lavoro vero. Saltare la base non accorcia il piano, lo riempie
    // meglio.
    int base;
    int build;
    if (startPhase == PlanPhase.build) {
      base = 0;
      build = remaining;
    } else {
      base = math.max(1, (remaining * 0.55).round());
      build = remaining - base;
      if (build < 1) {
        build = 1;
        base = remaining - 1;
      }
    }

    final List<PlanPhase> out = <PlanPhase>[];
    for (int i = 0; i < base; i++) {
      out.add(PlanPhase.base);
    }
    for (int i = 0; i < build; i++) {
      out.add(PlanPhase.build);
    }
    for (int i = 0; i < peak; i++) {
      out.add(PlanPhase.peak);
    }
    for (int i = 0; i < taper; i++) {
      out.add(PlanPhase.taper);
    }
    return out;
  }

  /// Ogni quarta settimana e' di scarico, ma non durante lo scarico finale.
  bool _isDownWeek(int index, PlanPhase phase) {
    if (phase == PlanPhase.taper || phase == PlanPhase.recovery) return false;
    return (index + 1) % 4 == 0;
  }

  // --------------------------------------------------------------- volumi
  /// Chilometri previsti settimana per settimana.
  List<double> volumesFor({
    required int weeks,
    required List<PlanPhase> phases,
    required double startWeeklyKm,
    required RaceGoal goal,
  }) {
    final double start = startWeeklyKm <= 0 ? 15.0 : startWeeklyKm;

    // Il picco non supera mai il 55% in piu' del punto di partenza, ne' il
    // tetto della distanza obiettivo. Chi parte da 20 km non finisce a 80:
    // e' la strada piu' breve per farsi male.
    double peakKm = math.min(start * 1.55, goal.weeklyCapKm);
    if (peakKm < start) peakKm = start;

    // SENZA GARA: PROGRESSIONE A CICLI, NON A FINE PIANO.
    //
    // Un piano con una data sale in linea retta fino alla gara. Un piano che
    // dura mesi non ha una retta da percorrere: ha cicli. Tre settimane di
    // carico allo stesso volume, una di scarico, e il ciclo dopo riparte
    // sopra il precedente.
    //
    // Il passo e' del 5% a ciclo, non a settimana: sono circa tre chilometri
    // ogni quattro settimane per chi ne fa sessanta. Sembra poco ed e'
    // esattamente il punto - il volume che cresce in fretta e' quello che
    // porta agli infortuni, e qui non c'e' nessuna data che costringa a fare
    // in fretta.
    if (goal == RaceGoal.fitness) {
      const double perCycle = 1.05;
      final List<double> continuo = <double>[];
      for (int i = 0; i < weeks; i++) {
        final int cycle = i ~/ 4;
        double value = start * math.pow(perCycle, cycle).toDouble();
        if (value > peakKm) value = peakKm;
        if (_isDownWeek(i, phases[i])) value *= 0.75;
        continuo.add(double.parse(value.toStringAsFixed(1)));
      }
      return continuo;
    }

    // Il picco si raggiunge alla fine dell'ultima settimana prima dello
    // scarico finale.
    int lastLoadIndex = weeks - 1;
    for (int i = weeks - 1; i >= 0; i--) {
      if (phases[i] != PlanPhase.taper) {
        lastLoadIndex = i;
        break;
      }
    }

    final List<double> taperFactors = _taperFactors(
      phases.where((PlanPhase p) => p == PlanPhase.taper).length,
    );
    int taperSeen = 0;

    final List<double> out = <double>[];
    for (int i = 0; i < weeks; i++) {
      double value;
      if (phases[i] == PlanPhase.taper) {
        final double factor = taperSeen < taperFactors.length
            ? taperFactors[taperSeen]
            : taperFactors.last;
        taperSeen++;
        value = peakKm * factor;
      } else {
        final double progress =
            lastLoadIndex <= 0 ? 1.0 : i / lastLoadIndex.toDouble();
        value = start + (peakKm - start) * progress.clamp(0.0, 1.0);
        if (_isDownWeek(i, phases[i])) {
          value *= 0.75;
        }
      }
      if (value < start * 0.45) value = start * 0.45;
      out.add(double.parse(value.toStringAsFixed(1)));
    }
    return out;
  }

  /// Quanto si scende nelle settimane di scarico finale.
  List<double> _taperFactors(int count) {
    switch (count) {
      case 0:
        return <double>[1.0];
      case 1:
        return <double>[0.55];
      case 2:
        return <double>[0.70, 0.50];
      default:
        return <double>[0.75, 0.60, 0.45];
    }
  }

  // ------------------------------------------------------------ settimana
  PlanWeek _buildWeek({
    required int index,
    required PlanPhase phase,
    required double targetKm,
    required PlanConfig config,
    required TrainingPaces paces,
    required bool isDownWeek,
  }) {
    final DateTime weekStart = _dayOnly(
      config.startDate.add(Duration(days: index * 7)),
    );
    final WeeklyAvailability availability = config.effectiveAvailability;

    int qualityWanted;
    switch (phase) {
      case PlanPhase.base:
        qualityWanted = 1;
        break;
      case PlanPhase.build:
      case PlanPhase.peak:
        qualityWanted = 2;
        break;
      case PlanPhase.taper:
        qualityWanted = 1;
        break;
      case PlanPhase.recovery:
        qualityWanted = 0;
        break;
    }
    if (availability.dayCount <= 3) qualityWanted = math.min(qualityWanted, 1);
    if (isDownWeek) qualityWanted = math.min(qualityWanted, 1);

    final WeekSchedule schedule =
        scheduleFor(availability, qualityWanted: qualityWanted);
    final List<int> qualityDays = schedule.qualityDays;
    final int longDay = schedule.longDay;

    // ------------------------------------------------- quanto ci sta davvero
    //
    // Il tempo dichiarato e' un tetto, non un suggerimento. Un piano che
    // chiede 18 km il giorno in cui hai un'ora e mezza a passo lento chiede
    // una cosa che non ci sta, e un piano che chiede l'impossibile viene
    // abbandonato entro la seconda settimana.
    final double easyPaceSec = paces.easy.slowestSecPerKm;
    double kmIn(int minutes) => minutes * 60.0 / easyPaceSec;

    double capacityKm = 0;
    for (final int day in schedule.runDays) {
      capacityKm += kmIn(availability.minutesOn(day));
    }

    // Il volume della settimana non puo' superare il tempo che c'e'. Si tiene
    // un margine del 5%: il tempo dichiarato e' il massimo, non la norma.
    final double usableKm = capacityKm * 0.95;
    final bool volumeLimitedByTime = targetKm > usableKm && usableKm > 0;
    final double weekKm = volumeLimitedByTime ? usableKm : targetKm;

    // ------------------------------------------------------------- lungo
    final double longFraction = _longFraction(phase);
    double longKm = weekKm * longFraction;
    final double capKm = config.goal.longRunCapMeters / 1000.0;
    if (longKm > capKm) longKm = capKm;
    final double longTimeCapKm = kmIn(availability.minutesOn(longDay));
    if (longKm > longTimeCapKm) longKm = longTimeCapKm;
    if (longKm < 5) longKm = math.min(5.0, weekKm * 0.5);

    // ---------------------------------------------------------- qualita'
    final List<PlannedSession> sessions = <PlannedSession>[];
    double qualityKm = 0;

    for (int slot = 0; slot < qualityDays.length; slot++) {
      final _QualitySession built = _qualitySession(
        phase: phase,
        goal: config.goal,
        weekIndex: index,
        slot: slot,
        paces: paces,
        vdot: config.vdot,
        weekNumber: index + 1,
        weekKm: weekKm,
        budgetSeconds: availability.minutesOn(qualityDays[slot]) * 60,
      );
      final double km = (built.workout.estimatedMeters) / 1000.0;
      qualityKm += km;
      sessions.add(PlannedSession(
        date: _dateOf(weekStart, qualityDays[slot]),
        kind: built.kind,
        title: built.title,
        detail: built.detail,
        distanceMeters: built.workout.estimatedMeters,
        durationSeconds: built.workout.estimatedSeconds,
        workout: built.workout,
      ));
    }

    // -------------------------------------------------------------- lenti
    //
    // I chilometri che restano si dividono in proporzione al tempo: chi ha
    // un'ora corre di piu' di chi ha mezz'ora, invece di dare a tutti la
    // stessa cifra e sforare dove il tempo non c'e'.
    final List<int> easyDays = schedule.easyDays;
    final double remainingKm =
        math.max(0.0, weekKm - longKm - qualityKm);

    int easyMinutes = 0;
    for (final int day in easyDays) {
      easyMinutes += availability.minutesOn(day);
    }

    for (final int day in easyDays) {
      final int minutes = availability.minutesOn(day);
      double km = easyMinutes <= 0
          ? 0
          : remainingKm * (minutes / easyMinutes);
      final double dayCapKm = kmIn(minutes);
      if (km > dayCapKm) km = dayCapKm;
      if (km > 18) km = 18;
      if (km < 3) km = math.min(3.0, dayCapKm);

      sessions.add(PlannedSession(
        date: _dateOf(weekStart, day),
        kind: SessionKind.easy,
        title: 'Lento ${km.toStringAsFixed(0)} km',
        detail: 'Passo ${formatPaceWithUnit(paces.easy.slowestSecPerKm)} - '
            '${formatPaceWithUnit(paces.easy.fastestSecPerKm)}. '
            'Se fai fatica a parlare, stai andando troppo forte.',
        distanceMeters: km * 1000,
      ));
    }

    // -------------------------------------------------------------- lungo
    sessions.add(PlannedSession(
      date: _dateOf(weekStart, longDay),
      kind: SessionKind.long,
      title: 'Lungo ${longKm.toStringAsFixed(0)} km',
      detail: _longDetail(phase, config.goal, paces),
      distanceMeters: longKm * 1000,
    ));

    sessions.sort((PlannedSession a, PlannedSession b) =>
        a.date.compareTo(b.date));

    final List<String> note = <String>[];
    if (isDownWeek) {
      note.add('Settimana di scarico: il volume scende del 25%');
    }
    if (volumeLimitedByTime) {
      note.add('Volume tenuto a ${weekKm.toStringAsFixed(0)} km: e\' quanto '
          'ci sta nel tempo che hai dichiarato');
    }

    return PlanWeek(
      number: index + 1,
      phase: phase,
      startDate: weekStart,
      targetKm: weekKm,
      sessions: sessions,
      note: note.isEmpty ? null : note.join('. '),
    );
  }

  double _longFraction(PlanPhase phase) {
    switch (phase) {
      case PlanPhase.base:
        return 0.25;
      case PlanPhase.build:
        return 0.28;
      case PlanPhase.peak:
        return 0.30;
      case PlanPhase.taper:
        return 0.22;
      case PlanPhase.recovery:
        return 0.22;
    }
  }

  String _longDetail(PlanPhase phase, RaceGoal goal, TrainingPaces paces) {
    if (phase == PlanPhase.peak &&
        (goal == RaceGoal.half || goal == RaceGoal.marathon)) {
      return 'Ultimo terzo al passo medio '
          '(${formatPaceWithUnit(paces.marathon.secondsPerKm)}). '
          'Serve a imparare a spingere da stanco.';
    }
    return 'Tutto lento, '
        '${formatPaceWithUnit(paces.easy.slowestSecPerKm)} o piu\'. '
        'Il lungo costruisce la resistenza col tempo sui piedi, non col ritmo.';
  }

  // ------------------------------------------------------ sedute qualita'
  _QualitySession _qualitySession({
    required PlanPhase phase,
    required RaceGoal goal,
    required int weekIndex,
    required int slot,
    required TrainingPaces paces,
    required double vdot,
    required int weekNumber,
    required double weekKm,
    int? budgetSeconds,
  }) {
    final String idBase = 'plan-w$weekNumber-q$slot';
    final double easySec = paces.easy.slowestSecPerKm;

    switch (phase) {
      case PlanPhase.base:
        {
        // In costruzione si tocca il veloce senza farne una seduta dura: il
        // corpo impara a muoversi in fretta mentre il motore cresce piano.
        if (weekIndex.isEven) {
          final _Fitted fit = _fit(
            wantedReps: 8,
            minReps: 4,
            repSeconds: 120,
            warmupSeconds: 720,
            cooldownSeconds: 480,
            budgetSeconds: budgetSeconds,
          );
          final int reps = fit.reps;
          return _QualitySession(
            kind: SessionKind.fartlek,
            title: 'Fartlek $reps x 1 minuto',
            detail: 'Un minuto veloce, uno lento, $reps volte. '
                'Senza guardare il passo: a sensazione, forte ma controllato.',
            workout: _buildWorkout(
              id: idBase,
              name: 'Fartlek $reps x 1\'',
              paces: paces,
              warmupSeconds: fit.warmupSeconds,
              repeat: reps,
              work: _timeStep(StepType.interval, 60, paces.interval),
              recovery: _timeStep(StepType.recovery, 60, paces.easy),
              cooldownSeconds: fit.cooldownSeconds,
            ),
          );
        }
        final _Fitted fit = _fit(
          wantedReps: 8,
          minReps: 4,
          repSeconds: 0.2 * paces.repetition.secondsPerKm + 90,
          warmupSeconds: 1200,
          cooldownSeconds: 600,
          budgetSeconds: budgetSeconds,
        );
        final int reps = fit.reps;
        return _QualitySession(
          kind: SessionKind.repetitions,
          title: 'Allunghi $reps x 200 m',
          detail: 'Allunghi brevi e sciolti a '
              '${formatPaceWithUnit(paces.repetition.secondsPerKm)}, '
              'con recupero camminato. Non deve stancare.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Allunghi $reps x 200 m',
            paces: paces,
            warmupSeconds: fit.warmupSeconds,
            repeat: reps,
            work: _distanceStep(StepType.interval, 200, paces.repetition),
            recovery: _timeStep(StepType.recovery, 90, paces.easy),
            cooldownSeconds: fit.cooldownSeconds,
          ),
        );
        }

      case PlanPhase.build:
        {
        // LA ROTAZIONE
        //
        // Ogni terza settimana i lavori cambiano forma, non intensita':
        // frazioni di soglia piu' lunghe allo stesso passo, e richiami brevi
        // al posto dei mille. Serve soprattutto ai piani senza gara, dove le
        // settimane sono tutte uguali e ripetere le stesse due sedute per
        // mesi smette di allenare molto prima che smetta di stancare.
        final bool variante = weekIndex % 3 == 2;

        if (slot == 0) {
          // La soglia e' il lavoro che sposta di piu' il risultato su
          // qualunque distanza dai 5 km in su: c'e' sempre, cambia solo la
          // lunghezza delle frazioni.
          final double frazione = variante ? 2000 : 1600;
          final int recupero = variante ? 120 : 90;
          final _Fitted fit = _fit(
            wantedReps: repsForShare(
              weekKm: weekKm,
              share: thresholdShareOfWeek,
              fractionMeters: frazione,
              minReps: 2,
              maxReps: 6,
            ),
            minReps: 2,
            repSeconds:
                frazione / 1000.0 * paces.threshold.secondsPerKm + recupero,
            warmupSeconds: 900,
            cooldownSeconds: 600,
            budgetSeconds: budgetSeconds,
          );
          final int reps = fit.reps;
          final String nome =
              'Soglia $reps x ${formatDistanceAuto(frazione)}';
          return _QualitySession(
            kind: SessionKind.threshold,
            title: nome,
            detail: 'A ${formatPaceWithUnit(paces.threshold.secondsPerKm)}, '
                'recupero $recupero secondi. Deve essere "duro ma '
                'sostenibile": se negli ultimi non tieni il passo, hai '
                'iniziato troppo forte.',
            workout: _buildWorkout(
              id: idBase,
              name: nome,
              paces: paces,
              warmupSeconds: fit.warmupSeconds,
              repeat: reps,
              work: _distanceStep(
                  StepType.interval, frazione, paces.threshold),
              recovery: _timeStep(StepType.recovery, recupero, paces.easy),
              cooldownSeconds: fit.cooldownSeconds,
            ),
          );
        }

        if (variante) {
          // Richiami brevi: non allenano il motore, allenano il gesto. Poco
          // volume, recupero pieno, e il giorno dopo le gambe sono fresche.
          final _Fitted fit = _fit(
            wantedReps: repsForShare(
              weekKm: weekKm,
              share: repetitionShareOfWeek,
              fractionMeters: 400,
              minReps: 5,
              maxReps: 10,
            ),
            minReps: 5,
            repSeconds: 0.4 * paces.repetition.secondsPerKm + 0.4 * easySec,
            warmupSeconds: 900,
            cooldownSeconds: 600,
            budgetSeconds: budgetSeconds,
          );
          final int reps = fit.reps;
          return _QualitySession(
            kind: SessionKind.repetitions,
            title: 'Veloci $reps x 400 m',
            detail: 'A ${formatPaceWithUnit(paces.repetition.secondsPerKm)}, '
                'recupero 400 m lenti. Non deve stancare: se l\'ultimo e\' '
                'piu\' lento del primo, eri troppo veloce.',
            workout: _buildWorkout(
              id: idBase,
              name: 'Veloci $reps x 400 m',
              paces: paces,
              warmupSeconds: fit.warmupSeconds,
              repeat: reps,
              work: _distanceStep(StepType.interval, 400, paces.repetition),
              recovery: _distanceStep(StepType.recovery, 400, paces.easy),
              cooldownSeconds: fit.cooldownSeconds,
            ),
          );
        }

        final _Fitted fit = _fit(
          wantedReps: repsForShare(
            weekKm: weekKm,
            share: intervalShareOfWeek,
            fractionMeters: 1000,
            minReps: 3,
            maxReps: 7,
          ),
          minReps: 3,
          repSeconds: paces.interval.secondsPerKm + 0.4 * easySec,
          warmupSeconds: 900,
          cooldownSeconds: 600,
          budgetSeconds: budgetSeconds,
        );
        final int reps = fit.reps;
        return _QualitySession(
          kind: SessionKind.intervals,
          title: 'Ripetute $reps x 1000 m',
          detail: 'A ${formatPaceWithUnit(paces.interval.secondsPerKm)}, '
              'recupero 400 m lenti. E\' la seduta che alza il tetto: '
              'gli ultimi due devono costare.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Ripetute $reps x 1000 m',
            paces: paces,
            warmupSeconds: fit.warmupSeconds,
            repeat: reps,
            work: _distanceStep(StepType.interval, 1000, paces.interval),
            recovery: _distanceStep(StepType.recovery, 400, paces.easy),
            cooldownSeconds: fit.cooldownSeconds,
          ),
        );
        }

      case PlanPhase.peak:
        {
        if (slot == 0) {
          return _racePaceSession(
            idBase: idBase,
            goal: goal,
            paces: paces,
            vdot: vdot,
            budgetSeconds: budgetSeconds,
          );
        }
        final _Fitted fit = _fit(
          wantedReps: repsForShare(
            weekKm: weekKm,
            share: thresholdShareOfWeek,
            fractionMeters: 2000,
            minReps: 2,
            maxReps: 5,
          ),
          minReps: 2,
          repSeconds: 2 * paces.threshold.secondsPerKm + 120,
          warmupSeconds: 900,
          cooldownSeconds: 600,
          budgetSeconds: budgetSeconds,
        );
        final int reps = fit.reps;
        return _QualitySession(
          kind: SessionKind.threshold,
          title: 'Soglia $reps x 2000 m',
          detail: 'A ${formatPaceWithUnit(paces.threshold.secondsPerKm)}, '
              'recupero 2 minuti. Frazioni piu\' lunghe, stesso passo.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Soglia $reps x 2000 m',
            paces: paces,
            warmupSeconds: fit.warmupSeconds,
            repeat: reps,
            work: _distanceStep(StepType.interval, 2000, paces.threshold),
            recovery: _timeStep(StepType.recovery, 120, paces.easy),
            cooldownSeconds: fit.cooldownSeconds,
          ),
        );
        }

      case PlanPhase.taper:
        {
        final _Fitted fit = _fit(
          wantedReps: 6,
          minReps: 4,
          repSeconds: 0.4 * paces.repetition.secondsPerKm + 0.4 * easySec,
          warmupSeconds: 900,
          cooldownSeconds: 600,
          budgetSeconds: budgetSeconds,
        );
        final int reps = fit.reps;
        return _QualitySession(
          kind: SessionKind.repetitions,
          title: 'Richiamo $reps x 400 m',
          detail: 'A ${formatPaceWithUnit(paces.repetition.secondsPerKm)}, '
              'recupero 400 m. Poco volume: serve a tenere la gamba viva, '
              'non ad allenare.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Richiamo $reps x 400 m',
            paces: paces,
            warmupSeconds: fit.warmupSeconds,
            repeat: reps,
            work: _distanceStep(StepType.interval, 400, paces.repetition),
            recovery: _distanceStep(StepType.recovery, 400, paces.easy),
            cooldownSeconds: fit.cooldownSeconds,
          ),
        );
        }

      case PlanPhase.recovery:
        {
        // Non dovrebbe arrivarci: in recupero non si programma qualita'.
        final int totale = budgetSeconds == null
            ? 2700
            : budgetSeconds.clamp(900, 2700);
        return _QualitySession(
          kind: SessionKind.easy,
          title: 'Lento',
          detail: 'Solo corsa lenta.',
          workout: _buildWorkout(
            id: idBase,
            name: 'Lento',
            paces: paces,
            warmupSeconds: totale - 900,
            repeat: 1,
            work: _timeStep(StepType.run, 600, paces.easy),
            recovery: null,
            cooldownSeconds: 300,
          ),
        );
        }
    }
  }

  /// Seduta al passo della gara scelta: e' quello che rende "specifica" la
  /// fase finale.
  _QualitySession _racePaceSession({
    required String idBase,
    required RaceGoal goal,
    required TrainingPaces paces,
    required double vdot,
    int? budgetSeconds,
  }) {
    final double? meters = goal.meters;
    if (meters == null) {
      final _Fitted fit = _fit(
        wantedReps: 5,
        minReps: 3,
        repSeconds: paces.interval.secondsPerKm +
            0.4 * paces.easy.slowestSecPerKm,
        warmupSeconds: 900,
        cooldownSeconds: 600,
        budgetSeconds: budgetSeconds,
      );
      final int reps = fit.reps;
      return _QualitySession(
        kind: SessionKind.intervals,
        title: 'Ripetute $reps x 1000 m',
        detail: 'A ${formatPaceWithUnit(paces.interval.secondsPerKm)}, '
            'recupero 400 m lenti.',
        workout: _buildWorkout(
          id: idBase,
          name: 'Ripetute $reps x 1000 m',
          paces: paces,
          warmupSeconds: fit.warmupSeconds,
          repeat: reps,
          work: _distanceStep(StepType.interval, 1000, paces.interval),
          recovery: _distanceStep(StepType.recovery, 400, paces.easy),
          cooldownSeconds: fit.cooldownSeconds,
        ),
      );
    }

    final int? raceSeconds = fitness.predictSeconds(vdot, meters);
    final double racePace = raceSeconds == null
        ? paces.threshold.secondsPerKm
        : raceSeconds / (meters / 1000.0);
    final TrainingPace pace = TrainingPace(
      key: 'G',
      label: 'Passo gara',
      description: 'Il passo previsto per la tua ${goal.label}.',
      secondsPerKm: racePace,
      fastestSecPerKm: racePace - 4,
      slowestSecPerKm: racePace + 6,
    );

    // Frazioni lunghe per le gare lunghe, piu' corte e veloci per le brevi.
    late int reps;
    late double fraction;
    late int recoverySeconds;
    switch (goal) {
      case RaceGoal.fiveK:
        reps = 5;
        fraction = 1000;
        recoverySeconds = 120;
        break;
      case RaceGoal.tenK:
        reps = 4;
        fraction = 2000;
        recoverySeconds = 150;
        break;
      case RaceGoal.half:
        reps = 3;
        fraction = 4000;
        recoverySeconds = 180;
        break;
      case RaceGoal.marathon:
        reps = 2;
        fraction = 6000;
        recoverySeconds = 180;
        break;
      case RaceGoal.fitness:
        reps = 4;
        fraction = 1500;
        recoverySeconds = 120;
        break;
    }

    final _Fitted fit = _fit(
      wantedReps: reps,
      minReps: 2,
      repSeconds: fraction / 1000.0 * racePace + recoverySeconds,
      warmupSeconds: 900,
      cooldownSeconds: 600,
      budgetSeconds: budgetSeconds,
    );
    reps = fit.reps;

    return _QualitySession(
      kind: SessionKind.racePace,
      title: 'Passo gara $reps x ${formatDistanceAuto(fraction)}',
      detail: 'A ${formatPaceWithUnit(racePace)}, il passo previsto per la tua '
          '${goal.label}. Serve a farlo diventare naturale prima del giorno '
          'della gara.',
      workout: _buildWorkout(
        id: idBase,
        name: 'Passo gara $reps x ${formatDistanceAuto(fraction)}',
        paces: paces,
        warmupSeconds: fit.warmupSeconds,
        repeat: reps,
        work: _distanceStep(StepType.interval, fraction, pace),
        recovery: _timeStep(StepType.recovery, recoverySeconds, paces.easy),
        cooldownSeconds: fit.cooldownSeconds,
      ),
    );
  }

  // ------------------------------------------------------------- mattoni
  WorkoutStep _distanceStep(
    StepType type,
    double meters,
    TrainingPace pace,
  ) =>
      WorkoutStep(
        type: type,
        goalType: StepGoalType.distance,
        goalDistanceMeters: meters,
        paceTarget: pace.target,
      );

  WorkoutStep _timeStep(StepType type, int seconds, TrainingPace pace) =>
      WorkoutStep(
        type: type,
        goalType: StepGoalType.time,
        goalSeconds: seconds,
        paceTarget: pace.target,
      );

  /// Struttura standard: riscaldamento, blocco ripetuto, defaticamento.
  // ------------------------------------------------- quanto lavoro forte
  //
  // QUANTA QUALITA' CI STA IN UNA SETTIMANA
  //
  // La prima versione faceva crescere le ripetizioni con il numero della
  // settimana, fermandosi a un numero scelto da me (cinque frazioni di
  // soglia, sei ripetute). Arbitrario in tutti e due i sensi: troppo per chi
  // fa trenta chilometri, troppo poco per chi ne fa ottanta, e comunque fermo
  // dopo due mesi.
  //
  // Daniels lega il lavoro forte al volume settimanale, ed e' l'unico
  // criterio che scala da solo: la soglia non supera il 10% dei chilometri
  // della settimana, le ripetute l'8%, le veloci il 5%. Cosi' l'intensita'
  // cresce quando cresce il volume e si ferma dove si deve fermare - dove lo
  // dice la fisiologia, non dove l'avevo messa io.
  //
  // I limiti valgono sui metri di LAVORO, recuperi esclusi.
  static const double thresholdShareOfWeek = 0.10;
  static const double intervalShareOfWeek = 0.08;
  static const double repetitionShareOfWeek = 0.05;

  /// Quante ripetizioni da [fractionMeters] entrano nella quota [share] del
  /// volume settimanale, fra [minReps] e [maxReps].
  int repsForShare({
    required double weekKm,
    required double share,
    required double fractionMeters,
    required int minReps,
    required int maxReps,
  }) {
    if (weekKm <= 0 || fractionMeters <= 0) return minReps;
    final int reps = (weekKm * 1000.0 * share / fractionMeters).floor();
    return reps.clamp(minReps, maxReps);
  }

  /// Riscaldamento minimo. Sotto i dieci minuti il riscaldamento non riscalda:
  /// si arriva alla prima ripetuta freddi, che e' il modo classico di farsi
  /// male al soleo.
  static const int minWarmupSeconds = 600;

  /// Defaticamento minimo: cinque minuti.
  static const int minCooldownSeconds = 300;

  /// Adatta una seduta al tempo che c'e'.
  ///
  /// L'ORDINE DEI TAGLI E' UNA SCELTA
  /// --------------------------------
  /// Prima si accorciano riscaldamento e defaticamento, poi si togliono
  /// ripetizioni. Il motivo: fra "4 x 1000 con dieci minuti di riscaldamento"
  /// e "3 x 1000 con venti" la prima allena di piu'. Il contorno serve, ma il
  /// lavoro e' il lavoro.
  ///
  /// Sotto [minReps] non si scende: una seduta di due ripetute su tre non e'
  /// una seduta ridotta, e' un'altra seduta. Se non ci sta nemmeno cosi', la
  /// seduta resta piu' lunga del tempo dichiarato - meglio dirlo con una
  /// seduta che sfora che fingere un allenamento che non allena.
  _Fitted _fit({
    required int wantedReps,
    required int minReps,
    required double repSeconds,
    required int warmupSeconds,
    required int cooldownSeconds,
    required int? budgetSeconds,
  }) {
    if (budgetSeconds == null || budgetSeconds <= 0 || repSeconds <= 0) {
      return _Fitted(
        reps: wantedReps,
        warmupSeconds: warmupSeconds,
        cooldownSeconds: cooldownSeconds,
      );
    }

    int warmup = warmupSeconds;
    int cooldown = cooldownSeconds;
    int reps = wantedReps;

    double totale() => warmup + cooldown + reps * repSeconds;

    // 1. Il contorno, a scalini di un minuto: prima il defaticamento, che e'
    //    la parte piu' facile da recuperare camminando a casa.
    while (totale() > budgetSeconds &&
        (cooldown > minCooldownSeconds || warmup > minWarmupSeconds)) {
      if (cooldown > minCooldownSeconds) {
        cooldown = math.max(minCooldownSeconds, cooldown - 60);
      } else {
        warmup = math.max(minWarmupSeconds, warmup - 60);
      }
    }

    // 2. Poi le ripetizioni.
    while (totale() > budgetSeconds && reps > minReps) {
      reps--;
    }

    return _Fitted(
      reps: reps,
      warmupSeconds: warmup,
      cooldownSeconds: cooldown,
    );
  }

  Workout _buildWorkout({
    required String id,
    required String name,
    required TrainingPaces paces,
    required int warmupSeconds,
    required int repeat,
    required WorkoutStep work,
    required WorkoutStep? recovery,
    required int cooldownSeconds,
  }) {
    return Workout(
      id: id,
      name: name,
      blocks: <WorkoutBlock>[
        WorkoutBlock(
          id: '$id-warmup',
          steps: <WorkoutStep>[
            _timeStep(StepType.warmup, warmupSeconds, paces.easy),
          ],
        ),
        WorkoutBlock(
          id: '$id-main',
          repeat: repeat,
          steps: <WorkoutStep>[
            work,
            if (recovery != null) recovery,
          ],
        ),
        WorkoutBlock(
          id: '$id-cooldown',
          steps: <WorkoutStep>[
            _timeStep(StepType.cooldown, cooldownSeconds, paces.easy),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------- gare
  /// Inserisce le gare nel piano: alleggerisce prima, recupera dopo.
  ///
  /// E' la parte che serve quando salta fuori una gara non prevista. Il piano
  /// non viene rifatto: vengono solo ammorbidite le sedute intorno alla data.
  TrainingPlan _applyRaces(TrainingPlan plan, TrainingPaces paces) {
    final List<RaceEvent> races = plan.config.races;
    if (races.isEmpty) return plan;

    List<PlanWeek> weeks = plan.weeks;

    for (final RaceEvent race in races) {
      final DateTime raceDay = _dayOnly(race.date);
      final DateTime taperFrom =
          raceDay.subtract(Duration(days: race.taperDays));
      final DateTime recoveryTo =
          raceDay.add(Duration(days: race.recoveryDays));

      weeks = weeks.map((PlanWeek week) {
        bool touched = false;
        bool hasRace = false;

        final List<PlannedSession> updated = <PlannedSession>[];
        for (final PlannedSession session in week.sessions) {
          final DateTime day = _dayOnly(session.date);

          // Giorno di gara: la gara sostituisce qualunque seduta.
          if (day == raceDay) {
            hasRace = true;
            touched = true;
            updated.add(PlannedSession(
              date: session.date,
              kind: SessionKind.race,
              title: race.name,
              detail: 'Gara di ${formatDistanceAuto(race.meters)}. '
                  'Riscaldamento lento, poi dai quello che hai.',
              distanceMeters: race.meters,
            ));
            continue;
          }

          // Nei giorni prima: niente qualita', e il lungo si accorcia.
          if (!day.isBefore(taperFrom) && day.isBefore(raceDay)) {
            touched = true;
            if (session.isQuality) {
              updated.add(PlannedSession(
                date: session.date,
                kind: SessionKind.easy,
                title: 'Lento corto',
                detail: 'Qualita\' rimandata: hai la gara fra pochi giorni. '
                    'Arrivarci stanco costa piu\' di quanto renda una seduta.',
                distanceMeters: (session.distanceMeters ?? 8000) * 0.5,
              ));
            } else if (session.kind == SessionKind.long) {
              updated.add(session.copyWith(
                title: 'Lungo ridotto',
                detail: 'Accorciato per la gara in arrivo.',
                distanceMeters: (session.distanceMeters ?? 12000) * 0.6,
              ));
            } else {
              updated.add(session);
            }
            continue;
          }

          // Nei giorni dopo: solo lento, il corpo sta riparando.
          if (day.isAfter(raceDay) && !day.isAfter(recoveryTo)) {
            touched = true;
            if (session.isQuality) {
              updated.add(PlannedSession(
                date: session.date,
                kind: SessionKind.easy,
                title: 'Lento di recupero',
                detail: 'Dopo una gara il muscolo ripara per giorni. '
                    'Tornare sulla qualita\' subito e\' il modo piu\' comune '
                    'di farsi male.',
                distanceMeters: (session.distanceMeters ?? 8000) * 0.6,
              ));
            } else if (session.kind == SessionKind.long) {
              updated.add(session.copyWith(
                title: 'Lungo ridotto',
                detail: 'Ancora in recupero dalla gara.',
                distanceMeters: (session.distanceMeters ?? 12000) * 0.7,
              ));
            } else {
              updated.add(session);
            }
            continue;
          }

          updated.add(session);
        }

        if (!touched) return week;

        // Se nella settimana non c'era nessuna seduta il giorno della gara,
        // la gara va aggiunta.
        if (!hasRace &&
            !raceDay.isBefore(week.startDate) &&
            !raceDay.isAfter(week.endDate)) {
          updated.add(PlannedSession(
            date: raceDay,
            kind: SessionKind.race,
            title: race.name,
            detail: 'Gara di ${formatDistanceAuto(race.meters)}.',
            distanceMeters: race.meters,
          ));
          hasRace = true;
        }

        updated.sort((PlannedSession a, PlannedSession b) =>
            a.date.compareTo(b.date));

        final String note = hasRace
            ? 'Gara: ${race.name}'
            : (raceDay.isAfter(week.endDate)
                ? 'Alleggerita per la gara in arrivo'
                : 'Recupero dopo la gara');

        return week.copyWith(
          sessions: updated,
          note: note,
          phase: (!hasRace && raceDay.isBefore(week.startDate))
              ? PlanPhase.recovery
              : week.phase,
        );
      }).toList();
    }

    return TrainingPlan(config: plan.config, weeks: weeks);
  }

  // -------------------------------------------------------------- helper
  DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Data del giorno [weekday] (1 = lunedi') dentro la settimana che inizia a
  /// [weekStart].
  DateTime _dateOf(DateTime weekStart, int weekday) =>
      weekStart.add(Duration(days: weekday - 1));
}

/// Risultato interno: una seduta di qualita' pronta.
/// Una seduta adattata al tempo disponibile.
class _Fitted {
  const _Fitted({
    required this.reps,
    required this.warmupSeconds,
    required this.cooldownSeconds,
  });

  final int reps;
  final int warmupSeconds;
  final int cooldownSeconds;
}

class _QualitySession {
  const _QualitySession({
    required this.kind,
    required this.title,
    required this.detail,
    required this.workout,
  });

  final SessionKind kind;
  final String title;
  final String detail;
  final Workout workout;
}
