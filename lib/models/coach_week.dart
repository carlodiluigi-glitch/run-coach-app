import '../utils/giorni.dart';
import 'training_plan.dart';
import 'workout.dart';

/// Una settimana concordata con il coach (un'AI) e importata in Falcata.
///
/// Non tocca il piano: il piano si ricalcola a ogni avvio dalle sue regole,
/// e questa settimana gli si appoggia sopra, giorno per giorno. Per i sette
/// giorni da [from] valgono le sedute del coach; fuori, quelle del piano.
/// Cancellarla riporta la settimana del piano esattamente com'era.
class CoachWeek {
  const CoachWeek({
    required this.from,
    required this.decision,
    required this.reason,
    required this.sessions,
    required this.importedAt,
  });

  /// Il primo dei sette giorni coperti, a mezzanotte.
  final DateTime from;

  /// conferma | alleggerisci | aumenta | cambia
  final String decision;

  /// Il perche', con le parole del coach.
  final String reason;

  final List<PlannedSession> sessions;

  final DateTime importedAt;

  DateTime get to => piuGiorni(from, 6);

  /// `true` se [day] cade nei sette giorni di questa settimana.
  bool covers(DateTime day) {
    final int g = giorniFra(from, day);
    return g >= 0 && g <= 6;
  }

  String get decisionLabel {
    switch (decision) {
      case 'conferma':
        return 'Confermata';
      case 'alleggerisci':
        return 'Alleggerita';
      case 'aumenta':
        return 'Aumentata';
      default:
        return 'Cambiata';
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'from': _iso(from),
        'decision': decision,
        'reason': reason,
        'importedAt': importedAt.toIso8601String(),
        'sessions': sessions.map(_sessionToJson).toList(),
      };

  static CoachWeek? fromJson(Map<String, dynamic> json) {
    final DateTime? from = DateTime.tryParse(json['from'] as String? ?? '');
    if (from == null) return null;
    final List<PlannedSession> sedute = <PlannedSession>[];
    for (final Object? raw in (json['sessions'] as List<dynamic>?) ?? <dynamic>[]) {
      if (raw is! Map) continue;
      final PlannedSession? s = _sessionFromJson(raw.cast<String, dynamic>());
      if (s != null) sedute.add(s);
    }
    return CoachWeek(
      from: soloGiorno(from),
      decision: json['decision'] as String? ?? 'cambia',
      reason: json['reason'] as String? ?? '',
      sessions: sedute,
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static Map<String, dynamic> _sessionToJson(PlannedSession s) =>
      <String, dynamic>{
        'date': _iso(s.date),
        'kind': s.kind.name,
        'title': s.title,
        'detail': s.detail,
        if (s.distanceMeters != null) 'meters': s.distanceMeters,
        if (s.durationSeconds != null) 'seconds': s.durationSeconds,
        if (s.workout != null) 'workout': s.workout!.toJson(),
      };

  static PlannedSession? _sessionFromJson(Map<String, dynamic> j) {
    final DateTime? date = DateTime.tryParse(j['date'] as String? ?? '');
    if (date == null) return null;
    SessionKind kind = SessionKind.easy;
    for (final SessionKind k in SessionKind.values) {
      if (k.name == j['kind']) kind = k;
    }
    final Object? w = j['workout'];
    return PlannedSession(
      date: soloGiorno(date),
      kind: kind,
      title: j['title'] as String? ?? kind.label,
      detail: j['detail'] as String? ?? '',
      distanceMeters: (j['meters'] as num?)?.toDouble(),
      durationSeconds: (j['seconds'] as num?)?.toInt(),
      workout:
          w is Map ? Workout.fromJson(w.cast<String, dynamic>()) : null,
    );
  }

  static String _due(int n) => n.toString().padLeft(2, '0');
  static String _iso(DateTime d) =>
      '${d.year}-${_due(d.month)}-${_due(d.day)}';
}
