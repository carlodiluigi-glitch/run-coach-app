import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/workout.dart';
import '../models/workout_step.dart';
import '../providers/workout_provider.dart';
import '../utils/formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/workout_step_widget.dart';

/// Editor di allenamenti personalizzati.
///
/// L'utente lavora su BLOCCHI: un blocco puo' essere ripetuto N volte, quindi
/// "10 x (400 m + 200 m)" sono due sole righe da compilare, non venti.
class WorkoutBuilderScreen extends StatefulWidget {
  const WorkoutBuilderScreen({super.key, this.existing});

  /// Allenamento da modificare. `null` = nuovo allenamento.
  final Workout? existing;

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late final TextEditingController _nameController;
  late List<WorkoutBlock> _blocks;

  @override
  void initState() {
    super.initState();
    final Workout? existing = widget.existing;
    _nameController =
        TextEditingController(text: existing?.name ?? 'Nuovo allenamento');
    _blocks = existing == null
        ? <WorkoutBlock>[]
        : existing.blocks
            .map((WorkoutBlock b) => b.copyWith(
                  steps: List<WorkoutStep>.from(b.steps),
                ))
            .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _totalSteps {
    int total = 0;
    for (final WorkoutBlock b in _blocks) {
      total += b.steps.length * (b.repeat < 1 ? 1 : b.repeat);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'Nuovo allenamento'
            : 'Modifica allenamento'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('SALVA'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: <Widget>[
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome allenamento',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              color: scheme.surfaceContainerHigh,
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Un blocco puo essere ripetuto piu volte: imposta le ripetizioni con l\'icona a forma di frecce circolari.',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle('Blocchi'),
            if (_blocks.isEmpty)
              AppCard(
                child: Column(
                  children: <Widget>[
                    Text(
                      'Nessun blocco. Aggiungi il primo per iniziare.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _addBlock,
                      icon: const Icon(Icons.add),
                      label: const Text('Aggiungi blocco'),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < _blocks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WorkoutBlockCard(
                    block: _blocks[i],
                    index: i,
                    onEditRepeat: () => _editRepeat(i),
                    onAddStep: () => _addStep(i),
                    onDeleteBlock: () => _deleteBlock(i),
                    onMoveUp: i == 0 ? null : () => _moveBlock(i, -1),
                    onMoveDown:
                        i == _blocks.length - 1 ? null : () => _moveBlock(i, 1),
                    onEditStep: (int s) => _editStep(i, s),
                    onDeleteStep: (int s) => _deleteStep(i, s),
                    onMoveStepUp: (int s) => _moveStep(i, s, -1),
                    onMoveStepDown: (int s) => _moveStep(i, s, 1),
                  ),
                ),
            if (_blocks.isNotEmpty) ...<Widget>[
              OutlinedButton.icon(
                onPressed: _addBlock,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi blocco'),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.timeline, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Totale: $_totalSteps fasi da eseguire.',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- azioni
  void _addBlock() {
    setState(() {
      _blocks = <WorkoutBlock>[
        ..._blocks,
        WorkoutBlock(repeat: 1, steps: <WorkoutStep>[]),
      ];
    });
  }

  void _deleteBlock(int index) {
    setState(() {
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      next.removeAt(index);
      _blocks = next;
    });
  }

  void _moveBlock(int index, int delta) {
    final int target = index + delta;
    if (target < 0 || target >= _blocks.length) return;
    setState(() {
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      final WorkoutBlock item = next.removeAt(index);
      next.insert(target, item);
      _blocks = next;
    });
  }

  Future<void> _editRepeat(int index) async {
    final int current = _blocks[index].repeat;
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => _RepeatDialog(initial: current),
    );
    if (value == null) return;
    setState(() {
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      next[index] = next[index].copyWith(repeat: value);
      _blocks = next;
    });
  }

  Future<void> _addStep(int blockIndex) async {
    final WorkoutStep? step = await showModalBottomSheet<WorkoutStep>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => const StepEditorSheet(),
    );
    if (step == null) return;
    setState(() {
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      final List<WorkoutStep> steps =
          List<WorkoutStep>.from(next[blockIndex].steps)..add(step);
      next[blockIndex] = next[blockIndex].copyWith(steps: steps);
      _blocks = next;
    });
  }

  Future<void> _editStep(int blockIndex, int stepIndex) async {
    final WorkoutStep original = _blocks[blockIndex].steps[stepIndex];
    final WorkoutStep? step = await showModalBottomSheet<WorkoutStep>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StepEditorSheet(initial: original),
    );
    if (step == null) return;
    setState(() {
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      final List<WorkoutStep> steps =
          List<WorkoutStep>.from(next[blockIndex].steps);
      steps[stepIndex] = step;
      next[blockIndex] = next[blockIndex].copyWith(steps: steps);
      _blocks = next;
    });
  }

  void _deleteStep(int blockIndex, int stepIndex) {
    setState(() {
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      final List<WorkoutStep> steps =
          List<WorkoutStep>.from(next[blockIndex].steps);
      steps.removeAt(stepIndex);
      next[blockIndex] = next[blockIndex].copyWith(steps: steps);
      _blocks = next;
    });
  }

  void _moveStep(int blockIndex, int stepIndex, int delta) {
    final List<WorkoutStep> steps =
        List<WorkoutStep>.from(_blocks[blockIndex].steps);
    final int target = stepIndex + delta;
    if (target < 0 || target >= steps.length) return;
    setState(() {
      final WorkoutStep item = steps.removeAt(stepIndex);
      steps.insert(target, item);
      final List<WorkoutBlock> next = List<WorkoutBlock>.from(_blocks);
      next[blockIndex] = next[blockIndex].copyWith(steps: steps);
      _blocks = next;
    });
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un nome per l\'allenamento.')),
      );
      return;
    }

    final List<WorkoutBlock> cleaned = _blocks
        .where((WorkoutBlock b) => b.steps.isNotEmpty)
        .toList();

    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aggiungi almeno una fase prima di salvare.')),
      );
      return;
    }

    final Workout workout = widget.existing == null
        ? Workout(name: name, blocks: cleaned)
        : widget.existing!.copyWith(name: name, blocks: cleaned);

    await context.read<WorkoutProvider>().save(workout);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// Dialogo per impostare il numero di ripetizioni di un blocco.
class _RepeatDialog extends StatefulWidget {
  const _RepeatDialog({required this.initial});

  final int initial;

  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial < 1 ? 1 : widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ripetizioni del blocco'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton.filledTonal(
            iconSize: 32,
            onPressed: _value > 1 ? () => setState(() => _value--) : null,
            icon: const Icon(Icons.remove),
          ),
          Text(
            '$_value ×',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          IconButton.filledTonal(
            iconSize: 32,
            onPressed: _value < 50 ? () => setState(() => _value++) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

/// Editor di un singolo step, mostrato come bottom sheet.
class StepEditorSheet extends StatefulWidget {
  const StepEditorSheet({super.key, this.initial});

  final WorkoutStep? initial;

  @override
  State<StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<StepEditorSheet> {
  late StepType _type;
  late StepGoalType _goalType;
  late TextEditingController _distanceController;
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  late TextEditingController _paceFastController;
  late TextEditingController _paceSlowController;
  bool _useTarget = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final WorkoutStep? initial = widget.initial;
    _type = initial?.type ?? StepType.interval;
    _goalType = initial?.goalType ?? StepGoalType.distance;

    _distanceController = TextEditingController(
      text: (initial?.goalDistanceMeters ?? 400).round().toString(),
    );
    final int seconds = initial?.goalSeconds ?? 300;
    _minutesController =
        TextEditingController(text: (seconds ~/ 60).toString());
    _secondsController =
        TextEditingController(text: (seconds % 60).toString().padLeft(2, '0'));

    final PaceTarget? target = initial?.paceTarget;
    _useTarget = target != null && target.isNotEmpty;
    _paceFastController =
        TextEditingController(text: _paceToText(target?.fastestSecPerKm));
    _paceSlowController =
        TextEditingController(text: _paceToText(target?.slowestSecPerKm));
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _paceFastController.dispose();
    _paceSlowController.dispose();
    super.dispose();
  }

  static String _paceToText(double? secPerKm) {
    if (secPerKm == null || secPerKm <= 0) return '';
    return formatPace(secPerKm);
  }

  /// Converte un testo tipo `4:05` in secondi per chilometro.
  static double? _parsePace(String text) {
    final String value = text.trim();
    if (value.isEmpty) return null;
    final List<String> parts = value.split(RegExp('[:.]'));
    if (parts.length != 2) return null;
    final int? minutes = int.tryParse(parts[0]);
    final int? seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    if (minutes < 0 || seconds < 0 || seconds > 59) return null;
    final double total = minutes * 60.0 + seconds;
    if (total <= 0 || total > 3599) return null;
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isDistance = _goalType == StepGoalType.distance;

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initial == null ? 'Nuova fase' : 'Modifica fase',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // ------------------------------------------------- tipo di fase
            const SectionTitle('Tipo di fase'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final StepType type in StepType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ------------------------------------------------- obiettivo
            const SectionTitle('La fase termina per'),
            SegmentedButton<StepGoalType>(
              segments: const <ButtonSegment<StepGoalType>>[
                ButtonSegment<StepGoalType>(
                  value: StepGoalType.distance,
                  label: Text('Distanza'),
                  icon: Icon(Icons.straighten),
                ),
                ButtonSegment<StepGoalType>(
                  value: StepGoalType.time,
                  label: Text('Tempo'),
                  icon: Icon(Icons.timer_outlined),
                ),
              ],
              selected: <StepGoalType>{_goalType},
              onSelectionChanged: (Set<StepGoalType> selection) {
                setState(() => _goalType = selection.first);
              },
            ),
            const SizedBox(height: 16),

            if (isDistance)
              TextField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Distanza in metri',
                  helperText: 'Esempi: 400, 1000, 2000',
                  border: OutlineInputBorder(),
                ),
              )
            else
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Minuti',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _secondsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Secondi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // ------------------------------------------------ ritmo target
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useTarget,
              onChanged: (bool value) => setState(() => _useTarget = value),
              title: const Text('Ritmo target'),
              subtitle: const Text('Es. da 4:00 a 4:10 al km'),
            ),
            if (_useTarget)
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _paceFastController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Piu veloce',
                        hintText: '4:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _paceSlowController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Piu lento',
                        hintText: '4:10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('CONFERMA FASE'),
            ),
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

  void _submit() {
    double distance = 0;
    int totalSeconds = 0;

    if (_goalType == StepGoalType.distance) {
      distance = double.tryParse(_distanceController.text.trim()) ?? 0;
      if (distance < 10) {
        setState(() => _error = 'Inserisci una distanza di almeno 10 metri.');
        return;
      }
    } else {
      final int minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
      final int seconds = int.tryParse(_secondsController.text.trim()) ?? 0;
      totalSeconds = minutes * 60 + seconds;
      if (totalSeconds < 10) {
        setState(() => _error = 'Inserisci una durata di almeno 10 secondi.');
        return;
      }
    }

    PaceTarget? target;
    if (_useTarget) {
      final double? fast = _parsePace(_paceFastController.text);
      final double? slow = _parsePace(_paceSlowController.text);
      if (fast == null && slow == null) {
        setState(() =>
            _error = 'Inserisci almeno un ritmo nel formato minuti:secondi.');
        return;
      }
      if (fast != null && slow != null && fast > slow) {
        setState(() => _error =
            'Il ritmo piu veloce deve avere un valore minore di quello piu lento.');
        return;
      }
      target = PaceTarget(fastestSecPerKm: fast, slowestSecPerKm: slow);
    }

    final WorkoutStep result = WorkoutStep(
      id: widget.initial?.id,
      type: _type,
      goalType: _goalType,
      goalDistanceMeters:
          _goalType == StepGoalType.distance ? distance : 1000,
      goalSeconds: _goalType == StepGoalType.time ? totalSeconds : 300,
      paceTarget: target,
    );

    Navigator.of(context).pop(result);
  }
}
