import 'dart:io';

import 'package:fitns/data/food_library.dart';
import 'package:fitns/data/image_assets.dart';
import 'package:fitns/data/pictures.dart';
import 'package:fitns/data/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every library food has a photo, and every photo is there', () {
    for (final f in foodLibrary) {
      expect(foodPhoto(f.name), isNotNull, reason: f.name);
    }
    for (final path in foodPhotos.values) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('food photos match saved foods that kept the name', () {
    expect(foodPhoto('banana'), foodPhoto('Banana'));
    expect(foodPhoto('Grandma’s special'), isNull);
  });

  test('exercise photos belong to built-in exercises and are there', () {
    final keys = {for (final e in seedExercises) e.key};
    for (final MapEntry(:key, :value) in exercisePhotoCounts.entries) {
      expect(keys, contains(key));
      expect(value, greaterThan(0));
      for (final path in exercisePhotos(key)) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
    expect(exercisePhotos(null), isEmpty);
    expect(exercisePhotos('no_such_exercise'), isEmpty);
  });

  test('nothing in assets is left unused', () {
    final used = {
      ...foodPhotos.values,
      for (final key in exercisePhotoCounts.keys) ...exercisePhotos(key),
    };
    for (final dir in ['assets/food', 'assets/exercises']) {
      for (final f in Directory(dir).listSync().whereType<File>()) {
        expect(used, contains(f.path.replaceAll(r'\', '/')), reason: f.path);
      }
    }
  });

  test('every food photo is credited, under a free licence', () {
    final credited = {for (final c in foodPhotoCredits) c.source};
    expect(credited, hasLength(foodPhotoCredits.length));
    final free = RegExp(r'^(CC0|Public domain|CC BY(-SA)? [0-9.]+)');
    for (final c in foodPhotoCredits) {
      expect(c.license, matches(free), reason: c.subject);
      expect(c.author.trim(), isNotEmpty, reason: c.subject);
      expect(c.source, startsWith('https://commons.wikimedia.org/'));
    }
    // One credit per distinct photo.
    expect(foodPhotoCredits.length, foodPhotos.values.toSet().length);
  });

  test('CREDITS.md lists every food photo', () {
    final md = File('CREDITS.md').readAsStringSync();
    for (final c in foodPhotoCredits) {
      expect(md, contains(c.source), reason: c.subject);
    }
  });
}
