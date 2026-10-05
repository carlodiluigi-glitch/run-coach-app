import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/tokens.dart';
import '../providers/activity_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shoe_provider.dart';
import '../providers/workout_provider.dart';
import '../services/native_bridge.dart';
import '../services/storage_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';

/// La copia di sicurezza dell'archivio.
///
/// PERCHE' E' LA MANCANZA PIU' GRAVE CHE L'APP AVESSE
/// --------------------------------------------------
/// Falcata tiene tutto nel telefono e non manda niente a nessuno. E' una
/// scelta, ed e' quella giusta: nessun account, nessun server, niente che
/// esca. Ma ha un prezzo, e finora l'ha pagato l'utente senza saperlo - **si
/// cambia telefono e sparisce tutto**. Anni di corse, i record, il piano.
///
/// Un archivio che non si puo' portare via non e' tuo: e' in prestito dal
/// telefono che hai adesso.
///
/// COME E' FATTA LA COPIA
/// ----------------------
/// Un file solo, in JSON leggibile. Non un formato chiuso: se un giorno
/// Falcata non esiste piu', quel file si apre lo stesso e dentro ci sono le
/// corse. E lo si mette dove si vuole - l'app apre il selettore di Android e
/// decide l'utente, cosi' la copia non finisce in un posto scelto da noi che
/// poi non si trova.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final NativeBridge _native = NativeBridge();
  final StorageService _storage = StorageService();

  bool _lavorando = false;
  String? _esito;
  bool _esitoBuono = true;

  @override
  Widget build(BuildContext context) {
    final AppPalette p = AppPalette.of(context);
    final ActivityProvider attivita = context.watch<ActivityProvider>();
    final int quante = attivita.activities.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Copia di sicurezza')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenSide,
            8,
            AppSpacing.screenSide,
            32,
          ),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    quante == 0
                        ? 'Non c\'e\' ancora niente da salvare'
                        : quante == 1
                            ? 'Una corsa nell\'archivio'
                            : '$quante corse nell\'archivio',
                    style: AppText.title.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Falcata tiene tutto nel telefono e non manda niente a '
                    'nessuno. E\' la scelta giusta, ma ha un prezzo: se cambi '
                    'telefono, o lo perdi, sparisce tutto.\n\n'
                    'La copia e\' un file solo, che metti dove vuoi tu: '
                    'mandatelo per email, su una chiavetta, su Drive. Dentro '
                    'c\'e\' testo leggibile, non un formato chiuso.',
                    style: AppText.body.copyWith(color: p.inkSoft),
                  ),
                ],
              ),
            ),

            const SectionTitle('Salvare'),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _lavorando || quante == 0 ? null : _salva,
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: p.onAccent,
                ),
                icon: const Icon(Icons.save_outlined, size: 19),
                label: const Text('Salva una copia'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                'Si apre il selettore di Android: scegli tu dove va a finire. '
                'Falla ogni tanto, e tienila in un posto che non sia solo '
                'questo telefono - una copia che sta accanto all\'originale '
                'non e\' una copia.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),

            const SectionTitle('Rimettere'),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _lavorando ? null : _ripristina,
                icon: const Icon(Icons.restore, size: 19),
                label: const Text('Rimetti da una copia'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8),
              child: Text(
                quante == 0
                    ? 'Scegli il file della copia: torna tutto com\'era.'
                    : 'Attenzione: quello che c\'e\' adesso nel telefono viene '
                        'sostituito da quello che c\'e\' nella copia. Se la '
                        'copia e\' vecchia, le corse fatte dopo si perdono.',
                style: AppText.caption.copyWith(
                  color: quante == 0 ? p.inkFaint : p.orange,
                ),
              ),
            ),

            if (_esito != null) ...<Widget>[
              const SizedBox(height: 20),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      _esitoBuono ? Icons.check_circle : Icons.error_outline,
                      size: 19,
                      color: _esitoBuono ? p.green : p.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _esito!,
                        style: AppText.body.copyWith(color: p.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),
            AppCard(
              child: Text(
                'Nella copia non finisce la corsa che stai registrando in '
                'questo momento: non fa ancora parte dell\'archivio, e '
                'rimetterla su un altro telefono farebbe comparire una corsa a '
                'meta\' che non hai mai fatto.',
                style: AppText.caption.copyWith(color: p.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salva() async {
    setState(() {
      _lavorando = true;
      _esito = null;
    });

    final String? contenuto =
        await _storage.exportBackup(appVersion: RunCoachApp.version);
    if (!mounted) return;

    if (contenuto == null) {
      setState(() {
        _lavorando = false;
        _esitoBuono = false;
        _esito = _storage.lastError ?? 'Copia non riuscita.';
      });
      return;
    }

    final DateTime ora = DateTime.now();
    final String nome = 'falcata-${ora.year}'
        '-${ora.month.toString().padLeft(2, '0')}'
        '-${ora.day.toString().padLeft(2, '0')}.json';

    final bool ok =
        await _native.saveTextFile(name: nome, content: contenuto);
    if (!mounted) return;

    setState(() {
      _lavorando = false;
      _esitoBuono = ok;
      _esito = ok
          ? 'Copia salvata come $nome. Tienila in un posto che non sia solo '
              'questo telefono.'
          : 'Non ho salvato niente.';
    });
  }

  Future<void> _ripristina() async {
    // La conferma si chiede PRIMA di aprire il selettore: dopo aver scelto il
    // file, l'utente ha gia' in testa che l'operazione e' partita, e una
    // domanda a quel punto si risponde senza leggerla.
    final bool? avanti = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Rimettere da una copia?'),
        content: const Text(
          'Quello che c\'e\' adesso nel telefono viene sostituito da quello '
          'che c\'e\' nella copia. Se la copia e\' vecchia, le corse fatte '
          'dopo si perdono.\n\n'
          'Se non sei sicuro, salva prima una copia di adesso.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Scegli il file'),
          ),
        ],
      ),
    );
    if (avanti != true || !mounted) return;

    setState(() {
      _lavorando = true;
      _esito = null;
    });

    final String? testo = await _native.openTextFile();
    if (!mounted) return;
    if (testo == null) {
      setState(() {
        _lavorando = false;
        _esitoBuono = false;
        _esito = 'Nessun file scelto. Non ho toccato niente.';
      });
      return;
    }

    final BackupReport report = await _storage.importBackup(testo);
    if (!mounted) return;

    if (!report.isOk) {
      setState(() {
        _lavorando = false;
        _esitoBuono = false;
        _esito = report.summary;
      });
      return;
    }

    // Tutto quello che e' in memoria adesso e' vecchio: si rilegge dal disco.
    // Senza questo, l'app continuerebbe a mostrare l'archivio di prima finche'
    // non viene riaperta, e sembrerebbe che il ripristino non abbia funzionato.
    if (!mounted) return;
    await context.read<SettingsProvider>().load();
    if (!mounted) return;
    await context.read<ActivityProvider>().load();
    if (!mounted) return;
    await context.read<ShoeProvider>().load();
    if (!mounted) return;
    await context.read<WorkoutProvider>().load();
    if (!mounted) return;
    await context.read<PlanProvider>().load();
    if (!mounted) return;

    final String quando = report.createdAt == null
        ? ''
        : ' (copia del ${formatDateShort(report.createdAt!)})';
    setState(() {
      _lavorando = false;
      _esitoBuono = true;
      _esito = '${report.summary}$quando';
    });
  }
}
