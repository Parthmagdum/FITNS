# Changelog

## 0.0.8 — 2026-11-06

**Your plan, kept on track**
- **Weekly check-in.** Once a week while a goal is set, Today compares your
  real weight trend with the plan's pace and offers a calorie change to
  apply in one tap — small steps (at most 250 kcal), never below the floor.
- **Food search.** 123 common foods — Indian staples and everyday basics —
  with typical calories and macros, found as you type in any meal. Pick one
  and it's saved to your foods (editable) and logged.

**Training**
- **How hard was that set?** After ticking a set, an optional "reps left in
  the tank" (0–4+). Taken to failure, the next session holds the weight;
  easy every set, it suggests a double step.
- **Lighter week.** After every 6 weeks of training in a row, the Workouts
  tab suggests a deload week.
- **Short on time?** While setting up, see roughly how long the workout
  will take and trim it to 20, 30, 45 or 60 minutes — sets come off evenly
  first, whole exercises from the end last.
- **Warm-up and cool-down** in one tap while setting up, with 8 new warm-up
  and stretch exercises.
- **4 more ready-made routines**: Push day, Pull day, Home full body (no
  equipment) and a 20-minute express.
- Today's quick-start buttons put your recent and your own routines first.

**Progress** (the chart button on Today)
- **Streaks**: weeks trained in a row, days at your step goal, days with
  food logged.
- **Any month at a glance**: workouts, time, volume, average calories,
  steps and sleep, and weight change.
- **Muscle balance**: sets per muscle over the last week against the usual
  10–20, with the gaps named.
- **12 badges** to earn.

**Body & sleep**
- **Sleep logging**: bedtime, wake time and how it felt; Today shows last
  night and the week's average.
- **Body-fat estimate** from your waist and neck (and hips) measurements —
  the US Navy method, a better guide than BMI if you lift.

**On your phone**
- **Reminders** (Settings): a workout reminder at your time on your days,
  water every two hours from 9 to 9, and a weekly weigh-in. Restored after
  a reboot; no extra permission.
- **Home-screen widget**: today's steps against your goal, calories left
  and your next program workout.
- **Progress photos** (Body tab): take one or pick from your gallery, see
  it beside your first. Kept privately on the phone, shrunk to save space —
  not in backups, so keep copies if you switch phones. No camera or storage
  permission needed.
- **Barcode scanning** in the food picker: scan a packet, enter its label
  once, and it's one scan from then on. Uses the open-source ZXing scanner
  and works offline; asks for the camera on first scan only.
- **Health Connect** (Settings, Android 8+): bring in steps and weight from
  your watch or scale, and share workouts. Off until you connect it; steps
  only ever go up when imported, weigh-ins aren't doubled.
- **Cycle-aware plans** (Settings, optional, off by default): log period
  starts to see your cycle day and phase on Today with training and food
  notes; the weekly check-in won't cut calories when the scale is likely
  high from water. Kept only on the phone.

**Under the hood**
- Schema v9 and backup format 6 (sleep, cycle, effort per set, reminder
  and cycle settings). Older backups still restore.
- New permissions: camera (barcode scanning only, asked on first use) and
  Health Connect's steps, weight and exercise (asked only when you
  connect). FITNS still has no internet access.
- Release builds use actions/setup-java@v5.

## 0.0.7 — 2026-11-06

- **Your goal & plan.** FITNS now asks what you're aiming for — on Today
  and Body, and pointedly when your BMI is under or over the healthy range.
  Choose lose, stay or gain, your target weight (one is suggested from the
  healthy range for your height) and how fast, and get:
  - **Daily targets** from your weight, height, age, sex and activity:
    calories, protein, carbs, fat, water and steps — with when you'll reach
    your target. Saving the plan sets all your daily goals to match.
  - **Safety limits**: losing is capped at 1 % of body weight a week and
    never below 1,200 / 1,500 kcal; gaining at 0.5 kg a week. It warns about
    targets outside the healthy range, and under-18s.
  - **A day of eating** sized to your calories — vegetarian, veg + eggs or
    non-veg, Indian-friendly meals — with another day a tap away. Save any
    meal to your foods to log it.
  - **A training program** for your goal and the days you can train (full
    body, upper/lower or push/pull/legs), set up on the Workouts tab in one
    tap.
  - **Progress** on Today and Body: how far you've come and what's left.
- **A ready-made Leg day routine**: Squat, Romanian Deadlift, Leg Press,
  Walking Lunge, Leg Curl and Calf Raise, with sets, reps and rest filled
  in. Added once — edit it, rename it or delete it like your own.
- **9 more leg exercises**: Hack Squat, Walking Lunge, Cossack Squat, Box
  Jump (high impact), Sumo Deadlift, Hip Abduction, Seated Leg Curl,
  Nordic Curl and Dumbbell Calf Raise.
- **A timer for each exercise**, alongside the workout's overall clock. The
  first exercise's timer starts with the workout; ticking off an
  exercise's last set stops it and starts the next one from zero. Jump to
  another exercise and the timer follows you there. Tap a timer to pause
  or carry on, or Start to begin an exercise by hand. Finished workouts
  show how long each exercise took.

## 0.0.6 — 2026-11-06

**Train anywhere, your way**
- **Programs.** Put routines in a cycle of days — Push, Pull, Legs, Rest —
  and the Workouts tab always shows what's up next, picking up after the
  last day you trained. Edit a routine and every program using it follows.
- **Places.** Say what equipment each place has (Gym, Home and Park or
  hotel to start with). Pick where you're training once on the Workouts
  tab; it stays until you change it.
- **Automatic swaps.** Start a routine somewhere without a barbell and
  Bench Press (Barbell) becomes Bench Press (Dumbbell) — same muscle, the
  closest movement, the same kind of sets. The routine itself never
  changes, and each swap shows "Instead of …".
- **Low-impact only.** One switch skips jumps and hard landings (burpees,
  jump squats, jumping jacks, jump rope) for gentler moves that train the
  same muscles. Custom exercises can be marked high impact.
- **Swap by hand.** Any exercise in a workout in progress can be swapped
  for a ranked list of alternatives, or back to the routine's own.
- **Add exercises** filters to what fits where you are, and labels high
  impact ones.
- 24 new built-in exercises for home, travel and low-impact days — bands,
  bodyweight and dumbbell alternatives.
- Backups include places and programs (format 4).

**Fixed**
- **The clock no longer runs while you set up.** A new workout — empty or
  from a routine or program — opens in setup: add, swap and pre-fill
  exercises with no clock, ticks or rest timer running. Tap **Start
  workout** when you're ready; the workout's time counts from then.

## 0.0.5 — 2026-11-02

**Smarter tracking**
- **Steps — where today is heading.** From your usual day over the last
  two weeks, the Steps card and page say whether you'll reach your goal at
  your normal pace, and if not, how long a walk would close the gap.
- **Workouts — personal records.** A finished workout marks each
  exercise's new heaviest weight, best estimated 1-rep max, or most reps
  (bodyweight), and counts them at the top.
- **Workouts — when to add weight.** If you hit every set last time, the
  exercise suggests the next step up (+2.5 kg / +5 lb); "Use" fills it into
  the sets you haven't done yet.
- **Body — weight trend.** A 90-day chart of weigh-ins with a 7-day average
  line, and how fast you're losing or gaining per week (from the last 4
  weeks, so daily water-weight swings don't fool it).
- **Water — pace.** Today's water card says whether you're on pace for
  your goal through the waking day, or how far behind.
- **Food — same as yesterday.** An empty meal offers the day before's
  same meal in one tap, with undo.

**Faster**
- Database indexes on every link between workouts, exercises, sets,
  routines, water and food (schema v6), so history, "previous" sets and the
  food list stay quick after years of logging.
- Walking with the app open now writes steps at most every 3 seconds
  instead of on nearly every step — less battery and fewer screen redraws.
  No steps are lost.
- Today shows your last workout from a one-row query, instead of
  recounting your whole history every time you tick off a set.
- The Steps page stops watching your step history once you leave it.

**Easier**
- **Undo** after deleting a food log, a set, or an exercise in a workout.
- **Jump to any day** — tap the date on the Food tab or the Steps page to
  pick one from a calendar.
- **Workout history by month**, with how many workouts each month had.

## 0.0.4 — 2026-11-02

- **Steps page** — tap the Steps card on Today to open a full page, like
  Samsung Health's:
  - **Day** — a goal ring, then steps by the hour; tap or drag across the
    chart to see any hour, and see your most active hour.
  - **Week / Month** — steps by the day against your goal line, daily
    average, total and how many days you hit the goal. Tap a bar and
    "View day" to jump to it. Step back through earlier days, weeks and months.
  - **Distance, calories and active time** — estimated from your height and
    latest weigh-in, in km or miles.
  - **Records** — current and longest goal streaks, best day and all-time
    steps.
  - Change the daily step goal right from the page.
- Steps are now also kept per hour (from this update on). Backups include
  them; older backups still restore.

## 0.0.3 — 2026-10-29

- **Food tab** — log what you eat by meal (breakfast, lunch, dinner,
  snacks) with calories, protein, carbs and fat. Move between days to fill
  in one you missed.
- **Saved foods** — save the foods you eat often with their serving and
  macros, then log them in one tap (or pick 0.5, 1.5, 2 servings). Editing
  or deleting a saved food never changes what you already logged.
- **Quick add** — log just the calories when you don't know the rest.
- **Daily goals** — calorie and macro targets, typed in or worked out from
  your weight, height, age and activity (Mifflin-St Jeor).
- **Water** — a daily goal, one-tap glass sizes you choose, undo, and the
  last 7 days. On Today and the Food tab.
- Backups now include food and water. Older backups still restore.

## 0.0.2 — 2026-10-29

- **Exercise icons** — every exercise shows an icon for its kind of movement
  (weights, bodyweight, core, holds, jumps, cardio…), in the picker, workout,
  routines and history. Pick one for your own exercises.
- **Edit finished workouts** — fix a mistyped set, add or remove sets and
  exercises, rename, or move the workout to another date and time.
- **Backup & restore** — save everything to one file wherever you like
  (Downloads, Drive…), and restore it on this or another phone. Restoring
  shows what's in the backup first and replaces everything only once you
  confirm.
- **Rest timer alerts** — with the phone locked or FITNS in the background,
  a countdown shows on the lock screen and the phone buzzes when rest is
  over. Settings shows whether alerts can arrive on time.

## 0.0.1 — 2026-10-28

The first release. Android only, fully offline — the app has no internet
permission, and everything stays on the phone.

- **Workouts** — log sets as weight × reps, reps, or time, with last
  session's numbers alongside. A rest timer starts each time you tick a set.
  A workout in progress survives the app being closed.
- **Routines** — reusable plans with target sets, reps and rest per exercise.
- **Exercise library** — 68 built-in exercises, plus your own.
- **Sensor rep counting** — push-ups (proximity sensor), squats, sit-ups,
  crunches and hanging leg raises (tilt), jumping jacks, jump rope, burpees
  and jump squats (jump detection). Fix the count before it's saved.
- **Steps** — today against your goal, and the last 7 days. Counts all day
  in the background, through reboots; can be switched off.
- **Body** — weight, body fat and tape measurements, with BMI.
- **Settings** — metric or imperial, light or dark, step goal, default rest.
