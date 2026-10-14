import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoagent_flutter/src/loading/page_skeletons.dart';
import 'package:neoagent_flutter/src/loading/skeleton.dart';

void main() {
  const sizes = <Size>[Size(375, 640), Size(1280, 800), Size(1280, 320)];

  for (final layout in PageSkeletonLayout.values) {
    for (final size in sizes) {
      testWidgets('${layout.name} skeleton fits ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PageSkeleton(layout: layout)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));

        expect(tester.takeException(), isNull);
        expect(find.byType(SkeletonBlock), findsWidgets);
      });
    }
  }

  testWidgets('reduced motion shows the blocks without the shimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(
          body: PageSkeleton(layout: PageSkeletonLayout.list),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonBlock), findsWidgets);
  });
}
