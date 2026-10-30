import 'dart:io';

import 'package:fitns/core/branding/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppInfo version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\+(\d+)',
      multiLine: true,
    ).firstMatch(pubspec)!;
    expect(AppInfo.version, match.group(1));
    expect(AppInfo.buildNumber, int.parse(match.group(2)!));
  });

  test('AppInfo package id matches the Android applicationId', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "${AppInfo.packageId}"'));
  });
}
