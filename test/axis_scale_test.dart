import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/widgets/axis_scale.dart';

void main() {
  void expectCovers(AxisScale s, Iterable<double> values) {
    for (final v in values) {
      expect(s.min, lessThanOrEqualTo(v), reason: 'min ${s.min} > $v');
      expect(s.max, greaterThanOrEqualTo(v), reason: 'max ${s.max} < $v');
      final t = s.normalize(v);
      expect(t, inInclusiveRange(0, 1));
      expect(s.denormalize(t), closeTo(v, 1e-9));
    }
  }

  bool isNice(double step) {
    var m = step;
    while (m >= 10) {
      m /= 10;
    }
    while (m < 1) {
      m *= 10;
    }
    return AxisScale.niceMantissas.any((n) => (n - m).abs() < 1e-9);
  }

  /// Fraction of the axis the data actually spans.
  double fill(AxisScale s, List<double> v) =>
      (v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b)) /
      (s.max - s.min);

  group('AxisScale.fit', () {
    test('covers the data with round ticks', () {
      final values = [62.3, 80.0, 131.0];
      final s = AxisScale.fit(values);
      expectCovers(s, values);
      expect(isNice(s.step), isTrue, reason: 'step ${s.step}');
      expect(s.min % s.step, closeTo(0, 1e-9));
    });

    test('large values (volume) fill most of the chart', () {
      final values = [21500.0, 40517.5];
      final s = AxisScale.fit(values);
      expectCovers(s, values);
      expect(isNice(s.step), isTrue, reason: 'step ${s.step}');
      expect(fill(s, values), greaterThan(0.6), reason: '${s.min}..${s.max}');
    });

    test('data fills a good share of the axis across magnitudes', () {
      for (final values in [
        [21500.0, 40517.5],
        [62.3, 131.0],
        [17.4, 22.3],
        [77.6, 84.4],
        [0.12, 0.97],
        [102.0, 105.0],
      ]) {
        final s = AxisScale.fit(values);
        expectCovers(s, values);
        expect(fill(s, values), greaterThan(0.5),
            reason: '$values -> ${s.min}..${s.max}');
      }
    });

    test('non-negative data never gets a negative axis', () {
      final s = AxisScale.fit([0.5, 3, 9]);
      expect(s.min, greaterThanOrEqualTo(0));
    });

    test('negative data is supported', () {
      final values = [-12.0, 7.0];
      expectCovers(AxisScale.fit(values), values);
    });

    test('flat series gets padded and stays inside', () {
      final s = AxisScale.fit([80, 80, 80]);
      expect(s.max, greaterThan(s.min));
      expect(s.normalize(80), inExclusiveRange(0, 1));
    });

    test('all-zero series (bodyweight exercise)', () {
      final s = AxisScale.fit([0, 0]);
      expect(s.min, 0);
      expect(s.max, greaterThan(0));
      expect(s.normalize(0), 0);
    });

    test('single value and empty input do not throw', () {
      expectCovers(AxisScale.fit([17.25]), [17.25]);
      expect(AxisScale.fit(const []).max, greaterThan(0));
    });

    test('always has the fixed number of intervals', () {
      for (final values in [
        [1.0, 2.0],
        [0.0, 999.0],
        [17.0, 22.0],
        [84.0, 78.0],
      ]) {
        final s = AxisScale.fit(values);
        expect((s.max - s.min) / s.step,
            closeTo(AxisScale.intervals.toDouble(), 1e-9));
      }
    });
  });

  group('AxisScale.format', () {
    test('drops trailing zeros', () {
      expect(AxisScale.format(80), '80');
      expect(AxisScale.format(62.5), '62.5');
      expect(AxisScale.format(17.25), '17.25');
      expect(AxisScale.format(0), '0');
    });

    test('abbreviates large values', () {
      expect(AxisScale.format(40000), '40k');
      expect(AxisScale.format(42500), '42.5k');
      expect(AxisScale.format(9999), '9999');
    });
  });
}
