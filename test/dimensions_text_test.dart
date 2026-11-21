import 'package:flutter_test/flutter_test.dart';
import 'package:studio3/models/piece_summary.dart';
import 'package:studio3/utils/dimensions_text.dart';

void main() {
  test('text dimensions read as they are', () {
    expect(dimensionsText('24x36x1.5 in'), '24x36x1.5 in');
    expect(dimensionsText('  '), isNull);
    expect(dimensionsText(null), isNull);
  });

  test('object dimensions read as the same text', () {
    expect(dimensionsText({'width': 40, 'height': 60, 'unit': 'cm'}), '40x60 cm');
    expect(dimensionsText({'width': 24, 'height': 36, 'depth': 1.5, 'unit': 'in'}), '24x36x1.5 in');
    expect(dimensionsText({'width': 24.0, 'height': 36}), '24x36');
    expect(dimensionsText({'unit': 'cm'}), isNull);
    expect(dimensionsText(42), isNull);
  });

  test('a piece with object dimensions no longer breaks parsing', () {
    final piece = PieceSummary.fromJson({
      'id': 'p1',
      'title': 'Tide',
      'dimensions': {'height': 60, 'unit': 'cm', 'width': 40},
    });
    expect(piece.dimensions, '40x60 cm');
  });
}
