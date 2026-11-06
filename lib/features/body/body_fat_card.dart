import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bmi.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Body fat estimated from the tape measurements the user logs — or what to
/// measure to get one. Hidden until height and sex are known.
class BodyFatEstimateCard extends ConsumerWidget {
  const BodyFatEstimateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final latest = ref.watch(latestBodyProvider);
    final sex = settings?.sex;
    final height = settings?.heightMm;
    if (sex == null || height == null) return const SizedBox.shrink();

    final estimate = navyBodyFat(
      sex: sex,
      heightMm: height,
      waistMm: latest[BodyMetric.waist]?.value,
      neckMm: latest[BodyMetric.neck]?.value,
      hipMm: latest[BodyMetric.hips]?.value,
    );
    final needs = sex == Sex.male ? 'waist and neck' : 'waist, hips and neck';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SectionCard(
        child: Row(
          children: [
            Icon(Icons.straighten, color: theme.accent),
            const SizedBox(width: 16),
            Expanded(
              child: estimate == null
                  ? Text(
                      'Log your $needs to estimate your body fat — a better '
                      'guide than BMI if you lift.',
                      style: theme.textTheme.bodySmall,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated body fat',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.muted,
                          ),
                        ),
                        Text(
                          '${estimate.toStringAsFixed(1)} %',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          'From your $needs (US Navy method), usually '
                          'within 3–4 points.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.muted,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
