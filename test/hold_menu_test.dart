import 'package:fitns/core/routing/hold_menu_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void fansOutClear(List<Offset> centres, Offset anchor, {bool above = true}) {
    expect(centres, hasLength(6));
    for (final c in centres) {
      // Above the ➕, clear of the tab bar (Glass's last bubble sits
      // straight left of it, over the tab capsule, as in XPENC).
      if (above) expect(anchor.dy - c.dy, greaterThan(60));
    }
    // No two bubbles (56 across) overlap.
    for (var i = 0; i < centres.length; i++) {
      for (var j = i + 1; j < centres.length; j++) {
        expect((centres[i] - centres[j]).distance, greaterThan(60));
      }
    }
  }

  test('Classic fans straight up over the ➕ in the middle', () {
    const anchor = Offset(180, 740);
    final centres = classicFanCenters(anchor, 6);
    fansOutClear(centres, anchor);
    expect(centres.first.dx, lessThan(anchor.dx));
    expect(centres[2].dx, greaterThan(anchor.dx));
    for (final c in centres) {
      expect(c.dx, inInclusiveRange(28, 360 - 28));
    }
  });

  test('Glass fans up and left from the corner', () {
    const anchor = Offset(320, 740);
    final centres = glassFanCenters(anchor, 6);
    fansOutClear(centres, anchor, above: false);
    for (final c in centres) {
      expect(c.dx, lessThanOrEqualTo(anchor.dx + 1));
      expect(c.dx, greaterThan(28));
    }
  });

  test('the bubble under the thumb, or none back on the ➕', () {
    const anchor = Offset(180, 740);
    final centres = classicFanCenters(anchor, 6);
    expect(
      fanHoveredIndex(anchor: anchor, pointer: centres[4], centres: centres),
      4,
    );
    expect(
      fanHoveredIndex(
        anchor: anchor,
        pointer: centres[4] + const Offset(20, 10),
        centres: centres,
      ),
      4,
    );
    expect(
      fanHoveredIndex(
        anchor: anchor,
        pointer: anchor + const Offset(5, -5),
        centres: centres,
      ),
      -1,
    );
  });
}
