import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/units.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'body_format.dart';

/// Log a weigh-in and/or measurements — every value shares one moment.
Future<void> showBodyLogSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _BodyLogSheet(),
);

class _BodyLogSheet extends ConsumerStatefulWidget {
  const _BodyLogSheet();

  @override
  ConsumerState<_BodyLogSheet> createState() => _BodyLogSheetState();
}

class _BodyLogSheetState extends ConsumerState<_BodyLogSheet> {
  final _controllers = {
    for (final m in BodyMetric.values) m: TextEditingController(),
  };
  final _errors = <BodyMetric>{};
  var _date = DateTime.now();
  var _showMeasurements = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final units = ref.read(unitsProvider);
    final values = <BodyMetric, int>{};
    final errors = <BodyMetric>{};
    for (final MapEntry(key: metric, value: c) in _controllers.entries) {
      if (c.text.trim().isEmpty) continue;
      final value = parseBodyValue(metric, c.text, units);
      if (value == null) {
        errors.add(metric);
      } else {
        values[metric] = value;
      }
    }
    setState(
      () => _errors
        ..clear()
        ..addAll(errors),
    );
    if (errors.isNotEmpty) return;
    if (values.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter at least one value')),
        );
      return;
    }
    final now = DateTime.now();
    // A past day keeps the current time of day, so two logs on it still
    // sort in the order they were made.
    final at = isSameDay(_date, now)
        ? now
        : DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    await ref.read(dbProvider).addBodyEntries(at, values);
    if (mounted) Navigator.pop(context);
  }

  Widget _field(BodyMetric metric, UnitSystem units, {bool autofocus = false}) {
    return TextField(
      controller: _controllers[metric],
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: metric.label,
        suffixText: bodyUnit(metric, units),
        errorText: _errors.contains(metric) ? 'Not a valid number' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final measurements = BodyMetric.measurements;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Log body', style: theme.textTheme.titleLarge),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(relativeDay(_date)),
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _field(BodyMetric.weight, units, autofocus: true),
              ),
              const SizedBox(width: 12),
              Expanded(child: _field(BodyMetric.bodyFat, units)),
            ],
          ),
          const SizedBox(height: 8),
          if (!_showMeasurements)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showMeasurements = true),
                icon: const Icon(Icons.straighten),
                label: const Text('Add measurements'),
              ),
            )
          else
            for (var i = 0; i < measurements.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(child: _field(measurements[i], units)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: i + 1 < measurements.length
                          ? _field(measurements[i + 1], units)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
