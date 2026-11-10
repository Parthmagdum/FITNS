import 'image_assets.dart';

export 'image_assets.dart' show ImageCredit, foodPhotoCredits;

/// The bundled photo for a food, by name — library foods, and the user's
/// saved foods that kept a library name. Null for anything else, which
/// falls back to an emoji.
String? foodPhoto(String name) =>
    foodPhotos[name] ?? _foodPhotosLower[name.trim().toLowerCase()];

final _foodPhotosLower = {
  for (final MapEntry(:key, :value) in foodPhotos.entries)
    key.toLowerCase(): value,
};

/// The bundled photos of a built-in exercise, start position first. Empty
/// for the user's own exercises and the few without a faithful photo.
List<String> exercisePhotos(String? seedKey) {
  final count = seedKey == null ? 0 : exercisePhotoCounts[seedKey] ?? 0;
  return [
    for (var i = 0; i < count; i++) 'assets/exercises/${seedKey}_$i.webp',
  ];
}

/// Where the exercise photos come from: one public-domain collection.
const exercisePhotoSource = (
  name: 'free-exercise-db',
  author: 'yuhonas and contributors',
  license: 'Public domain (Unlicense)',
  url: 'https://github.com/yuhonas/free-exercise-db',
);
