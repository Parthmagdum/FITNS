import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Asks for the user's height in their units and saves it. Shared by
/// Settings and the Body tab's "add height for BMI".
Future<void> editHeight(BuildContext context, WidgetRef ref) async {
  final units = ref.read(unitsProvider);
  final current = ref.read(settingsProvider).valueOrNull?.heightMm;
  final int? mm;
  if (units == UnitSystem.metric) {
    final text = await promptText(
      context,
      title: 'Height',
      initial: current == null ? '' : lengthInputText(current, units),
      hint: '175',
      suffix: 'cm',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (text == null) return;
    mm = parseLength(text, units);
  } else {
    mm = await showDialog<int>(
      context: context,
      builder: (_) => _FeetInchesDialog(initialMm: current),
    );
  }
  // Under 50 cm or over 2.5 m is a typo, not a person.
  if (mm == null || mm < 500 || mm > 2500) return;
  await ref
      .read(dbProvider)
      .updateSettings(SettingsCompanion(heightMm: Value(mm)));
}

class _FeetInchesDialog extends StatefulWidget {
  const _FeetInchesDialog({required this.initialMm});

  final int? initialMm;

  @override
  State<_FeetInchesDialog> createState() => _FeetInchesDialogState();
}

class _FeetInchesDialogState extends State<_FeetInchesDialog> {
  late final _feet = TextEditingController();
  late final _inches = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialMm case final mm?) {
      final (:feet, :inches) = feetAndInches(mm);
      _feet.text = '$feet';
      _inches.text = '$inches';
    }
  }

  @override
  void dispose() {
    _feet.dispose();
    _inches.dispose();
    super.dispose();
  }

  void _save() {
    final feet = int.tryParse(_feet.text) ?? 0;
    final inches = int.tryParse(_inches.text) ?? 0;
    if (feet == 0 && inches == 0) return;
    Navigator.pop(context, heightFromFeetInches(feet, inches));
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: const Text('Height'),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _feet,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: const InputDecoration(suffixText: 'ft'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _inches,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: const InputDecoration(suffixText: 'in'),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
