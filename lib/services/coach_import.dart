import 'dart:convert';

import '../models/coach_week.dart';
import '../models/running_activity.dart';
import '../models/training_plan.dart';
import '../models/weekly_availability.dart';
import '../models/workout.dart';
import '../models/workout_step.dart';
import '../utils/giorni.dart';
import 'coach_export.dart';
import 'pace_zone_engine.dart';

/// Legge il blocco che l'AI scrive alla fine della conversazione e lo
/// trasforma in una settimana di Falcata - dopo averla controllata.
///
/// L'AI PROPONE, IL MOTORE CONTROLLA
/// ---------------------------------
/// Il formato e' quello scritto in fondo al testo esportato
/// ([CoachExport.formatVersion]). Qui non si indovina niente: se un campo e'
/// sbagliato si dice quale e perche', e l'atleta chiede all'AI di
/// correggerlo. Un dato aggiustato a caso sarebbe peggio di un errore.
///
/// I controlli sono di due tipi:
///
///  - DA CORREGGERE: le regole che il piano non viola mai - due sedute di
///    qualita' in giorni attaccati, qualita' il giorno prima del lungo, due
///    sedute nello stesso giorno. Finche' ci sono, la settimana non entra.
///  - AVVISI: cose da guardare, non sbagliate per forza - un giorno che non
///    hai, una seduta piu' lunga del tempo che hai, un carico che sale molto,
///    un passo piu' veloce delle tue zone. Si possono confermare lo stesso.
class CoachImport {
  const CoachImport();

  /// Sopra questo aumento sul volume medio delle ultime quattro settimane,
  /// il carico sale troppo in fretta.
  static const double maxVolumeJump = 0.30;

  /// Quanto si puo' andare piu' veloci della zona piu' veloce prima che sia
  /// un avviso: il 3%.
  static const double paceMargin = 0.03;

  static const Map<String, SessionKind> _tipiSeduta = <String, SessionKind>{
    'lento': SessionKind.easy,
    'lungo': SessionKind.long,
    'soglia': SessionKind.threshold,
    'ripetute': SessionKind.intervals,
    'veloci': SessionKind.repetitions,
    'passo_gara': SessionKind.racePace,
    'fartlek': SessionKind.fartlek,
    'gara': SessionKind.race,
  };

  static const Map<String, StepType> _tipiPasso = <String, StepType>{
    'riscaldamento': StepType.warmup,
    'corsa': StepType.run,
    'lavoro': StepType.interval,
    'recupero': StepType.recovery,
    'defaticamento': StepType.cooldown,
  };

  // ------------------------------------------------------------- lettura
  /// Legge il testo incollato. Accetta tutta la risposta dell'AI: il blocco
  /// viene cercato fra i due segni.
  CoachImportResult parse(String testo, {required DateTime now}) {
    final String? blocco = _estrai(testo);
    if (blocco == null) {
      if (RegExp(r'===FALCATA-SETTIMANA-\d+===').hasMatch(testo)) {
        return CoachImportResult.error(
            'Il blocco e\' di una versione diversa del formato. Chiedi '
            'all\'AI di riscriverlo esattamente come nelle istruzioni.');
      }
      return CoachImportResult.error(
          'Non trovo il blocco. Deve cominciare con '
          '${CoachExport.inizioBlocco} e finire con ${CoachExport.fineBlocco}.');
    }

    final Object? json;
    try {
      json = jsonDecode(blocco);
    } catch (_) {
      return CoachImportResult.error(
          'Il blocco non e\' scritto bene (non e\' JSON valido). Chiedi '
          'all\'AI di riscriverlo, senza testo dentro i due segni.');
    }
    if (json is! Map) {
      return CoachImportResult.error('Il blocco non ha la forma attesa.');
    }
    final Map<String, dynamic> m = json.cast<String, dynamic>();

    final List<String> errori = <String>[];

    // --- la settimana
    final DateTime? dal = _data(m['settimana_dal']);
    if (dal == null) {
      return CoachImportResult.error(
          '"settimana_dal" manca o non e\' una data (AAAA-MM-GG).');
    }
    if (giorniFra(dal, soloGiorno(now)) > 6) {
      errori.add('La settimana del ${_g(dal)} e\' gia\' passata.');
    }

    final String decisione = (m['decisione'] as String? ?? '').trim();
    const List<String> decisioni = <String>[
      'conferma',
      'alleggerisci',
      'aumenta',
      'cambia',
    ];
    if (!decisioni.contains(decisione)) {
      errori.add('"decisione" deve essere conferma, alleggerisci, aumenta '
          'o cambia.');
    }
    final String motivo = (m['motivo'] as String? ?? '').trim();

    // --- le sedute
    final List<PlannedSession> sedute = <PlannedSession>[];
    final Object? rawSedute = m['sedute'];
    if (rawSedute is! List) {
      errori.add('"sedute" manca o non e\' un elenco.');
    } else {
      for (int i = 0; i < rawSedute.length; i++) {
        final Object? r = rawSedute[i];
        final String dove = 'Seduta ${i + 1}';
        if (r is! Map) {
          errori.add('$dove: non ha la forma attesa.');
          continue;
        }
        final PlannedSession? s =
            _seduta(r.cast<String, dynamic>(), dal, dove, errori);
        if (s != null) sedute.add(s);
      }
    }
    sedute.sort((PlannedSession a, PlannedSession b) =>
        a.date.compareTo(b.date));

    // --- i riepiloghi
    final List<CoachSummary> riepiloghi = <CoachSummary>[];
    final Object? rawRiep = m['riepiloghi'];
    if (rawRiep is List) {
      for (final Object? r in rawRiep) {
        if (r is! Map) continue;
        final String id = (r['corsa'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        riepiloghi.add(CoachSummary(
          activityId: id,
          feelings: (r['sensazioni'] ?? '').toString().trim(),
          limiter: (r['limite'] ?? 'non noto').toString().trim(),
          couldContinue: (r['avrebbe_continuato'] ?? 'non noto')
              .toString()
              .trim(),
        ));
      }
    }

    if (errori.isNotEmpty) return CoachImportResult.errors(errori);

    return CoachImportResult.ok(
      CoachWeek(
        from: dal,
        decision: decisione,
        reason: motivo,
        sessions: sedute,
        importedAt: now,
      ),
      riepiloghi,
    );
  }

  PlannedSession? _seduta(
    Map<String, dynamic> j,
    DateTime dal,
    String dove,
    List<String> errori,
  ) {
    final DateTime? data = _data(j['data']);
    if (data == null) {
      errori.add('$dove: "data" manca o non e\' una data.');
      return null;
    }
    final int g = giorniFra(dal, data);
    if (g < 0 || g > 6) {
      errori.add('$dove: il ${_g(data)} e\' fuori dalla settimana.');
      return null;
    }
    final SessionKind? tipo = _tipiSeduta[(j['tipo'] as String? ?? '').trim()];
    if (tipo == null) {
      errori.add('$dove (${_g(data)}): tipo "${j['tipo']}" non previsto.');
      return null;
    }
    final String titolo = (j['titolo'] as String? ?? '').trim().isEmpty
        ? tipo.label
        : (j['titolo'] as String).trim();

    final Object? rawFasi = j['fasi'];
    if (rawFasi is! List || rawFasi.isEmpty) {
      errori.add('$dove (${_g(data)}): mancano le fasi.');
      return null;
    }
    final List<WorkoutBlock> blocchi = <WorkoutBlock>[];
    for (int f = 0; f < rawFasi.length; f++) {
      final Object? rf = rawFasi[f];
      final String doveF = '$dove (${_g(data)}), fase ${f + 1}';
      if (rf is! Map) {
        errori.add('$doveF: non ha la forma attesa.');
        return null;
      }
      final int ripeti = (rf['ripeti'] as num?)?.toInt() ?? 1;
      if (ripeti < 1 || ripeti > 30) {
        errori.add('$doveF: "ripeti" deve stare fra 1 e 30.');
        return null;
      }
      final Object? rawPassi = rf['passi'];
      if (rawPassi is! List || rawPassi.isEmpty) {
        errori.add('$doveF: mancano i passi.');
        return null;
      }
      final List<WorkoutStep> passi = <WorkoutStep>[];
      for (final Object? rp in rawPassi) {
        if (rp is! Map) {
          errori.add('$doveF: un passo non ha la forma attesa.');
          return null;
        }
        final WorkoutStep? st =
            _passo(rp.cast<String, dynamic>(), doveF, errori);
        if (st == null) return null;
        passi.add(st);
      }
      blocchi.add(WorkoutBlock(repeat: ripeti, steps: passi));
    }

    final Workout w = Workout(name: titolo, blocks: blocchi);
    return PlannedSession(
      date: soloGiorno(data),
      kind: tipo,
      title: titolo,
      detail: describe(w),
      distanceMeters: w.estimatedMeters,
      durationSeconds: w.estimatedSeconds,
      workout: w,
    );
  }

  WorkoutStep? _passo(
    Map<String, dynamic> j,
    String dove,
    List<String> errori,
  ) {
    final StepType? tipo = _tipiPasso[(j['tipo'] as String? ?? '').trim()];
    if (tipo == null) {
      errori.add('$dove: tipo di passo "${j['tipo']}" non previsto.');
      return null;
    }
    final num? metri = j['metri'] as num?;
    final num? secondi = j['secondi'] as num?;
    if ((metri == null) == (secondi == null)) {
      errori.add('$dove: ogni passo vuole "metri" oppure "secondi", uno solo.');
      return null;
    }
    if (metri != null && (metri < 50 || metri > 50000)) {
      errori.add('$dove: $metri metri non e\' una distanza plausibile.');
      return null;
    }
    if (secondi != null && (secondi < 10 || secondi > 14400)) {
      errori.add('$dove: $secondi secondi non e\' una durata plausibile.');
      return null;
    }
    final double? da = _passoKm(j['passo_da']);
    final double? a = _passoKm(j['passo_a']);
    if ((j['passo_da'] != null && da == null) ||
        (j['passo_a'] != null && a == null)) {
      errori.add('$dove: il passo va scritto min:sec, fra 2:30 e 12:00.');
      return null;
    }
    PaceTarget? target;
    if (da != null || a != null) {
      final double x = da ?? a!;
      final double y = a ?? da!;
      target = PaceTarget(
        fastestSecPerKm: x < y ? x : y,
        slowestSecPerKm: x < y ? y : x,
      );
    }
    return WorkoutStep(
      type: tipo,
      goalType: metri != null ? StepGoalType.distance : StepGoalType.time,
      goalDistanceMeters: metri?.toDouble() ?? 1000,
      goalSeconds: secondi?.toInt() ?? 300,
      paceTarget: target,
    );
  }

  // ------------------------------------------------------------ controlli
  /// I controlli del motore sulla settimana letta.
  List<CoachCheck> check({
    required CoachWeek week,
    required List<RunningActivity> activities,
    TrainingPlan? plan,
    TrainingZones? zones,
  }) {
    final List<CoachCheck> out = <CoachCheck>[];
    final List<PlannedSession> s = week.sessions;

    // Due sedute nello stesso giorno.
    for (int i = 1; i < s.length; i++) {
      if (giorniFra(s[i - 1].date, s[i].date) == 0) {
        out.add(CoachCheck.block('Due sedute il ${_g(s[i].date)}: il piano ne '
            'prevede una al giorno.'));
      }
    }

    // Qualita' attaccate, qualita' prima del lungo.
    for (int i = 1; i < s.length; i++) {
      final PlannedSession prima = s[i - 1];
      final PlannedSession dopo = s[i];
      if (giorniFra(prima.date, dopo.date) != 1) continue;
      if (prima.isQuality && dopo.isQuality) {
        out.add(CoachCheck.block('Due sedute di qualita\' attaccate '
            '(${_g(prima.date)} e ${_g(dopo.date)}): fra due sedute dure ci '
            'vuole almeno un giorno facile.'));
      }
      if (prima.isQuality && dopo.kind == SessionKind.long) {
        out.add(CoachCheck.block('Qualita\' il giorno prima del lungo '
            '(${_g(prima.date)}): il lungo va fatto con le gambe fresche.'));
      }
    }

    // Giorni e minuti disponibili.
    final PlanConfig? config = plan?.config;
    if (config != null) {
      for (final PlannedSession x in s) {
        final PlanWeek? w = plan!.weekFor(x.date);
        final WeeklyAvailability disp = w == null
            ? config.availabilityForWeek(1)
            : config.availabilityForWeek(w.number);
        final int giorno = x.date.weekday;
        if (!disp.runsOn(giorno)) {
          out.add(CoachCheck.warn('${_gMaiusc(x.date)} non e\' fra i giorni in cui '
              'hai detto di poter correre.'));
        } else {
          final int minuti = disp.minutesOn(giorno);
          final int servono = ((x.durationSeconds ?? 0) / 60).round();
          if (minuti > 0 && servono > minuti * 1.1) {
            out.add(CoachCheck.warn('${_gMaiusc(x.date)}: la seduta dura circa '
                '$servono minuti, ne hai $minuti.'));
          }
        }
      }
    }

    // Il carico: chilometri contro la media delle ultime quattro settimane.
    final double kmSettimana = s.fold<double>(
            0, (double t, PlannedSession x) => t + (x.distanceMeters ?? 0)) /
        1000.0;
    final DateTime lunedi = piuGiorni(week.from, -(week.from.weekday - 1));
    double kmPrima = 0;
    for (final RunningActivity a in activities) {
      final int g = giorniFra(a.startTime, lunedi);
      if (g >= 1 && g <= 28) kmPrima += a.distanceMeters / 1000.0;
    }
    final double media = kmPrima / 4.0;
    if (media >= 10 && kmSettimana > media * (1 + maxVolumeJump)) {
      out.add(CoachCheck.warn('Circa ${kmSettimana.round()} km contro una '
          'media di ${media.round()} nelle ultime quattro settimane: '
          'il carico sale di oltre il ${(maxVolumeJump * 100).round()}%.'));
    }

    // Passi piu' veloci delle zone.
    if (zones != null) {
      double piuVeloce = double.infinity;
      for (final ZonePace z in zones.all) {
        if (z.range.low < piuVeloce) piuVeloce = z.range.low;
      }
      if (piuVeloce.isFinite) {
        for (final PlannedSession x in s) {
          for (final WorkoutBlock b in x.workout?.blocks ?? <WorkoutBlock>[]) {
            for (final WorkoutStep st in b.steps) {
              final double? f = st.paceTarget?.fastestSecPerKm;
              if (f != null && f < piuVeloce * (1 - paceMargin)) {
                out.add(CoachCheck.warn('${_gMaiusc(x.date)}: passo ${_mmss(f)}, '
                    'piu\' veloce della tua zona piu\' veloce '
                    '(${_mmss(piuVeloce)}).'));
              }
            }
          }
        }
      }
    }

    final int qualita = s.where((PlannedSession x) => x.isQuality).length;
    if (qualita > 3) {
      out.add(CoachCheck.warn('$qualita sedute di qualita\' in una '
          'settimana: di solito ne bastano due.'));
    }

    return out;
  }

  // ------------------------------------------------------------- utilita'
  /// La seduta a parole: "15:00 riscaldamento + 5 x (1.00 km a 4:15-4:20
  /// + 2:00 recupero) + 10:00 defaticamento".
  static String describe(Workout w) {
    final List<String> parti = <String>[];
    for (final WorkoutBlock b in w.blocks) {
      final String passi = b.steps.map((WorkoutStep s) {
        final String quanto = s.isDistanceBased
            ? (s.goalDistanceMeters < 1000
                ? '${s.goalDistanceMeters.round()} m'
                : '${(s.goalDistanceMeters / 1000).toStringAsFixed(2)} km')
            : _durata(s.goalSeconds);
        final PaceTarget? t = s.paceTarget;
        final String ritmo = t == null
            ? ''
            : ' a ${_mmss(t.fastestSecPerKm)}-${_mmss(t.slowestSecPerKm)}';
        return '$quanto ${s.type.label.toLowerCase()}$ritmo';
      }).join(' + ');
      parti.add(b.repeat > 1 ? '${b.repeat} x ($passi)' : passi);
    }
    return parti.join(' + ');
  }

  static String? _estrai(String testo) {
    final int i = testo.indexOf(CoachExport.inizioBlocco);
    if (i < 0) return null;
    final int da = i + CoachExport.inizioBlocco.length;
    final int f = testo.indexOf(CoachExport.fineBlocco, da);
    if (f < 0) return null;
    String dentro = testo.substring(da, f).trim();
    // Le chat a volte chiudono il blocco fra tre apici inversi.
    dentro = dentro.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
    dentro = dentro.replaceAll(RegExp(r'\s*```$'), '');
    return dentro.trim();
  }

  static DateTime? _data(Object? v) {
    if (v is! String) return null;
    final RegExpMatch? m =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final int y = int.parse(m.group(1)!);
    final int mo = int.parse(m.group(2)!);
    final int d = int.parse(m.group(3)!);
    final DateTime out = DateTime(y, mo, d);
    // 2026-02-30 diventerebbe il 2 marzo: no.
    if (out.month != mo || out.day != d) return null;
    return out;
  }

  static double? _passoKm(Object? v) {
    if (v == null) return null;
    final RegExpMatch? m =
        RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.toString().trim());
    if (m == null) return null;
    final int sec = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    if (int.parse(m.group(2)!) > 59 || sec < 150 || sec > 720) return null;
    return sec.toDouble();
  }

  static String _mmss(double? s) {
    if (s == null) return '?';
    final int x = s.round();
    return '${x ~/ 60}:${(x % 60).toString().padLeft(2, '0')}';
  }

  static String _durata(int secondi) {
    final int m = secondi ~/ 60;
    final int s = secondi % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static const List<String> _nomi = <String>[
    'lunedi\'',
    'martedi\'',
    'mercoledi\'',
    'giovedi\'',
    'venerdi\'',
    'sabato',
    'domenica',
  ];

  static String _g(DateTime d) => '${_nomi[d.weekday - 1]} ${d.day}/${d.month}';

  static String _gMaiusc(DateTime d) {
    final String x = _g(d);
    return '${x[0].toUpperCase()}${x.substring(1)}';
  }
}

/// Il riassunto di una corsa scritto dall'AI dopo averne parlato.
///
/// Resta separato dalle note dell'atleta: quelle sono parole sue, questo e'
/// un'interpretazione. Il testo per il coach lo dice.
class CoachSummary {
  const CoachSummary({
    required this.activityId,
    required this.feelings,
    required this.limiter,
    required this.couldContinue,
  });

  final String activityId;
  final String feelings;
  final String limiter;
  final String couldContinue;

  /// Una riga sola, da salvare sulla corsa.
  String get asText {
    final List<String> parti = <String>[
      if (feelings.isNotEmpty) feelings,
      'Limite: ${limiter.isEmpty ? 'non noto' : limiter}.',
      'Avrebbe continuato: '
          '${couldContinue.isEmpty ? 'non noto' : couldContinue}.',
    ];
    return parti.join(' ');
  }
}

class CoachCheck {
  const CoachCheck.block(this.message) : blocking = true;
  const CoachCheck.warn(this.message) : blocking = false;

  final String message;

  /// `true` = da correggere prima di confermare.
  final bool blocking;
}

class CoachImportResult {
  const CoachImportResult.ok(CoachWeek this.week, this.summaries)
      : errors = const <String>[];
  CoachImportResult.error(String message)
      : week = null,
        summaries = const <CoachSummary>[],
        errors = <String>[message];
  const CoachImportResult.errors(this.errors)
      : week = null,
        summaries = const <CoachSummary>[];

  final CoachWeek? week;
  final List<CoachSummary> summaries;
  final List<String> errors;

  bool get isOk => week != null;
}
