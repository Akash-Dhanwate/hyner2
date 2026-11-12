import 'package:flutter_test/flutter_test.dart';
import 'package:hyner/core/performance/performance_recorder.dart';

void main() {
  test('frame window is bounded and reports stage percentiles instead of claiming FPS', () {
    final samples = FramePerformanceWindow(capacity: 3);
    samples.add(99999, 99999);
    samples.add(1000, 4000);
    samples.add(2000, 5000);
    samples.add(20000, 6000);
    expect(samples.length, 3);
    expect(samples.summary['build_p50_us'], 2000);
    expect(samples.summary['build_p95_us'], 20000);
    expect(samples.summary['raster_p99_us'], 6000);
    expect(samples.summary['over_60hz_stage_budget_samples'], 1);
    expect(FramePerformanceWindow().summary['samples'], 0);
  });
}
