import 'tables.dart';

/// How to do one exercise: the movement step by step, plus the cues that
/// matter most. Built in, so it works offline like the rest of the app.
class ExerciseGuide {
  const ExerciseGuide(this.steps, [this.tips = const []]);

  final List<String> steps;

  /// Form cues and common mistakes.
  final List<String> tips;
}

/// Guides for the built-in exercises, by seed key. A key here must exist in
/// `seedExercises` — test/exercise_guides_test.dart checks it.
const exerciseGuides = <String, ExerciseGuide>{
  // ── Chest ──
  'bench_press_bb': ExerciseGuide([
    'Lie on the bench with your eyes under the bar and feet flat on the floor.',
    'Grip the bar slightly wider than shoulder width. Squeeze your shoulder blades together.',
    'Unrack the bar and hold it over your shoulders with straight arms.',
    'Lower it slowly to your mid-chest, elbows about 45° from your body.',
    'Press back up to straight arms, keeping your back and hips on the bench.',
  ], [
    'Use a spotter or safety arms when you go heavy.',
    "Don't bounce the bar off your chest.",
  ]),
  'incline_bench_bb': ExerciseGuide([
    'Set the bench to 30–45° and lie back with feet flat.',
    'Grip just wider than shoulder width and unrack the bar.',
    'Lower it to your upper chest, just below the collarbones.',
    'Press up and slightly back until your arms are straight.',
  ], [
    'A steeper bench works the shoulders more than the chest.',
  ]),
  'bench_press_db': ExerciseGuide([
    'Sit on the bench with a dumbbell on each thigh, then lie back and bring them to your chest.',
    'Hold them at chest level, palms facing your feet.',
    'Press both up until your arms are straight and the weights nearly touch.',
    'Lower slowly until you feel a stretch across your chest.',
  ], [
    'Keep your wrists straight and stacked over your elbows.',
  ]),
  'incline_bench_db': ExerciseGuide([
    'Set the bench to 30–45°, sit back with a dumbbell at each shoulder.',
    'Press the weights up over your upper chest.',
    'Lower them slowly to the sides of your upper chest.',
    'Press back up without locking your elbows hard.',
  ]),
  'chest_fly_db': ExerciseGuide([
    'Lie on a flat bench, dumbbells held above your chest, palms facing each other.',
    'Keep a slight bend in your elbows.',
    'Open your arms wide in an arc until you feel a stretch in your chest.',
    'Squeeze your chest to bring the weights back together over you.',
  ], [
    'Go light — this is a stretch-and-squeeze move, not a press.',
    "Don't let your elbows drop below the bench.",
  ]),
  'cable_crossover': ExerciseGuide([
    'Set both pulleys high. Take a handle in each hand and step forward.',
    'Stand in a split stance and lean slightly forward, elbows softly bent.',
    'Pull the handles down and together in front of your hips.',
    'Let your arms open slowly back out until your chest stretches.',
  ]),
  'chest_press_machine': ExerciseGuide([
    'Adjust the seat so the handles are at mid-chest height.',
    'Sit with your back against the pad and grip the handles.',
    'Push forward until your arms are straight.',
    'Return slowly without letting the weight stack touch down.',
  ]),
  'push_up': ExerciseGuide([
    'Start on your hands and toes, hands just wider than your shoulders.',
    'Make a straight line from head to heels — brace your stomach and glutes.',
    'Bend your elbows to lower your chest close to the floor.',
    'Push the floor away to return to the top.',
  ], [
    "Too hard? Put your knees down or your hands on a bench.",
    "Don't let your hips sag or stick up.",
  ]),
  'dip': ExerciseGuide([
    'Grip the parallel bars and jump up to straight arms.',
    'Lean your chest slightly forward and bend your knees.',
    'Lower yourself until your upper arms are about parallel to the floor.',
    'Push back up to straight arms.',
  ], [
    "Stop lower if your shoulders hurt — don't force depth.",
  ]),

  // ── Back ──
  'deadlift_bb': ExerciseGuide([
    'Stand with feet hip-width apart, the bar over the middle of your feet.',
    'Hinge at your hips and grip the bar just outside your legs.',
    'Drop your hips, lift your chest and flatten your back. Take a big breath and brace.',
    'Push the floor away with your legs, keeping the bar close to your shins and thighs.',
    'Stand tall at the top, then lower the bar the same way under control.',
  ], [
    'Keep your back flat — never round it to reach the bar.',
    "Don't lean back at the top; just stand straight.",
  ]),
  'bent_over_row_bb': ExerciseGuide([
    'Hold the bar with an overhand grip, hands shoulder-width apart.',
    'Hinge forward until your torso is near 45°, knees slightly bent, back flat.',
    'Pull the bar to your lower ribs, squeezing your shoulder blades.',
    'Lower it slowly until your arms are straight.',
  ], [
    "Don't jerk the weight up with your lower back.",
  ]),
  'one_arm_row_db': ExerciseGuide([
    'Put one knee and the same hand on a bench, back flat.',
    'Hold a dumbbell in the other hand, arm hanging straight down.',
    'Pull the dumbbell toward your hip, elbow close to your body.',
    'Lower it slowly and repeat. Switch sides.',
  ]),
  'pull_up': ExerciseGuide([
    'Hang from the bar, palms facing away, hands a little wider than shoulders.',
    'Pull your shoulders down and back first.',
    'Pull yourself up until your chin is over the bar.',
    'Lower slowly all the way down to straight arms.',
  ], [
    "Can't do one yet? Use a band, or jump up and lower slowly.",
    "Don't swing or kick.",
  ]),
  'chin_up': ExerciseGuide([
    'Hang from the bar with palms facing you, hands shoulder-width apart.',
    'Pull until your chin passes the bar, chest toward it.',
    'Lower under control to a full hang.',
  ]),
  'lat_pulldown': ExerciseGuide([
    'Sit with your knees under the pads and grip the bar wide, palms forward.',
    'Lean back slightly and lift your chest.',
    'Pull the bar down to your upper chest, elbows driving down.',
    'Let it rise slowly until your arms are straight.',
  ], [
    "Don't pull the bar behind your neck.",
  ]),
  'seated_cable_row': ExerciseGuide([
    'Sit with feet on the platform, knees slightly bent, and grab the handle.',
    'Sit tall with your chest up and arms straight.',
    'Pull the handle to your stomach, squeezing your shoulder blades together.',
    'Return slowly, letting your shoulders stretch forward a little.',
  ], [
    'Keep your torso still — no rocking back and forth.',
  ]),
  't_bar_row': ExerciseGuide([
    'Straddle the bar and grip the handle.',
    'Hinge forward with a flat back and slightly bent knees.',
    'Pull the weight to your chest.',
    'Lower slowly to straight arms.',
  ]),
  'back_extension': ExerciseGuide([
    'Set the pad just below your hips and hook your heels under the foot pads.',
    'Cross your arms over your chest and bend forward at the hips.',
    'Raise your torso until your body is in a straight line.',
    'Lower slowly and repeat.',
  ], [
    "Don't over-arch at the top.",
  ]),

  // ── Shoulders ──
  'ohp_bb': ExerciseGuide([
    'Stand with the bar on your front shoulders, hands just outside them.',
    'Squeeze your glutes and brace your stomach.',
    'Press the bar straight up, moving your head back slightly to let it pass.',
    'Lock out overhead with the bar over your mid-foot, then lower to your shoulders.',
  ], [
    "Don't lean back to push the weight — brace instead.",
  ]),
  'shoulder_press_db': ExerciseGuide([
    'Sit or stand holding dumbbells at shoulder height, palms forward.',
    'Press them up until your arms are straight overhead.',
    'Lower slowly back to shoulder height.',
  ]),
  'arnold_press': ExerciseGuide([
    'Hold dumbbells in front of your shoulders, palms facing you.',
    'As you press up, rotate your palms to face forward.',
    'Finish with arms straight overhead.',
    'Reverse the rotation as you lower.',
  ]),
  'lateral_raise_db': ExerciseGuide([
    'Stand holding light dumbbells at your sides, elbows slightly bent.',
    'Raise your arms out to the sides until they reach shoulder height.',
    'Pause, then lower slowly.',
  ], [
    'Lead with your elbows, not your hands.',
    "Don't shrug or swing — go lighter.",
  ]),
  'front_raise_db': ExerciseGuide([
    'Stand holding dumbbells in front of your thighs.',
    'Raise them forward with straight arms to shoulder height.',
    'Lower slowly.',
  ]),
  'rear_delt_fly_db': ExerciseGuide([
    'Hinge forward with a flat back, dumbbells hanging below your chest.',
    'With a slight elbow bend, raise them out to the sides.',
    'Squeeze the back of your shoulders at the top, then lower slowly.',
  ]),
  'face_pull': ExerciseGuide([
    'Set a rope on a cable at face height.',
    'Grab the ends with palms facing in and step back.',
    'Pull the rope toward your face, splitting the ends past your ears.',
    'Return slowly to straight arms.',
  ], [
    'Finish with your hands higher than your elbows.',
  ]),
  'shrug_db': ExerciseGuide([
    'Stand with a dumbbell in each hand at your sides.',
    'Lift your shoulders straight up toward your ears.',
    'Hold for a second, then lower.',
  ], [
    "Don't roll your shoulders — just up and down.",
  ]),

  // ── Arms ──
  'curl_bb': ExerciseGuide([
    'Stand holding the bar with palms up, hands shoulder-width apart.',
    'Keep your elbows pinned at your sides.',
    'Curl the bar up toward your shoulders.',
    'Lower slowly to straight arms.',
  ], [
    "Don't swing your back to lift the weight.",
  ]),
  'curl_db': ExerciseGuide([
    'Stand holding dumbbells at your sides, palms facing forward.',
    'Curl them up, keeping your elbows by your sides.',
    'Squeeze at the top, then lower slowly.',
  ]),
  'hammer_curl_db': ExerciseGuide([
    'Hold dumbbells at your sides with palms facing each other.',
    'Curl them up, keeping your palms facing in the whole time.',
    'Lower slowly.',
  ]),
  'preacher_curl': ExerciseGuide([
    'Sit at the preacher bench with your upper arms flat on the pad.',
    'Hold the bar with palms up.',
    'Curl the bar up toward your shoulders.',
    'Lower slowly until your arms are almost straight.',
  ]),
  'cable_curl': ExerciseGuide([
    'Attach a bar to a low pulley and hold it palms up.',
    'Stand tall with elbows at your sides.',
    'Curl the bar up to your chest, then lower slowly.',
  ]),
  'triceps_pushdown': ExerciseGuide([
    'Attach a bar or rope to a high pulley.',
    'Stand close, elbows tucked at your sides.',
    'Push the handle down until your arms are straight.',
    'Let it rise back to about chest height, elbows still.',
  ], [
    'Only your forearms should move.',
  ]),
  'overhead_ext_db': ExerciseGuide([
    'Hold one dumbbell with both hands, arms straight overhead.',
    'Bend your elbows to lower the weight behind your head.',
    'Straighten your arms to lift it back up.',
  ], [
    'Keep your elbows pointing forward, close to your head.',
  ]),
  'skull_crusher_bb': ExerciseGuide([
    'Lie on a bench holding the bar over your chest, arms straight.',
    'Bend only your elbows to lower the bar toward your forehead.',
    'Straighten your arms to press it back up.',
  ]),
  'close_grip_bench': ExerciseGuide([
    'Lie on a bench and grip the bar about shoulder-width apart.',
    'Lower it to your lower chest, elbows close to your body.',
    'Press back up to straight arms.',
  ]),
  'bench_dip': ExerciseGuide([
    'Sit on a bench edge, hands next to your hips, fingers forward.',
    'Slide your hips off the bench, legs out in front.',
    'Bend your elbows to lower your hips toward the floor.',
    'Push back up to straight arms.',
  ], [
    'Bend your knees to make it easier.',
  ]),
  'wrist_curl_db': ExerciseGuide([
    'Sit with your forearms on your thighs, palms up, wrists past your knees.',
    'Let the dumbbells roll down toward your fingers.',
    'Curl your wrists up as high as you can, then lower.',
  ]),

  // ── Legs ──
  'squat_bb': ExerciseGuide([
    'Set the bar on your upper back, not your neck. Grip it firmly.',
    'Stand with feet shoulder-width apart, toes slightly out.',
    'Brace your stomach, then sit your hips back and down.',
    'Go down until your thighs are at least parallel to the floor, knees following your toes.',
    'Drive up through your whole foot to stand.',
  ], [
    'Keep your chest up and heels down.',
    'Use safety bars in a rack when you go heavy.',
  ]),
  'front_squat_bb': ExerciseGuide([
    'Rest the bar on your front shoulders, elbows high.',
    'Stand with feet shoulder-width apart.',
    'Squat down keeping your torso upright.',
    'Stand back up, keeping your elbows lifted.',
  ]),
  'goblet_squat': ExerciseGuide([
    'Hold a dumbbell vertically against your chest.',
    'Stand with feet a little wider than your shoulders.',
    'Squat down between your knees, elbows inside your knees.',
    'Push through your heels to stand up.',
  ]),
  'leg_press': ExerciseGuide([
    'Sit with your back flat on the pad, feet hip-width on the platform.',
    'Release the safety handles.',
    'Bend your knees to lower the platform toward your chest.',
    'Press it back up without locking your knees.',
  ], [
    "Don't let your lower back lift off the pad at the bottom.",
  ]),
  'leg_extension': ExerciseGuide([
    'Sit with the pad on your lower shins and your knees lined up with the pivot.',
    'Straighten your legs to lift the pad.',
    'Squeeze your thighs at the top, then lower slowly.',
  ]),
  'lunge_db': ExerciseGuide([
    'Stand holding dumbbells at your sides.',
    'Take a big step forward.',
    'Lower your back knee toward the floor until both knees are at about 90°.',
    'Push off your front foot to step back. Switch legs.',
  ], [
    'Keep your front knee over your foot, not caving inward.',
  ]),
  'bulgarian_split_squat': ExerciseGuide([
    'Stand a big step in front of a bench, top of one foot resting on it behind you.',
    'Hold dumbbells at your sides.',
    'Lower your back knee toward the floor.',
    'Push through your front heel to stand. Finish one side, then switch.',
  ]),
  'bodyweight_squat': ExerciseGuide([
    'Stand with feet shoulder-width apart, arms in front for balance.',
    'Sit your hips back and down as if into a chair.',
    'Go as low as you comfortably can with your heels down.',
    'Stand back up.',
  ]),
  'rdl_bb': ExerciseGuide([
    'Stand holding the bar at your thighs, knees slightly bent.',
    'Push your hips back, sliding the bar down your legs.',
    'Stop when you feel a strong stretch in your hamstrings, back flat.',
    'Drive your hips forward to stand tall.',
  ], [
    'It is a hip hinge, not a squat — knees stay softly bent.',
  ]),
  'leg_curl': ExerciseGuide([
    'Lie face down with the pad just above your heels.',
    'Curl your heels toward your glutes.',
    'Lower slowly.',
  ]),
  'hip_thrust_bb': ExerciseGuide([
    'Sit on the floor with your upper back against a bench and the bar over your hips.',
    'Plant your feet flat, hip-width apart.',
    'Drive your hips up until your body is flat from shoulders to knees.',
    'Squeeze your glutes at the top, then lower.',
  ], [
    'Use a pad on the bar for comfort.',
  ]),
  'glute_bridge': ExerciseGuide([
    'Lie on your back, knees bent, feet flat near your hips.',
    'Push through your heels to lift your hips.',
    'Squeeze your glutes at the top.',
    'Lower slowly.',
  ]),
  'standing_calf_raise': ExerciseGuide([
    'Stand with the balls of your feet on the platform, shoulders under the pads.',
    'Let your heels drop below the platform.',
    'Rise up as high as you can onto your toes.',
    'Lower slowly.',
  ]),
  'seated_calf_raise': ExerciseGuide([
    'Sit with the pad on your lower thighs and the balls of your feet on the platform.',
    'Lower your heels for a stretch.',
    'Push up onto your toes, then lower slowly.',
  ]),

  // ── Core ──
  'plank': ExerciseGuide([
    'Rest on your forearms and toes, elbows under your shoulders.',
    'Make a straight line from head to heels.',
    'Brace your stomach and squeeze your glutes.',
    'Hold, breathing steadily.',
  ], [
    "Don't let your hips sag or rise.",
  ]),
  'side_plank': ExerciseGuide([
    'Lie on your side, propped up on one forearm, elbow under your shoulder.',
    'Stack your feet and lift your hips off the floor.',
    'Keep your body in a straight line and hold. Switch sides.',
  ], [
    'Bend your knees to make it easier.',
  ]),
  'crunch': ExerciseGuide([
    'Lie on your back with knees bent and feet flat.',
    'Put your hands lightly behind your head or across your chest.',
    'Curl your shoulders off the floor using your stomach.',
    'Lower slowly.',
  ], [
    "Don't pull on your neck.",
  ]),
  'hanging_leg_raise': ExerciseGuide([
    'Hang from a bar with straight arms.',
    'Raise your legs in front of you, as high as you can control.',
    'Lower slowly without swinging.',
  ], [
    'Bend your knees to make it easier.',
  ]),
  'russian_twist': ExerciseGuide([
    'Sit with knees bent and lean back slightly, back straight.',
    'Lift your feet off the floor if you can.',
    'Twist your torso to one side, then the other.',
  ]),
  'ab_wheel': ExerciseGuide([
    'Kneel holding the wheel under your shoulders.',
    'Roll it forward slowly, keeping your back flat.',
    'Go as far as you can control.',
    'Pull it back using your stomach.',
  ], [
    "Don't let your lower back arch.",
  ]),
  'cable_crunch': ExerciseGuide([
    'Kneel facing a high pulley holding a rope by your head.',
    'Crunch down, bringing your elbows toward your knees.',
    'Return slowly.',
  ]),
  'sit_up': ExerciseGuide([
    'Lie on your back, knees bent, feet anchored or flat.',
    'Curl all the way up until your chest is near your knees.',
    'Lower slowly back down.',
  ]),

  // ── Full body & cardio ──
  'kettlebell_swing': ExerciseGuide([
    'Stand with feet wider than hips, kettlebell on the floor in front.',
    'Hinge at your hips and grab it with both hands.',
    'Hike it back between your legs.',
    'Snap your hips forward to swing it to chest height.',
    'Let it swing back down and repeat.',
  ], [
    'Power comes from your hips, not your arms.',
  ]),
  'burpee': ExerciseGuide([
    'Stand tall, then squat down and put your hands on the floor.',
    'Jump your feet back into a push-up position.',
    'Jump your feet back toward your hands.',
    'Jump up with your arms overhead.',
  ], [
    'Step back instead of jumping to make it gentler.',
  ]),
  'jump_squat': ExerciseGuide([
    'Stand with feet shoulder-width apart.',
    'Squat down.',
    'Jump up explosively.',
    'Land softly and go straight into the next squat.',
  ]),
  'mountain_climber': ExerciseGuide([
    'Start in a push-up position.',
    'Drive one knee toward your chest.',
    'Switch legs quickly, like running in place.',
  ], [
    'Keep your hips low.',
  ]),
  'jumping_jacks': ExerciseGuide([
    'Stand with feet together, arms at your sides.',
    'Jump your feet out while raising your arms overhead.',
    'Jump back to the start.',
  ]),
  'jump_rope': ExerciseGuide([
    'Hold the handles at hip height, rope behind you.',
    'Swing it over your head with your wrists.',
    'Hop just high enough to clear it, landing on the balls of your feet.',
  ]),
  'treadmill': ExerciseGuide([
    'Step on, clip the safety key to your clothes.',
    'Start slow to warm up.',
    'Raise the speed or incline to your working pace.',
    'Slow down for a few minutes before stopping.',
  ], [
    "Don't hold the handrails while running.",
  ]),
  'stationary_bike': ExerciseGuide([
    'Set the seat so your knee is slightly bent at the bottom of the pedal stroke.',
    'Start with light resistance to warm up.',
    'Increase resistance or speed for your workout.',
    'Ease off to cool down.',
  ]),
  'rowing_machine': ExerciseGuide([
    'Strap in your feet and grab the handle.',
    'Push with your legs first, then lean back slightly, then pull to your lower ribs.',
    'Return in reverse: arms, then body, then legs.',
  ], [
    'Legs do most of the work — about 60%.',
  ]),

  // ── Home / low-impact alternatives ──
  'band_chest_press': ExerciseGuide([
    'Anchor the band behind you at chest height, a handle in each hand.',
    'Step forward until the band is tight.',
    'Press your hands forward until your arms are straight.',
    'Return slowly.',
  ]),
  'incline_push_up': ExerciseGuide([
    'Put your hands on a bench, table or wall, a little wider than your shoulders.',
    'Walk your feet back so your body is straight.',
    'Lower your chest to the edge.',
    'Push back up.',
  ], [
    'The higher your hands, the easier it gets.',
  ]),
  'band_row': ExerciseGuide([
    'Sit with legs straight and loop the band around your feet.',
    'Hold the ends, sit tall.',
    'Pull your hands to your stomach, squeezing your shoulder blades.',
    'Return slowly.',
  ]),
  'inverted_row': ExerciseGuide([
    'Lie under a sturdy table or low bar and grip its edge.',
    'Straighten your body, heels on the floor.',
    'Pull your chest up to the bar.',
    'Lower slowly.',
  ], [
    'Bend your knees to make it easier.',
  ]),
  'superman': ExerciseGuide([
    'Lie face down, arms stretched overhead.',
    'Lift your arms, chest and legs off the floor.',
    'Hold, looking at the floor.',
  ]),
  'pike_push_up': ExerciseGuide([
    'Start in a push-up position, then walk your feet in and raise your hips into an upside-down V.',
    'Bend your elbows to lower your head toward the floor.',
    'Press back up.',
  ]),
  'band_overhead_press': ExerciseGuide([
    'Stand on the band, handles at your shoulders.',
    'Press your hands overhead until your arms are straight.',
    'Lower slowly.',
  ]),
  'band_pull_apart': ExerciseGuide([
    'Hold a band in front of you at shoulder height, arms straight.',
    'Pull it apart until it touches your chest.',
    'Return slowly.',
  ]),
  'band_curl': ExerciseGuide([
    'Stand on the band, handles in your hands, palms up.',
    'Curl your hands to your shoulders, elbows at your sides.',
    'Lower slowly.',
  ]),
  'band_pushdown': ExerciseGuide([
    'Anchor the band high, above a door for example.',
    'Hold it with elbows at your sides.',
    'Push down until your arms are straight.',
    'Return slowly.',
  ]),
  'diamond_push_up': ExerciseGuide([
    'Get in a push-up position with your hands together under your chest, thumbs and fingers forming a diamond.',
    'Lower your chest to your hands, elbows close to your body.',
    'Push back up.',
  ], [
    'Drop to your knees to make it easier.',
  ]),
  'reverse_lunge_bw': ExerciseGuide([
    'Stand tall, hands on your hips.',
    'Step one foot back.',
    'Lower your back knee toward the floor.',
    'Push through your front foot to return. Alternate legs.',
  ]),
  'step_up': ExerciseGuide([
    'Stand facing a sturdy step or bench.',
    'Put one whole foot on it.',
    'Push through that foot to stand up on top.',
    'Step down slowly and repeat. Switch legs.',
  ]),
  'wall_sit': ExerciseGuide([
    'Lean your back against a wall.',
    'Slide down until your knees are at 90°, like sitting on a chair.',
    'Hold, feet flat.',
  ]),
  'rdl_db': ExerciseGuide([
    'Stand with dumbbells in front of your thighs, knees soft.',
    'Push your hips back, lowering the weights down your legs.',
    'Stop at a strong hamstring stretch, back flat.',
    'Drive your hips forward to stand.',
  ]),
  'single_leg_bridge': ExerciseGuide([
    'Lie on your back, knees bent, then straighten one leg.',
    'Push through the other heel to lift your hips.',
    'Lower slowly. Switch legs.',
  ]),
  'kettlebell_deadlift': ExerciseGuide([
    'Stand over the kettlebell, feet hip-width.',
    'Hinge and bend your knees to grab the handle, back flat.',
    'Stand up by pushing through your feet.',
    'Lower it back the same way.',
  ]),
  'calf_raise_bw': ExerciseGuide([
    'Stand on the edge of a step, heels hanging off.',
    'Rise up onto your toes.',
    'Lower your heels below the step slowly.',
  ], [
    'Hold a wall for balance.',
  ]),
  'dead_bug': ExerciseGuide([
    'Lie on your back, arms up, knees bent at 90° over your hips.',
    'Press your lower back into the floor.',
    'Lower your opposite arm and leg toward the floor.',
    'Return, then switch sides.',
  ]),
  'inchworm': ExerciseGuide([
    'Stand tall, then bend forward and put your hands on the floor.',
    'Walk your hands out to a push-up position.',
    'Walk your feet up to your hands.',
    'Stand up and repeat.',
  ]),
  'squat_to_press_db': ExerciseGuide([
    'Hold dumbbells at your shoulders.',
    'Squat down.',
    'As you stand, press the weights overhead in one smooth move.',
    'Lower them to your shoulders and repeat.',
  ]),
  'march_in_place': ExerciseGuide([
    'Stand tall.',
    'Lift one knee to hip height, then the other.',
    'Swing your arms naturally and keep a steady pace.',
  ]),
  'step_jacks': ExerciseGuide([
    'Stand with feet together.',
    'Step one foot out to the side while raising your arms.',
    'Step it back, then do the other side.',
  ]),
  'shadow_boxing': ExerciseGuide([
    'Stand with one foot forward, fists up by your face.',
    'Throw punches into the air — jabs, crosses, hooks.',
    'Keep moving your feet and keep your hands up.',
  ]),

  // ── Leg day ──
  'hack_squat': ExerciseGuide([
    'Stand on the platform with your back and shoulders against the pads.',
    'Release the safety and squat down.',
    'Push back up through your whole foot.',
  ]),
  'walking_lunge_db': ExerciseGuide([
    'Hold dumbbells at your sides.',
    'Step forward into a lunge.',
    'Push off and bring your back foot forward into the next lunge.',
    'Keep walking.',
  ]),
  'cossack_squat': ExerciseGuide([
    'Stand with your feet very wide.',
    'Shift your weight to one side and squat down on that leg.',
    'Keep the other leg straight, toes up.',
    'Push back to the middle and switch sides.',
  ]),
  'box_jump': ExerciseGuide([
    'Stand in front of a sturdy box.',
    'Swing your arms back and bend your knees.',
    'Jump onto the box, landing softly with both feet.',
    'Step back down — don\'t jump down.',
  ]),
  'sumo_deadlift_bb': ExerciseGuide([
    'Stand with a very wide stance, toes pointing out.',
    'Grip the bar between your legs with your arms straight.',
    'Brace, push your knees out and stand up.',
    'Lower it back under control.',
  ]),
  'hip_abduction': ExerciseGuide([
    'Sit in the machine with the pads on the outside of your knees.',
    'Push your knees apart.',
    'Return slowly.',
  ]),
  'seated_leg_curl': ExerciseGuide([
    'Sit with the pad behind your lower legs and the thigh pad locked down.',
    'Curl your legs down and back.',
    'Return slowly.',
  ]),
  'nordic_curl': ExerciseGuide([
    'Kneel with your ankles anchored under something heavy.',
    'Keeping your hips straight, lean forward as slowly as you can.',
    'Catch yourself with your hands and push back up.',
  ], [
    'Very hard — go slow and use your hands as much as you need.',
  ]),
  'calf_raise_db': ExerciseGuide([
    'Hold dumbbells at your sides.',
    'Rise up onto your toes.',
    'Lower slowly.',
  ]),

  // ── Warm-ups and stretches ──
  'arm_circles': ExerciseGuide([
    'Stand with arms out to the sides.',
    'Make small circles, slowly getting bigger.',
    'Switch direction halfway.',
  ]),
  'leg_swings': ExerciseGuide([
    'Hold a wall for balance.',
    'Swing one leg forward and back.',
    'Then swing it side to side. Switch legs.',
  ]),
  'hip_circles': ExerciseGuide([
    'Stand with hands on your hips.',
    'Circle your hips slowly.',
    'Switch direction.',
  ]),
  'hamstring_stretch': ExerciseGuide([
    'Sit with one leg straight, the other bent.',
    'Reach toward your toes until you feel a stretch.',
    'Hold, then switch legs.',
  ], [
    'Reach from your hips, keeping your back long.',
  ]),
  'quad_stretch': ExerciseGuide([
    'Stand on one leg, holding a wall if needed.',
    'Pull your other heel toward your glutes.',
    'Hold, knees together, then switch.',
  ]),
  'chest_stretch': ExerciseGuide([
    'Stand in a doorway, forearm on the frame at shoulder height.',
    'Step forward until you feel a stretch in your chest.',
    'Hold, then switch sides.',
  ]),
  'hip_flexor_stretch': ExerciseGuide([
    'Kneel on one knee, the other foot in front.',
    'Squeeze your glutes and push your hips forward.',
    'Hold, then switch.',
  ]),
  'childs_pose': ExerciseGuide([
    'Kneel and sit back on your heels.',
    'Fold forward, arms stretched in front.',
    'Rest your forehead on the floor and breathe slowly.',
  ]),
};

/// The guide for a built-in, or general advice for a custom exercise.
ExerciseGuide guideFor({
  String? seedKey,
  required ExerciseKind kind,
  required Equipment equipment,
}) {
  final known = seedKey == null ? null : exerciseGuides[seedKey];
  if (known != null) return known;
  return switch (kind) {
    ExerciseKind.duration => const ExerciseGuide([
      'Set up in your starting position.',
      'Start the timer and hold or keep moving at a steady pace.',
      'Breathe steadily — never hold your breath.',
      'Stop when the time is up, or sooner if your form slips.',
    ]),
    _ => ExerciseGuide([
      if (equipment == Equipment.machine)
        'Adjust the seat and pads so they fit you before you start.',
      'Start light to learn the movement.',
      'Move through your full range of motion with control.',
      'Lift in about 1 second, lower in about 2–3 seconds.',
      'Rest, then repeat for your next set.',
    ], const [
      'Stop if anything hurts sharply — that is pain, not effort.',
    ]),
  };
}
