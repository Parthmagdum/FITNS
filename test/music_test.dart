import 'dart:math';

import 'package:drift/native.dart';
import 'package:fitns/core/platform/music_bridge.dart';
import 'package:fitns/core/theme/app_theme.dart';
import 'package:fitns/data/backup.dart';
import 'package:fitns/data/database.dart';
import 'package:fitns/data/providers.dart';
import 'package:fitns/features/music/music_controller.dart';
import 'package:fitns/features/music/music_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android's side, played by hand.
class FakeMusic extends MusicBridge {
  final calls = <String>[];
  void Function(String)? _events;
  var picks = <Song>[];
  var installedApps = <String>{};
  var playable = true;

  void emit(String event) => _events!(event);

  @override
  void listen(void Function(String) onEvent) => _events = onEvent;
  @override
  Future<List<Song>> pick() async => picks;
  @override
  Future<bool> play(String uri) async {
    calls.add('play $uri');
    return playable;
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> setVolume(double value) async => calls.add('volume $value');
  @override
  Future<Set<String>> installed(List<String> packages) async =>
      installedApps.intersection(packages.toSet());
  @override
  Future<bool> open(String? package) async {
    calls.add('open $package');
    return true;
  }
}

Song song(String n) => (uri: 'content://music/$n', title: n);

void main() {
  late AppDatabase db;
  late FakeMusic android;
  late MusicController music;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    android = FakeMusic();
    music = MusicController(db, android, random: Random(1));
    await pumpEventQueue();
  });
  tearDown(() async {
    music.dispose();
    await db.close();
  });

  Future<void> withSongs(List<String> names) async {
    android.picks = [for (final n in names) song(n)];
    await music.importSongs();
  }

  test('imported songs are kept, without duplicates', () async {
    await withSongs(['a', 'b']);
    android.picks = [song('b'), song('c')];
    expect(await music.importSongs(), 1);
    expect(music.state.songs.map((s) => s.title), ['a', 'b', 'c']);
    // A fresh start reads them back.
    final again = MusicController(db, FakeMusic());
    addTearDown(again.dispose);
    await pumpEventQueue();
    expect(again.state.songs, hasLength(3));
  });

  test('play, pause, carry on', () async {
    await withSongs(['a', 'b']);
    await music.toggle();
    expect(music.state.current!.title, 'a');
    expect(music.state.playing, isTrue);
    await music.toggle();
    expect(music.state.playing, isFalse);
    await music.toggle();
    expect(android.calls, ['play content://music/a', 'pause', 'resume']);
  });

  test('a finished song moves on, and the list repeats by default', () async {
    await withSongs(['a', 'b']);
    await music.playAt(1);
    android.emit('completed');
    await pumpEventQueue();
    expect(music.state.current!.title, 'a');
  });

  test('repeat one plays it again; repeat off stops at the end', () async {
    await withSongs(['a', 'b']);
    music.cycleRepeat(); // all → one
    expect(music.state.repeat, SongRepeat.one);
    await music.playAt(0);
    android.emit('completed');
    await pumpEventQueue();
    expect(music.state.current!.title, 'a');
    // But Next still skips.
    await music.next();
    expect(music.state.current!.title, 'b');

    music.cycleRepeat(); // one → off
    android.emit('completed');
    await pumpEventQueue();
    expect(music.state.playing, isFalse);
    expect(android.calls.last, 'stop');
  });

  test('shuffle never picks the same song twice in a row', () async {
    await withSongs(['a', 'b', 'c', 'd']);
    music.toggleShuffle();
    await music.playAt(2);
    for (var i = 0; i < 20; i++) {
      final before = music.state.index;
      await music.next();
      expect(music.state.index, isNot(before));
    }
  });

  test('a song that won\'t play is skipped; none playing stops', () async {
    await withSongs(['a', 'b']);
    android.playable = false;
    await music.playAt(0);
    await pumpEventQueue();
    expect(music.state.playing, isFalse);
  });

  test('a call pauses it, and it carries on after', () async {
    await withSongs(['a']);
    await music.toggle();
    android.emit('paused');
    expect(music.state.playing, isFalse);
    android.emit('resumed');
    expect(music.state.playing, isTrue);
  });

  test('removing the song playing stops it', () async {
    await withSongs(['a', 'b', 'c']);
    await music.playAt(2);
    await music.remove(0);
    expect(music.state.index, 1);
    expect(music.state.current!.title, 'c');
    await music.remove(1);
    expect(music.state.current, isNull);
    expect(android.calls.last, 'stop');
  });

  test('songs are links to this phone: left out of backups', () async {
    await withSongs(['a']);
    final json = await BackupService(db).export();
    expect(json, isNot(contains('content://music/a')));
    // And a restore keeps the phone's own list.
    await BackupService(db).restore(BackupService(db).parse(json));
    expect(decodeSongs((await db.getSettings()).musicTracks), hasLength(1));
  });

  test('stored songs survive junk', () {
    expect(decodeSongs('not json'), isEmpty);
    expect(decodeSongs('[{"title": "no uri"}, {"uri": "x"}]'), [
      (uri: 'x', title: 'Song'),
    ]);
    expect(decodeSongs(encodeSongs([song('a')])), [song('a')]);
  });

  testWidgets('the sheet plays, adds songs, and opens music apps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final fake = FakeMusic()
      ..picks = [song('Warm up'), song('Sprint')]
      ..installedApps = {'com.spotify.music'};
    final widgetDb = AppDatabase(NativeDatabase.memory());
    addTearDown(widgetDb.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(widgetDb),
          musicBridgeProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: Row(children: [MusicButton()]),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.tap(find.byTooltip('Music'));
    await tester.pumpAndSettle();
    // Which apps are installed arrives a moment later.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No songs yet'), findsOneWidget);
    expect(find.text('Spotify', skipOffstage: false), findsOneWidget);
    expect(find.text('YouTube Music', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Add songs'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Added 2 songs'), findsOneWidget);
    expect(find.text('Sprint'), findsOneWidget);

    await tester.tap(find.text('Sprint'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('play content://music/Sprint'));
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Spotify'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'open com.spotify.music');
    await tester.pumpWidget(const SizedBox());
  });
}
