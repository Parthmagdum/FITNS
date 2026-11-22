import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/units.dart';
import '../../data/providers.dart';

/// Asks how much water to add: a tap on one of the quick-add sizes, or an
/// amount typed in. Resolves to ml, or null if dismissed.
Future<int?> showAddWaterSheet(BuildContext context) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddWaterSheet(),
    );

class _AddWaterSheet extends ConsumerStatefulWidget {
  const _AddWaterSheet();

  @override
  ConsumerState<_AddWaterSheet> createState() => _AddWaterSheetState();
}

class _AddWaterSheetState extends ConsumerState<_AddWaterSheet> {
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _addTyped(UnitSystem units) {
    final ml = parseVolume(_amount.text, units);
    if (ml == null || ml > 5000) {
      setState(
        () => _error = 'Enter an amount, up to ${formatVolume(5000, units)}',
      );
      return;
    }
    Navigator.pop(context, ml);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = ref.watch(unitsProvider);
    final presets = ref.watch(waterPresetsProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, color: theme.accent),
                  const SizedBox(width: 8),
                  Text('Add water', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'How much did you drink?',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ml in presets)
                    ActionChip(
                      avatar: Icon(Icons.add, size: 18, color: theme.accent),
                      label: Text(formatVolume(ml, units)),
                      onPressed: () => Navigator.pop(context, ml),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('water-amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTyped(units),
                      decoration: InputDecoration(
                        labelText: 'Other amount',
                        suffixText: volumeUnit(units),
                        errorText: _error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton(
                      onPressed: () => _addTyped(units),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
