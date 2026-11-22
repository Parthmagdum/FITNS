import 'package:fitns/core/routing/hold_menu_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The logo button in the bottom-right corner of a 360-wide phone.
  const anchor = Offset(313, 720);

  test('12 items fan up and left from the corner on three rings', () {
    final centres = cornerFanCenters(anchor, 12);
    expect(centres, hasLength(12));
    for (final c in centres) {
      // Never right of the button, never off the left edge.
      expect(c.dx, lessThanOrEqualTo(anchor.dx + 1));
      expect(c.dx, greaterThan(28));
      // Never below it.
      expect(c.dy, lessThanOrEqualTo(anchor.dy + 1));
    }
    // No two bubbles (54 across) overlap.
    for (var i = 0; i < centres.length; i++) {
      for (var j = i + 1; j < centres.length; j++) {
        expect((centres[i] - centres[j]).distance, greaterThan(60));
      }
    }
    // Ring by ring outwards: the tabs (the last five) are the outer ring.
    final d = [for (final c in centres) (c - anchor).distance];
    expect(d.take(3).every((r) => r < 110), isTrue);
    expect(d.skip(7).every((r) => r > 230), isTrue);
  });

  test('fewer items fill the inner rings first', () {
    final centres = cornerFanCenters(anchor, 4);
    expect(centres, hasLength(4));
    expect((centres[3] - anchor).distance, greaterThan(150));
  });

  test('the bubble under the thumb, or none back on the button', () {
    final centres = cornerFanCenters(anchor, 12);
    for (final i in [0, 5, 11]) {
      expect(
        fanHoveredIndex(anchor: anchor, pointer: centres[i], centres: centres),
        i,
      );
    }
    expect(
      fanHoveredIndex(
        anchor: anchor,
        pointer: centres[4] + const Offset(15, 10),
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
