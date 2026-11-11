import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'music_controller.dart';

/// A streaming app FITNS can open: it doesn't play their music itself.
typedef MusicApp = ({String package, String name, Color color});

/// Must match the `<queries>` packages in AndroidManifest.xml.
const musicApps = <MusicApp>[
  (package: 'com.spotify.music', name: 'Spotify', color: Color(0xFF1DB954)),
  (
    package: 'com.google.android.apps.youtube.music',
    name: 'YouTube Music',
    color: Color(0xFFFF0000),
  ),
  (
    package: 'com.jio.media.jiobeats',
    name: 'JioSaavn',
    color: Color(0xFF2BC5B4),
  ),
  (package: 'com.gaana', name: 'Gaana', color: Color(0xFFE72C30)),
  (package: 'com.bsbportal.music', name: 'Wynk', color: Color(0xFFE41F2D)),
  (
    package: 'com.apple.android.music',
    name: 'Apple Music',
    color: Color(0xFFFA2D48),
  ),
  (package: 'com.amazon.mp3', name: 'Amazon Music', color: Color(0xFF25D1DA)),
  (
    package: 'com.soundcloud.android',
    name: 'SoundCloud',
    color: Color(0xFFFF5500),
  ),
  (package: 'deezer.android.app', name: 'Deezer', color: Color(0xFFA238FF)),
];

/// The streaming apps installed on this phone.
final installedMusicAppsProvider = FutureProvider<List<MusicApp>>((ref) async {
  final installed = await ref.watch(musicBridgeProvider).installed([
    for (final a in musicApps) a.package,
  ]);
  return [
    for (final a in musicApps)
      if (installed.contains(a.package)) a,
  ];
});

/// The music button for a workout or Today: a filled note while playing.
class MusicButton extends ConsumerWidget {
  const MusicButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(musicProvider.select((m) => m.playing));
    return IconButton(
      tooltip: 'Music',
      color: playing ? Theme.of(context).accent : null,
      onPressed: () => showMusicSheet(context),
      icon: Icon(playing ? Icons.music_note : Icons.music_note_outlined),
    );
  }
}

Future<void> showMusicSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (context, controller) => _MusicSheet(controller: controller),
  ),
);

class _MusicSheet extends ConsumerWidget {
  const _MusicSheet({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final music = ref.watch(musicProvider);
    final player = ref.read(musicProvider.notifier);
    final apps = ref.watch(installedMusicAppsProvider).valueOrNull ?? const [];
    final current = music.current;
    final hasSongs = music.songs.isNotEmpty;

    Future<void> import() async {
      final messenger = ScaffoldMessenger.of(context);
      final added = await player.importSongs();
      if (added > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added $added ${added == 1 ? 'song' : 'songs'}'),
          ),
        );
      }
    }

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('Music', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        // Now playing.
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: theme.accentGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                music.playing ? Icons.graphic_eq : Icons.music_note,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current?.title ??
                        (hasSongs ? 'Ready when you are' : 'No songs yet'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    hasSongs
                        ? 'Your songs · ${music.songs.length}'
                        : 'Add songs from this phone, or open a music app',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Controls.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: music.shuffle ? 'Shuffle on' : 'Shuffle off',
              color: music.shuffle ? theme.accent : theme.muted,
              onPressed: hasSongs ? player.toggleShuffle : null,
              icon: const Icon(Icons.shuffle),
            ),
            IconButton(
              tooltip: 'Previous',
              iconSize: 34,
              onPressed: hasSongs ? player.previous : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
            Material(
              color: hasSongs ? theme.accent : theme.track,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: music.playing ? 'Pause' : 'Play',
                iconSize: 40,
                color: Colors.white,
                padding: const EdgeInsets.all(14),
                onPressed: hasSongs ? player.toggle : null,
                icon: Icon(
                  music.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              iconSize: 34,
              onPressed: hasSongs ? player.next : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
            IconButton(
              tooltip: switch (music.repeat) {
                SongRepeat.off => 'Repeat off',
                SongRepeat.all => 'Repeat all',
                SongRepeat.one => 'Repeat one',
              },
              color: music.repeat == SongRepeat.off
                  ? theme.muted
                  : theme.accent,
              onPressed: hasSongs ? player.cycleRepeat : null,
              icon: Icon(
                music.repeat == SongRepeat.one
                    ? Icons.repeat_one
                    : Icons.repeat,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(Icons.volume_down, color: theme.muted),
            Expanded(
              child: Slider(
                value: music.volume,
                onChanged: hasSongs ? player.setVolume : null,
              ),
            ),
            Icon(Icons.volume_up, color: theme.muted),
          ],
        ),
        const SizedBox(height: 8),
        // Your songs.
        Row(
          children: [
            Expanded(
              child: Text('Your songs', style: theme.textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: import,
              icon: const Icon(Icons.add),
              label: const Text('Add songs'),
            ),
          ],
        ),
        if (!hasSongs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Pick music files saved on this phone. They play right here '
              'in FITNS, offline, and stay in this list.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          ),
        for (final (i, song) in music.songs.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              i == music.index && music.playing
                  ? Icons.graphic_eq
                  : Icons.music_note_outlined,
              color: i == music.index ? theme.accent : theme.muted,
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: i == music.index
                  ? TextStyle(color: theme.accent, fontWeight: FontWeight.w700)
                  : null,
            ),
            onTap: () => player.playAt(i),
            trailing: IconButton(
              tooltip: 'Remove ${song.title}',
              onPressed: () => player.remove(i),
              icon: Icon(Icons.close, color: theme.muted),
            ),
          ),
        const SizedBox(height: 20),
        // Streaming apps.
        Text('Play from an app', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Opens the app, so you can start your playlist. Then come back to '
          'your workout.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final app in apps)
              ActionChip(
                avatar: CircleAvatar(backgroundColor: app.color, radius: 8),
                label: Text(app.name),
                onPressed: () =>
                    ref.read(musicBridgeProvider).open(app.package),
              ),
            ActionChip(
              avatar: const Icon(Icons.library_music_outlined, size: 18),
              label: const Text('Your music app'),
              onPressed: () => ref.read(musicBridgeProvider).open(null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Songs keep playing while you use other apps, and stop when you '
          'close FITNS.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
        ),
      ],
    );
  }
}
