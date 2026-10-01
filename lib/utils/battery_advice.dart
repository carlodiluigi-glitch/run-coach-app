/// Dove cercare l'impostazione che spegne le app, marca per marca.
///
/// PERCHE' SERVE UN FILE SOLO PER QUESTO
/// -------------------------------------
/// Android ha un meccanismo standard per escludere un'app dal risparmio
/// energetico, e Falcata lo usa. Ma diversi produttori ci hanno messo sopra un
/// gestore loro, piu' aggressivo, che chiude le app anche quando il sistema
/// dice di non farlo. Xiaomi, Huawei, Oppo, Samsung: ognuno con un nome
/// diverso, in un posto diverso, e nessun modo di toccarlo da codice.
///
/// L'unica cosa onesta e' dire all'utente dove guardare. Un'istruzione
/// generica ("controlla le impostazioni della batteria") non la segue nessuno;
/// una che nomina la voce giusta si segue in trenta secondi.
///
/// Se la marca non e' fra queste, si danno le istruzioni generiche: sono
/// giuste per un Android senza aggiunte.
class BatteryAdvice {
  const BatteryAdvice._();

  /// `true` per le marche con un gestore energetico proprio, dove l'esenzione
  /// standard di Android non basta.
  static bool needsExtraSteps(String manufacturer) =>
      _extra.containsKey(_normalise(manufacturer));

  /// Le istruzioni per quella marca.
  static String stepsFor(String manufacturer) =>
      _extra[_normalise(manufacturer)] ?? _generic;

  /// Il nome da mostrare ("Xiaomi", "Samsung"...). Vuoto se non si sa.
  static String displayName(String manufacturer) {
    final String key = _normalise(manufacturer);
    if (key.isEmpty) return '';
    return key[0].toUpperCase() + key.substring(1);
  }

  static String _normalise(String value) {
    final String v = value.toLowerCase().trim();
    // Redmi e POCO sono Xiaomi, e hanno lo stesso gestore.
    if (v.contains('redmi') || v.contains('poco') || v.contains('xiaomi')) {
      return 'xiaomi';
    }
    if (v.contains('honor')) return 'honor';
    if (v.contains('huawei')) return 'huawei';
    if (v.contains('samsung')) return 'samsung';
    if (v.contains('oppo')) return 'oppo';
    if (v.contains('realme')) return 'realme';
    if (v.contains('vivo')) return 'vivo';
    if (v.contains('oneplus')) return 'oneplus';
    return '';
  }

  static const String _generic =
      'Apri le impostazioni di Falcata, vai su "Batteria" e scegli '
      '"Senza restrizioni" (o "Non ottimizzata").';

  /// VALORI DA VERIFICARE SUL CAMPO. I nomi delle voci cambiano fra versioni
  /// della stessa interfaccia: se una non si trova, va corretta qui.
  static const Map<String, String> _extra = <String, String>{
    'xiaomi':
        'Su Xiaomi, Redmi e POCO servono due cose, in due posti diversi.\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Senza restrizioni".\n'
            '2. Impostazioni di Falcata -> "Avvio automatico": accendilo.\n\n'
            'La seconda e\' quella che conta davvero: senza, il telefono '
            'chiude l\'app quando spegni lo schermo, anche durante la corsa.',
    'huawei':
        'Su Huawei:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Avvio app" -> '
            'passa a "Gestisci manualmente" e accendi tutte e tre le voci '
            '(avvio automatico, avvio secondario, esecuzione in background).\n'
            '2. Nelle impostazioni batteria del telefono, togli Falcata '
            'dalla chiusura automatica.',
    'honor':
        'Su Honor:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Avvio app" -> '
            '"Gestisci manualmente", e accendi tutte le voci.\n'
            '2. Controlla che Falcata non sia nella lista delle app da '
            'chiudere quando lo schermo si spegne.',
    'samsung':
        'Su Samsung:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Senza restrizioni".\n'
            '2. Impostazioni del telefono -> Batteria -> "Limiti di utilizzo '
            'in background": controlla che Falcata non sia fra le app '
            '"sospese" o "mai sospese" - deve stare fra quelle mai sospese.',
    'oppo':
        'Su Oppo:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Consenti attivita\' '
            'in background".\n'
            '2. Nel gestore delle app, accendi "Avvio automatico" per '
            'Falcata.',
    'realme':
        'Su Realme:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Consenti attivita\' '
            'in background".\n'
            '2. Accendi "Avvio automatico" per Falcata.',
    'vivo':
        'Su Vivo:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> consumo elevato in '
            'background: consentito.\n'
            '2. Accendi "Avvio automatico" per Falcata.',
    'oneplus':
        'Su OnePlus:\n\n'
            '1. Impostazioni di Falcata -> Batteria -> "Non ottimizzare".\n'
            '2. Nelle impostazioni batteria del telefono, spegni '
            '"Ottimizzazione avanzata" mentre usi l\'app per correre.',
  };
}
