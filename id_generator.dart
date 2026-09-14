import 'dart:math';

/// Generatore di identificativi univoci senza dipendenze esterne.
///
/// Combina il timestamp in millisecondi (base 36) con una parte casuale:
/// e' piu' che sufficiente per una app locale a utente singolo.
class IdGenerator {
  IdGenerator._();

  static final Random _random = Random();

  static String newId([String prefix = '']) {
    final String time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final String rand = _random.nextInt(0x7FFFFFFF).toRadixString(36);
    final String id = '$time$rand';
    return prefix.isEmpty ? id : '${prefix}_$id';
  }
}
