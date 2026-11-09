// Development tool: measures the signature effects on a real device.
//   flutter build apk --profile --dart-define=MN_PERF=true
// then launch the app and read `adb logcat -s flutter | grep MN_PERF`.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme.dart';
import '../features/sales/sale_success_mark.dart';
import '../shared/motion/fire.dart';

/// Never true in release builds.
const devPerfHarnessEnabled = !kReleaseMode && bool.fromEnvironment('MN_PERF');

class PerfHarness extends StatefulWidget {
  const PerfHarness({super.key});

  @override
  State<PerfHarness> createState() => _PerfHarnessState();
}

class _PerfHarnessState extends State<PerfHarness> {
  final _timings = <FrameTiming>[];
  Widget _stage = const SizedBox();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_timings.addAll);
    _run();
  }

  void _report(String name) {
    if (_timings.isEmpty) {
      debugPrint('MN_PERF $name no frames (screen off?)');
      return;
    }
    List<double> ms(Duration Function(FrameTiming) f) =>
        _timings.map((t) => f(t).inMicroseconds / 1000).toList()..sort();
    double pct(List<double> v, double p) =>
        v[math.min(v.length - 1, (v.length * p).floor())];
    final build = ms((t) => t.buildDuration);
    final raster = ms((t) => t.rasterDuration);
    final total = ms((t) => t.totalSpan);
    final janky = total.where((v) => v > 1000 / 60).length;
    debugPrint('MN_PERF $name frames=${_timings.length} '
        'build_avg=${(build.reduce((a, b) => a + b) / build.length).toStringAsFixed(2)} '
        'build_p90=${pct(build, .9).toStringAsFixed(2)} '
        'raster_avg=${(raster.reduce((a, b) => a + b) / raster.length).toStringAsFixed(2)} '
        'raster_p90=${pct(raster, .9).toStringAsFixed(2)} '
        'raster_p99=${pct(raster, .99).toStringAsFixed(2)} '
        'worst_total=${total.last.toStringAsFixed(2)} '
        'over_16ms=$janky');
    _timings.clear();
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    _timings.clear();
    setState(() => _stage = Stack(children: [
          Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              height: 300,
              child: FireCanvas(spec: FireSpec.fungaSiku())),
        ]));
    await Future<void>.delayed(const Duration(milliseconds: 5000));
    _report('funga_siku_fire');
    for (var i = 0; i < 5; i++) {
      setState(() => _stage =
          Center(child: SaleSuccessMark(key: ValueKey(i), playId: 'perf-$i')));
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    _report('sale_success_x5');
    debugPrint('MN_PERF done');
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: MaterialApp(
          theme: mrNyamaTheme(),
          home: Scaffold(
              backgroundColor: MNColors.charcoal,
              body: _stage is Center
                  ? ColoredBox(color: MNColors.white, child: _stage)
                  : _stage),
        ),
      );
}
