import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/running_shoe.dart';
import '../providers/shoe_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

/// Gestione delle scarpe da running.
class ShoesScreen extends StatelessWidget {
  const ShoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ShoeProvider provider = context.watch<ShoeProvider>();
    final List<RunningShoe> shoes = provider.shoes;

    return Scaffold(
      appBar: AppBar(title: const Text('Scarpe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nuova'),
      ),
      body: shoes.isEmpty
          ? EmptyState(
              icon: Icons.hiking,
              title: 'Nessuna scarpa inserita',
              message:
                  'Aggiungi le tue scarpe per tenere traccia dei chilometri percorsi con ognuna.',
              actionLabel: 'Aggiungi scarpa',
              onAction: () => _openEditor(context, null),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: shoes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) =>
                  _ShoeCard(shoe: shoes[index]),
            ),
    );
  }

  static Future<void> _openEditor(BuildContext context, RunningShoe? shoe) async {
    final RunningShoe? result = await showModalBottomSheet<RunningShoe>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => ShoeEditorSheet(initial: shoe),
    );
    if (result == null || !context.mounted) return;
    final ShoeProvider provider = context.read<ShoeProvider>();
    if (shoe == null) {
      await provider.add(result);
    } else {
      await provider.update(result);
    }
  }
}

class _ShoeCard extends StatelessWidget {
  const _ShoeCard({required this.shoe});

  final RunningShoe shoe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ShoeProvider provider = context.read<ShoeProvider>();
    final double? ratio = shoe.wearRatio;

    return AppCard(
      onTap: () => ShoesScreen._openEditor(context, shoe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      shoe.brand,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: scheme.primary,
                      ),
                    ),
                    Text(
                      shoe.model,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (String value) async {
                  if (value == 'edit') {
                    await ShoesScreen._openEditor(context, shoe);
                  } else if (value == 'retire') {
                    await provider.update(shoe.copyWith(retired: !shoe.retired));
                  } else if (value == 'delete') {
                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        title: const Text('Eliminare la scarpa?'),
                        content: Text(
                            '"${shoe.displayName}" verra rimossa. Le attivita gia salvate restano nello storico.'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Elimina'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await provider.remove(shoe.id);
                  }
                },
                itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                      value: 'edit', child: Text('Modifica')),
                  PopupMenuItem<String>(
                    value: 'retire',
                    child: Text(shoe.retired ? 'Rimetti in uso' : 'Metti a riposo'),
                  ),
                  const PopupMenuItem<String>(
                      value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                shoe.thresholdKm == null
                    ? '${shoe.totalKm.toStringAsFixed(0)} km'
                    : '${shoe.totalKm.toStringAsFixed(0)} / ${shoe.thresholdKm!.toStringAsFixed(0)} km',
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (shoe.retired)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('A riposo'),
                ),
            ],
          ),
          if (ratio != null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: ratio, minHeight: 8),
            ),
            if (shoe.isOverThreshold) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Soglia consigliata raggiunta: valuta la sostituzione.',
                style: TextStyle(fontSize: 13, color: scheme.error),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ShoeStat(
                  label: 'Corse',
                  value: '${shoe.runCount}',
                ),
              ),
              Expanded(
                child: _ShoeStat(
                  label: 'Primo utilizzo',
                  value: formatDateShort(shoe.firstUseDate),
                ),
              ),
              Expanded(
                child: _ShoeStat(
                  label: 'Ultimo utilizzo',
                  value: shoe.lastUsed == null
                      ? kEmptyValue
                      : formatDateShort(shoe.lastUsed!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShoeStat extends StatelessWidget {
  const _ShoeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Form di inserimento / modifica di una scarpa.
class ShoeEditorSheet extends StatefulWidget {
  const ShoeEditorSheet({super.key, this.initial});

  final RunningShoe? initial;

  @override
  State<ShoeEditorSheet> createState() => _ShoeEditorSheetState();
}

class _ShoeEditorSheetState extends State<ShoeEditorSheet> {
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _initialKm;
  late final TextEditingController _threshold;
  late DateTime _firstUse;
  String? _error;

  @override
  void initState() {
    super.initState();
    final RunningShoe? initial = widget.initial;
    _brand = TextEditingController(text: initial?.brand ?? '');
    _model = TextEditingController(text: initial?.model ?? '');
    _initialKm = TextEditingController(
      text: initial == null || initial.initialKm == 0
          ? ''
          : initial.initialKm.toStringAsFixed(0),
    );
    _threshold = TextEditingController(
      text: initial?.thresholdKm == null
          ? ''
          : initial!.thresholdKm!.toStringAsFixed(0),
    );
    _firstUse = initial?.firstUseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _initialKm.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.initial == null ? 'Nuova scarpa' : 'Modifica scarpa',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _brand,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Marca',
                hintText: 'ASICS',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Modello',
                hintText: 'Novablast 5',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _initialKm,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Km iniziali',
                      helperText: 'Opzionale',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _threshold,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Soglia km',
                      helperText: 'Opzionale',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Data primo utilizzo'),
              subtitle: Text(formatDateShort(_firstUse)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _pickDate,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('SALVA')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _firstUse,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _firstUse = picked);
  }

  void _submit() {
    final String brand = _brand.text.trim();
    final String model = _model.text.trim();
    if (brand.isEmpty && model.isEmpty) {
      setState(() => _error = 'Inserisci almeno la marca o il modello.');
      return;
    }

    final double initialKm = double.tryParse(_initialKm.text.trim()) ?? 0;
    final double? threshold = _threshold.text.trim().isEmpty
        ? null
        : double.tryParse(_threshold.text.trim());

    final RunningShoe? existing = widget.initial;
    final RunningShoe result = existing == null
        ? RunningShoe(
            brand: brand,
            model: model,
            firstUseDate: _firstUse,
            initialKm: initialKm,
            thresholdKm: threshold,
          )
        : existing.copyWith(
            brand: brand,
            model: model,
            firstUseDate: _firstUse,
            initialKm: initialKm,
            thresholdKm: threshold,
            clearThreshold: threshold == null,
          );

    Navigator.of(context).pop(result);
  }
}
