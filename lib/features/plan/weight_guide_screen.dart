import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/plan/plan.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// How weight change works — energy balance, losing, gaining, tracking —
/// with the numbers worked out for this person where FITNS knows enough.
/// The same rules the plan, the burn target and the check-ins use.
class WeightGuideScreen extends ConsumerWidget {
  const WeightGuideScreen({super.key});

  static final _n = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(settingsProvider).valueOrNull;
    final weight = ref.watch(weightHistoryProvider).firstOrNull?.value;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.45,
    );

    // This person's maintenance (TDEE), if everything it needs is known.
    int? tdee;
    if (s != null &&
        weight != null &&
        s.heightMm != null &&
        s.birthYear != null &&
        s.sex != null) {
      tdee =
          (restingKcal(
                    weightGrams: weight,
                    heightMm: s.heightMm!,
                    age: DateTime.now().year - s.birthYear!,
                    sex: s.sex!,
                  ) *
                  (s.activityLevel ?? ActivityLevel.light).factor)
              .round();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Weight guide')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'How weight change works',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your weight follows energy balance: the calories you eat and '
            'drink (calories in) against the calories your body uses '
            '(calories out, your TDEE — Total Daily Energy Expenditure).',
            style: muted,
          ),
          const SizedBox(height: 12),
          _Bullets([
            (
              'Calories in',
              'Energy from food and drinks: protein, carbs, fat.',
            ),
            (
              'Calories out (TDEE)',
              'Resting metabolism (breathing, organs), daily movement '
                  '(walking, standing), digesting food, and workouts.',
            ),
          ]),
          const SizedBox(height: 16),
          if (tdee != null)
            _YourNumbers(
              key: const Key('guide-yours'),
              tdee: tdee,
              weightGrams: weight!,
              sex: s!.sex!,
            )
          else
            SectionCard(
              onTap: () => context.push('/plan'),
              child: Row(
                children: [
                  Icon(Icons.calculate_outlined, color: theme.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add your weight, height, birth year and sex in Your '
                      'goal & plan, and this guide fills in your own numbers.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          const SectionLabel('At a glance'),
          const _GoalTable(),
          const SectionLabel('1 · How to lose weight (fat loss)'),
          Text(
            'Burn more than you eat, steadily, so the body draws on stored '
            'energy — body fat.',
            style: muted,
          ),
          const SizedBox(height: 10),
          _Bullets(const [
            (
              'A moderate deficit',
              'Eat 300–500 kcal a day below your TDEE. Skip crash diets: '
                  'below about 1,200 kcal a day for women or 1,500 for men, '
                  'without a doctor, brings tiredness, muscle loss and '
                  'rebound weight gain.',
            ),
            (
              'Protein first',
              '1.6–2.2 g per kg of body weight a day. It keeps you full and '
                  'protects muscle while the fat comes off.',
            ),
            (
              'Strength training 2–4 times a week',
              'Tells your body to keep muscle and burn fat instead.',
            ),
            (
              'Cardio and daily steps',
              'Walking, running or cycling raise the daily burn without '
                  'wearing down recovery.',
            ),
            (
              'Filling, nutrient-dense food',
              'Vegetables, fruit, lean protein, whole grains and pulses — '
                  'dal, chana, rajma — give fibre and vitamins that keep '
                  'hunger down on fewer calories.',
            ),
          ]),
          const SectionLabel('2 · How to gain weight (lean muscle)'),
          Text(
            'Eat a little more than you burn, steadily, so the body has spare '
            'energy to build new tissue.',
            style: muted,
          ),
          const SizedBox(height: 10),
          _Bullets(const [
            (
              'A controlled surplus',
              'Eat 300–500 kcal a day above your TDEE. Eating far more '
                  "doesn't build muscle faster — it mostly adds fat.",
            ),
            (
              'Hit your protein',
              '1.6–2.2 g per kg of body weight a day, the building blocks '
                  'for repair and growth.',
            ),
            (
              'Progressive strength training 3–4 times a week',
              'Add weight or reps over time. Without it, extra calories are '
                  'stored mostly as fat.',
            ),
            (
              'Keep cardio light',
              'Short, easy walks or 15–20 minute rides 2–3 times a week are '
                  'enough for heart health without burning off the surplus.',
            ),
            (
              'Calorie-dense, nourishing food',
              'If you fill up fast: nuts and nut butters, olive oil or ghee, '
                  'avocado, oats, rice, paneer, curd, milk and smoothies.',
            ),
          ]),
          const SectionLabel('3 · Tracking progress & adjusting'),
          _Bullets(const [
            (
              'Weekly averages, not daily spikes',
              'Weight swings 0.5–1.5 kg day to day with water, salt, '
                  'digestion and sleep. Weigh in 2–3 times a week, in the '
                  'morning, and compare the weekly averages — the trend on '
                  'the Body page does this for you.',
            ),
            (
              'Adjust every 2–3 weeks',
              'Losing and the scale won\'t move: eat 150–200 kcal a day '
                  'less, or add 2,000–3,000 steps a day. Gaining and it won\'t '
                  'move: eat 200–250 kcal more, or trim extra cardio. FITNS '
                  'suggests this for you in a check-in every two weeks.',
            ),
          ]),
          const SizedBox(height: 16),
          Text(
            'General guidance, not medical advice. If you are pregnant, '
            'under 18, or have a health condition, check with a doctor '
            'before changing how you eat.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/plan'),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Set my goal & plan'),
          ),
        ],
      ),
    );
  }
}

/// This person's maintenance, the deficit and surplus ranges, and protein.
class _YourNumbers extends StatelessWidget {
  const _YourNumbers({
    super.key,
    required this.tdee,
    required this.weightGrams,
    required this.sex,
  });

  final int tdee;
  final int weightGrams;
  final Sex sex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = WeightGuideScreen._n;
    final floor = sex == Sex.male ? 1500 : 1200;
    final protein = proteinRange(weightGrams);
    int atLeast(int k) => k < floor ? floor : k;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your numbers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'From your weight, height, age, sex and activity level.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          row('Maintenance (TDEE)', '${n.format(tdee)} kcal'),
          row(
            'To lose',
            '${n.format(atLeast(tdee - 500))}–'
                '${n.format(atLeast(tdee - 300))} kcal',
          ),
          row(
            'To gain',
            '${n.format(tdee + 300)}–${n.format(tdee + 500)} kcal',
          ),
          row('Protein', '${protein.low}–${protein.high} g a day'),
        ],
      ),
    );
  }
}

/// Lose, maintain, gain: the balance, the weekly change, the focus.
class _GoalTable extends StatelessWidget {
  const _GoalTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(
      IconData icon,
      String goal,
      String balance,
      String change,
      String focus,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(balance, style: theme.textTheme.bodyMedium),
                Text(
                  '$change · $focus',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return SectionCard(
      child: Column(
        children: [
          item(
            Icons.trending_down,
            'Lose weight',
            'Deficit: eat 300–500 kcal less than your TDEE',
            '−0.25 to −0.5 kg a week',
            'fat loss, keeping muscle',
          ),
          const Divider(),
          item(
            Icons.trending_flat,
            'Maintain weight',
            'Balance: eat about your TDEE',
            'Stable weight',
            'performance, energy and health',
          ),
          const Divider(),
          item(
            Icons.trending_up,
            'Gain weight',
            'Surplus: eat 300–500 kcal more than your TDEE',
            '+0.25 to +0.5 kg a week',
            'muscle, with little fat',
          ),
        ],
      ),
    );
  }
}

/// Bold lead-ins with a line of detail each.
class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (lead, body)) in items.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$lead. ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: body),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
