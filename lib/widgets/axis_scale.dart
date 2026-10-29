import 'dart:math' as math;

/// A "nice" linear y-axis for one chart series: round tick values and a fixed
/// number of intervals.
///
/// Every scale has exactly [intervals] steps, so two series in very different
/// units (e.g. avg weight ~80 and volume ~40000) can share one chart, one axis
/// on each side, with their gridlines lined up. Values are plotted normalized
/// to 0..1 and labels are mapped back with [denormalize].
class AxisScale {
  static const intervals = 4;

  final double min;
  final double step;

  const AxisScale._(this.min, this.step);

  double get max => min + step * intervals;

  factory AxisScale.fit(Iterable<double> values) {
    if (values.isEmpty) return const AxisScale._(0, 0.25);
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final nonNegative = lo >= 0;
    if (hi == lo) {
      // Flat series: give it some room so it sits mid-chart.
      final pad = lo == 0 ? 1.0 : lo.abs() * 0.1;
      lo -= pad;
      hi += pad;
    }

    var step = _niceStep((hi - lo) / intervals);
    while (true) {
      var start = (lo / step).floorToDouble() * step;
      if (nonNegative && start < 0) start = 0;
      if (start + step * intervals >= hi) return AxisScale._(start, step);
      step = _niceStep(step * 1.01); // next nice step up
    }
  }

  /// Mantissas for tick steps. Finer than the classic 1/2/5 so the fixed
  /// interval count still lets the data fill most of the chart.
  static const niceMantissas = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0];

  /// Smallest `m × 10^n` (m in [niceMantissas]) that is >= [raw].
  static double _niceStep(double raw) {
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / magnitude;
    return niceMantissas.firstWhere((m) => m >= f - 1e-9) * magnitude;
  }

  double normalize(double v) => (v - min) / (max - min);

  double denormalize(double t) => min + t * (max - min);

  /// Short tick label: `40.5k` for large values, otherwise at most two
  /// decimals with trailing zeros dropped (`62.5`, `80`, `17.25`).
  static String format(double v) {
    if (v.abs() >= 10000) return '${_trim((v / 1000).toStringAsFixed(1))}k';
    return _trim(v.toStringAsFixed(2));
  }

  static String _trim(String s) =>
      s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}
