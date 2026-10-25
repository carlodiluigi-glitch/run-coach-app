import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/tokens.dart';
import '../models/effort.dart';
import '../models/running_activity.dart';
import '../models/running_shoe.dart';
import '../providers/activity_provider.dart';
import '../providers/shoe_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';

/// Aggiungere a mano una corsa che il GPS non ha visto.
///
/// A COSA SERVE DAVVERO
/// --------------------
/// Nasce per il tapis roulant, ma il tapis roulant e' solo il caso piu'
/// frequente. Lo stesso pulsante copre tutte le corse che esistono e che
/// l'applicazione non ha misurato:
///
///   - il nastro in palestra, d'inverno o quando fuori diluvia;
///   - una gara corsa senza telefono addosso;
///   - l'uscita in cui il GPS e' morto, o ti sei dimenticato di avviare;
///   - la corsa con un amico, col telefono rimasto in macchina.
///
/// Senza questa schermata quei chilometri sparivano, e sparivano nel posto
/// peggiore: il volume settimanale. Un piano che crede che tu abbia corso
/// trenta chilometri quando ne hai corsi cinquanta ti fa progredire troppo in
/// fretta, perche' calcola l'aumento su una base falsa.
///
/// COSA QUESTA SCHERMATA NON CHIEDE, DI PROPOSITO
/// ----------------------------------------------
/// Non chiede il passo: si ricava da durata e distanza, e farlo scrivere
/// vorrebbe dire permettere che i tre numeri non tornino fra loro.
///
/// Non chiede i parziali, la cadenza, il dislivello. Non ci sono. Una casella
/// vuota da riempire a mano produrrebbe un dato inventato con l'aspetto di un
/// dato misurato, ed e' il difetto che questa applicazione passa il tempo a
/// evitare.
class ManualRunScreen extends StatefulWidget {
  const ManualRunScreen({super.key});

  @override
  State<ManualRunScreen> createState() => _ManualRunScreenState();
}

class _ManualRunScreenState extends State<ManualRunScreen> {
  final TextEditingController _ore = TextEditingController();
  final TextEditingController _minuti = TextEditingController();
  final TextEditingController _secondi = TextEditingController();
  final TextEditingController _distanza = TextEditingController();
  final TextEditingController _nota = TextEditingController();

  DateTime _quando = DateTime.now();
  String? _scarpaId;
  int? _fatica;
  bool _salvataggioInCorso = false;
  String? _errore;

  @override
  void dispose() {
    _ore.dispose();
    _minuti.dispose();
    _secondi.dispose();
    _distanza.dispose();
    _nota.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ i conti
  /// La durata scritta, in secondi. `null` se non e' ancora utilizzabile.
  int? get _durataSecondi {
    final int h = int.tryParse(_ore.text.trim()) ?? 0;
    final int m = int.tryParse(_minuti.text.trim()) ?? 0;
    final int s = int.tryParse(_secondi.text.trim()) ?? 0;
    final int totale = h * 3600 + m * 60 + s;
    return totale > 0 ? totale : null;
  }

  /// I metri scritti. Accetta sia la virgola che il punto: su una tastiera
  /// italiana esce la virgola, e rifiutarla sarebbe solo pedanteria.
  double? get _metri {
    final String grezzo = _distanza.text.trim().replaceAll(',', '.');
    if (grezzo.isEmpty) return null;
    final double? km = double.tryParse(grezzo);
    if (km == null || km <= 0) return null;
    return km * 1000.0;
  }

  /// Il passo che viene fuori dai due numeri, in secondi al chilometro.
  double? get _passo {
    final int? secondi = _durataSecondi;
    final double? metri = _metri;
    if (secondi == null || metri == null || metri <= 0) return null;
    return secondi / (metri / 1000.0);
  }

  /// Perche' non si puo' ancora salvare. `null` quando si puo'.
  ///
  /// I limiti non sono burocrazia: sono i confini oltre i quali il numero non
  /// e' una corsa ma un errore di battitura, e un errore di battitura nel
  /// volume settimanale sballa il piano per settimane.
  String? get _perche {
    final int? secondi = _durataSecondi;
    final double? metri = _metri;
    if (secondi == null) return 'Manca la durata.';
    if (metri == null) return 'Manca la distanza.';
    if (metri < 300) return 'Meno di trecento metri non e\' una corsa.';
    if (metri > 200000) {
      return 'Duecento chilometri sono troppi: controlla la distanza.';
    }
    if (secondi > 24 * 3600) {
      return 'Piu\' di ventiquattro ore: controlla la durata.';
    }
    if (_quando.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return 'La data e\' nel futuro.';
    }

    final double? passo = _passo;
    if (passo != null) {
      // Due minuti al chilometro e' piu' veloce del record del mondo sui
      // 10.000; venti minuti al chilometro e' piu' lento di una passeggiata.
      // Fuori da li' il dato e' sbagliato, non eccezionale.
      if (passo < 120) {
        return 'Verrebbe un passo di ${formatPace(passo)} al km: '
            'controlla i numeri.';
      }
      if (passo > 1200) {
        return 'Verrebbe un passo di ${formatPace(passo)} al km: '
            'controlla i numeri.';
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ azioni
  Future<void> _scegliData() async {
    final DateTime adesso = DateTime.now();
    final DateTime? giorno = await showDatePicker(
      context: context,
      initialDate: _quando,
      firstDate: adesso.subtract(const Duration(days: 730)),
      lastDate: adesso,
      helpText: 'Quando hai corso',
    );
    if (giorno == null || !mounted) return;

    final TimeOfDay? ora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_quando),
      helpText: 'A che ora',
    );
    if (!mounted) return;

    setState(() {
      _quando = DateTime(
        giorno.year,
        giorno.month,
        giorno.day,
        ora?.hour ?? _quando.hour,
        ora?.minute ?? _quando.minute,
      );
    });
  }

  Future<void> _salva() async {
    final String? blocco = _perche;
    if (blocco != null) {
      setState(() => _errore = blocco);
      return;
    }

    setState(() {
      _salvataggioInCorso = true;
      _errore = null;
    });

    final int secondi = _durataSecondi!;
    final double metri = _metri!;
    final String nota = _nota.text.trim();

    // id, route e laps li mette il costruttore: un identificativo nuovo, un
    // tracciato vuoto e nessun parziale. Non ci sono, e non si inventano.
    final RunningActivity corsa = RunningActivity(
      startTime: _quando,
      name: 'Tapis roulant',
      type: ActivityType.treadmill,
      durationSeconds: secondi,
      distanceMeters: metri,
      shoeId: _scarpaId,
      note: nota.isEmpty ? null : nota,
      feedback: _fatica == null
          ? null
          : SessionFeedback(rpe: _fatica!, note: nota.isEmpty ? null : nota),
    );

    final bool ok = await context.read<ActivityProvider>().add(corsa);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _salvataggioInCorso = false;
        _errore = 'Non sono riuscito a salvare. Riprova.';
      });
      return;
    }

    Navigator.of(context).pop();
  }

  // ------------------------------------------------------------------ disegno
  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final List<RunningShoe> scarpe = context.watch<ShoeProvider>().shoes;
    final double? passo = _passo;
    final String? blocco = _perche;

    return Scaffold(
      appBar: AppBar(title: const Text('Aggiungi una corsa')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Il nastro, o il telefono rimasto a casa',
                    style: AppText.title.copyWith(color: p.ink)),
                const SizedBox(height: 8),
                Text(
                  'Durata e distanza le leggi dal display e le scrivi qui. '
                  'Questi chilometri contano nel volume della settimana, nel '
                  'carico e sul consumo delle scarpe.\n\n'
                  'Non toccano l\'indice di forma ne\' i passi del piano: '
                  'la distanza la dichiara il nastro, e un nastro tarato male '
                  'non si puo\' smascherare da qui.',
                  style: AppText.body.copyWith(color: p.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ------------------------------------------------------------ quando
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Quando', style: AppText.title.copyWith(color: p.ink)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _scegliData,
                  icon: const Icon(Icons.event),
                  label: Text(
                    '${formatDateShort(_quando)} - '
                    '${_quando.hour.toString().padLeft(2, '0')}:'
                    '${_quando.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ------------------------------------------------------------ durata
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Durata', style: AppText.title.copyWith(color: p.ink)),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(child: _numero(_ore, 'ore', 2)),
                    const SizedBox(width: 10),
                    Expanded(child: _numero(_minuti, 'minuti', 2)),
                    const SizedBox(width: 10),
                    Expanded(child: _numero(_secondi, 'secondi', 2)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // --------------------------------------------------------- distanza
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Distanza',
                    style: AppText.title.copyWith(color: p.ink)),
                const SizedBox(height: 10),
                TextField(
                  controller: _distanza,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(() => _errore = null),
                  decoration: const InputDecoration(
                    labelText: 'Chilometri',
                    hintText: '10,5',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ------------------------------------------------------- il riscontro
          //
          // Il passo non si chiede: si mostra. E' il controllo che fa vedere
          // all'atleta se ha sbagliato a digitare, prima di salvare.
          AppCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.speed, color: passo == null ? p.inkFaint : p.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    passo == null
                        ? 'Il passo compare qui appena scrivi durata e distanza.'
                        : 'Passo medio ${formatPaceWithUnit(passo)}',
                    style: AppText.body.copyWith(
                      color: passo == null ? p.inkFaint : p.ink,
                      fontWeight:
                          passo == null ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // --------------------------------------------------------- facoltativi
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Il resto, se ti va',
                    style: AppText.title.copyWith(color: p.ink)),
                const SizedBox(height: 4),
                Text('Si puo\' saltare tutto.',
                    style: AppText.caption.copyWith(color: p.inkFaint)),
                const SizedBox(height: 12),
                if (scarpe.isNotEmpty) ...<Widget>[
                  Text('Scarpe', style: AppText.body.copyWith(color: p.inkSoft)),
                  const SizedBox(height: 6),
                  DropdownButton<String?>(
                    value: _scarpaId,
                    isExpanded: true,
                    hint: const Text('Nessuna'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nessuna'),
                      ),
                      for (final RunningShoe s in scarpe)
                        DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (String? v) => setState(() => _scarpaId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Quanto e\' costata',
                    style: AppText.body.copyWith(color: p.inkSoft)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = PerceivedEffort.min;
                        i <= PerceivedEffort.max;
                        i++)
                      ChoiceChip(
                        label: Text('$i'),
                        selected: _fatica == i,
                        onSelected: (bool scelto) =>
                            setState(() => _fatica = scelto ? i : null),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nota,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nota',
                    hintText: 'Pendenza 1%, palestra',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),

          if (_errore != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(_errore!,
                style: AppText.body.copyWith(color: p.accent)),
          ],

          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                (blocco != null || _salvataggioInCorso) ? null : _salva,
            child: Text(_salvataggioInCorso ? 'Salvo...' : 'Salva la corsa'),
          ),
          if (blocco != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(blocco,
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: p.inkFaint)),
          ],
        ],
      ),
    );
  }

  Widget _numero(TextEditingController c, String etichetta, int cifre) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(cifre),
      ],
      onChanged: (_) => setState(() => _errore = null),
      decoration: InputDecoration(
        labelText: etichetta,
        hintText: '0',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
