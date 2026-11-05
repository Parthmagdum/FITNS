# Changelog

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
