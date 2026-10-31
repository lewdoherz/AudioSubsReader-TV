import 'dart:io';

import 'package:audiosubs_reader/appearance.dart';
import 'package:audiosubs_reader/appearance_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('font and exact custom RGB work without opening a keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 540);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('tv-appearance-'),
    ))!;
    final file = File('${directory.path}/appearance.json');
    await tester.runAsync(
      () => file.writeAsString('{"schemaVersion":1,"fontSize":32}'),
    );
    final controller = (await tester.runAsync(
      () => AppearanceController.load(file),
    ))!;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: controller.value.theme(Brightness.dark),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAppearancePanel(context, controller),
                child: const Text('Open appearance'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open appearance'));
      await tester.pumpAndSettle();
      final increase = find.byTooltip('Increase book size');
      await tester.ensureVisible(increase);
      await tester.runAsync(() => tester.tap(increase));
      await tester.pump();
      expect(controller.value.fontSize, 33);
      final decrease = find.byTooltip('Decrease book size');
      await tester.ensureVisible(decrease);
      await tester.runAsync(() => tester.tap(decrease));
      await tester.pump();
      expect(controller.value.fontSize, 32);

      final redRow = find.ancestor(
        of: find.text('Red 128'),
        matching: find.byType(Row),
      );
      final redPlus = find.descendant(of: redRow, matching: find.text('+1'));
      await tester.ensureVisible(redPlus);
      await tester.runAsync(() => tester.tap(redPlus));
      await tester.pump();
      expect(controller.value.highlightArgb, 0xff81cbc4);
      expect(find.text('Red 129'), findsOneWidget);
      expect(tester.view.viewInsets.bottom, 0);
      await tester.runAsync(controller.flush);
      final restored = (await tester.runAsync(
        () => AppearanceController.load(
          File('${directory.path}/appearance.json'),
        ),
      ))!;
      expect(restored.value.highlightArgb, 0xff81cbc4);
      restored.dispose();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(controller.flush);
      controller.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });
}
