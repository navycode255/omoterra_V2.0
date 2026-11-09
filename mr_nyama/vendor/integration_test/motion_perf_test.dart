// Device performance of the signature effects, in profile mode:
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/motion_perf_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mr_nyama_vendor/core/theme/theme.dart';
import 'package:mr_nyama_vendor/features/sales/sale_success_mark.dart';
import 'package:mr_nyama_vendor/shared/motion/fire.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Funga Siku fire sweep', (tester) async {
    await binding.watchPerformance(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          backgroundColor: MNColors.charcoal,
          body: Stack(children: [
            Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                height: 300,
                child: FireCanvas(spec: FireSpec.fungaSiku())),
          ]),
        ),
      ));
      // The full effect: ignition through the idle flame dying out.
      await tester.pumpAndSettle(const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 8));
    }, reportKey: 'funga_siku');
  });

  testWidgets('Sale success mark', (tester) async {
    await binding.watchPerformance(() async {
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(ProviderScope(
          key: ValueKey(i),
          child: MaterialApp(
            home: Scaffold(
                body: Center(child: SaleSuccessMark(playId: 'sale-$i'))),
          ),
        ));
        await tester.pumpAndSettle();
      }
    }, reportKey: 'sale_success');
  });
}
