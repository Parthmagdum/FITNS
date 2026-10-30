import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/body/body_screen.dart';
import '../../data/database.dart' show Meal;
import '../../features/exercises/exercise_picker_screen.dart';
import '../../features/food/food_picker_screen.dart';
import '../../features/food/food_screen.dart';
import '../../features/food/goals_screen.dart';
import '../../features/routines/routine_editor_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/workouts/active_workout_screen.dart';
import '../../features/workouts/auto_count_screen.dart';
import '../../features/workouts/workout_detail_screen.dart';
import '../../features/workouts/workouts_screen.dart';
import 'app_shell.dart';

/// One router per [ProviderScope], so each widget test starts at `/today`.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workouts',
                builder: (_, _) => const WorkoutsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/food', builder: (_, _) => const FoodScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/body', builder: (_, _) => const BodyScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen pages, above the tab bar.
      GoRoute(
        path: '/workout/:id/count/:itemId',
        builder: (_, state) => AutoCountScreen(
          workoutId: _id(state, 'id'),
          itemId: _id(state, 'itemId'),
        ),
      ),
      GoRoute(
        path: '/workout/:id/log',
        builder: (_, state) => ActiveWorkoutScreen(workoutId: _id(state, 'id')),
      ),
      GoRoute(
        path: '/workout/:id',
        builder: (_, state) => WorkoutDetailScreen(workoutId: _id(state, 'id')),
      ),
      GoRoute(
        path: '/routine/new',
        builder: (_, _) => const RoutineEditorScreen(),
      ),
      GoRoute(
        path: '/routine/:id',
        builder: (_, state) => RoutineEditorScreen(routineId: _id(state, 'id')),
      ),
      GoRoute(
        path: '/exercises/pick',
        builder: (_, _) => const ExercisePickerScreen(),
      ),
      GoRoute(
        path: '/food/add/:day/:meal',
        builder: (_, state) => FoodPickerScreen(
          day: DateTime.parse(state.pathParameters['day']!),
          meal: Meal.values.byName(state.pathParameters['meal']!),
        ),
      ),
      GoRoute(path: '/settings/goals', builder: (_, _) => const GoalsScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

int _id(GoRouterState state, String name) =>
    int.parse(state.pathParameters[name]!);
