import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/music_bridge.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

enum SongRepeat { off, all, one }

@immutable
class MusicState {
  const MusicState({
    this.songs = const [],
    this.index,
    this.playing = false,
    this.shuffle = false,
    this.repeat = SongRepeat.all,
    this.volume = 1,
  });

  final List<Song> songs;

  /// The song loaded, playing or paused; null before any.
  final int? index;
  final bool playing;
  final bool shuffle;
  final SongRepeat repeat;

  /// 0 to 1, FITNS's own — the phone's volume still applies on top.
  final double volume;

  Song? get current =>
      index == null || index! >= songs.length ? null : songs[index!];

  MusicState copyWith({
    List<Song>? songs,
    int? Function()? index,
    bool? playing,
    bool? shuffle,
    SongRepeat? repeat,
    double? volume,
  }) => MusicState(
    songs: songs ?? this.songs,
    index: index == null ? this.index : index(),
    playing: playing ?? this.playing,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    volume: volume ?? this.volume,
  );
}

/// [Settings.musicTracks] → songs. Anything unreadable is dropped.
List<Song> decodeSongs(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    return [
      for (final s in (jsonDecode(raw) as List).whereType<Map>())
        if (s['uri'] case final String uri)
          (uri: uri, title: '${s['title'] ?? 'Song'}'),
    ];
  } on FormatException {
    return const [];
  }
}

String encodeSongs(List<Song> songs) => jsonEncode([
  for (final s in songs) {'uri': s.uri, 'title': s.title},
]);

/// Workout music: the user's imported songs, played in order or shuffled,
/// on repeat or not. Android plays them; this keeps the list and decides
/// what's next.
class MusicController extends StateNotifier<MusicState> {
  MusicController(this._db, this._bridge, {Random? random})
    : _random = random ?? Random(),
      super(const MusicState()) {
    _bridge.listen(_onEvent);
    _load();
  }

  final AppDatabase _db;
  final MusicBridge _bridge;
  final Random _random;

  /// Songs in a row that wouldn't play — all of them means stop trying.
  var _failures = 0;

  Future<void> _load() async {
    final songs = decodeSongs((await _db.getSettings()).musicTracks);
    if (mounted) state = state.copyWith(songs: songs);
  }

  Future<void> _save() => _db.updateSettings(
    SettingsCompanion(musicTracks: Value(encodeSongs(state.songs))),
  );

  void _onEvent(String event) {
    switch (event) {
      case 'completed':
        _failures = 0;
        next(auto: true);
      case 'failed':
        if (++_failures >= state.songs.length) {
          _failures = 0;
          state = state.copyWith(playing: false);
        } else {
          next(auto: true, skipping: true);
        }
      case 'paused':
        state = state.copyWith(playing: false);
      case 'resumed':
        state = state.copyWith(playing: true);
    }
  }

  /// Opens the file picker and adds what's chosen (no duplicates).
  Future<int> importSongs() async {
    final picked = await _bridge.pick();
    final known = {for (final s in state.songs) s.uri};
    final added = [
      for (final s in picked)
        if (known.add(s.uri)) s,
    ];
    if (added.isEmpty) return 0;
    state = state.copyWith(songs: [...state.songs, ...added]);
    await _save();
    return added.length;
  }

  Future<void> remove(int i) async {
    final songs = [...state.songs]..removeAt(i);
    final current = state.index;
    if (current == i) await _bridge.stop();
    state = state.copyWith(
      songs: songs,
      index: () => current == null || current == i
          ? null
          : (current > i ? current - 1 : current),
      playing: current == i ? false : state.playing,
    );
    await _save();
  }

  Future<void> playAt(int i) async {
    if (i < 0 || i >= state.songs.length) return;
    state = state.copyWith(index: () => i, playing: true);
    if (!await _bridge.play(state.songs[i].uri)) _onEvent('failed');
  }

  /// Play or pause; the first song if nothing is loaded yet.
  Future<void> toggle() async {
    if (state.songs.isEmpty) return;
    if (state.current == null) {
      await playAt(state.shuffle ? _random.nextInt(state.songs.length) : 0);
    } else if (state.playing) {
      state = state.copyWith(playing: false);
      await _bridge.pause();
    } else {
      state = state.copyWith(playing: true);
      await _bridge.resume();
    }
  }

  /// The next song. [auto] when the last one ended by itself: "repeat one"
  /// plays it again, and with repeat off the list stops at its end.
  Future<void> next({bool auto = false, bool skipping = false}) async {
    final n = state.songs.length;
    if (n == 0) return;
    final i = state.index;
    if (auto && !skipping && state.repeat == SongRepeat.one && i != null) {
      return playAt(i);
    }
    if (state.shuffle && n > 1) {
      var pick = _random.nextInt(n - 1);
      if (i != null && pick >= i) pick++;
      return playAt(pick);
    }
    final after = (i ?? -1) + 1;
    if (after < n) return playAt(after);
    if (state.repeat == SongRepeat.off && auto) {
      state = state.copyWith(playing: false);
      await _bridge.stop();
      return;
    }
    return playAt(0);
  }

  Future<void> previous() async {
    final n = state.songs.length;
    if (n == 0) return;
    final i = state.index ?? 0;
    return playAt(i > 0 ? i - 1 : n - 1);
  }

  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  void cycleRepeat() => state = state.copyWith(
    repeat: SongRepeat.values[(state.repeat.index + 1) % 3],
  );

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: v.clamp(0, 1));
    await _bridge.setVolume(state.volume);
  }
}

final musicBridgeProvider = Provider<MusicBridge>((ref) => const MusicBridge());

final musicProvider = StateNotifierProvider<MusicController, MusicState>(
  (ref) =>
      MusicController(ref.watch(dbProvider), ref.watch(musicBridgeProvider)),
);
