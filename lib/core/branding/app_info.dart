/// Everything the app knows about itself.
///
/// [version] and [buildNumber] mirror the `version:` line in `pubspec.yaml` —
/// constants rather than a `package_info_plus` lookup, the same choice XPENC
/// made: no platform channel, so widget tests need no mock.
/// `test/branding_test.dart` fails the build if the two drift apart.
class AppInfo {
  const AppInfo._();

  static const name = 'FITNS';
  static const tagline = 'Fitness, tracked offline.';

  static const description =
      'Workouts, body metrics and steps — all on this device. Nothing is '
      'ever uploaded.';

  /// The family of apps FITNS belongs to. XPENC was the first.
  static const studio = 'TRAKVRS';
  static const siblingApp = 'XPENC';
  static const siblingUrl = 'https://xpenc.in';

  // ── Version ────────────────────────────────────────────────────────────────
  static const version = '0.1.0';
  static const buildNumber = 9;

  /// `1.0.0 (build 1)` — the string a bug report should quote.
  static const versionLabel = '$version (build $buildNumber)';

  // ── Project ────────────────────────────────────────────────────────────────
  static const repoUrl = 'https://github.com/Parthmagdum/FITNS';
  static const issuesUrl = '$repoUrl/issues';

  /// The privacy policy the store listings link to.
  static const privacyUrl = '$repoUrl/blob/main/PRIVACY.md';
  static const privacySummary =
      'FITNS collects nothing. No accounts, ads, analytics or trackers, and '
      'no internet access — everything stays on this phone. Delete it all '
      'any time in Settings.';

  /// Android application id. Permanent once the app is on the Play Store.
  static const packageId = 'com.trakvrs.fitns';

  static const licenseName = 'MIT License';
  static const copyright = '© 2026 Parth Magdum';
}
