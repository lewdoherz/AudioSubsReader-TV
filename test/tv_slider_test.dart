import 'package:audiosubs_reader/tv_focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Up and Down leave a slider; only Left and Right adjust it', (
    tester,
  ) async {
    final above = FocusNode();
    final slider = FocusNode();
    final below = FocusNode();
    addTearDown(above.dispose);
    addTearDown(slider.dispose);
    addTearDown(below.dispose);
    var value = 95.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                TextButton(
                  focusNode: above,
                  onPressed: () {},
                  child: const Text('Above'),
                ),
                TvRemoteSlider(
                  focusNode: slider,
                  step: 5,
                  slider: Slider(
                    value: value,
                    max: 100,
                    onChanged: (next) => setState(() => value = next),
                  ),
                ),
                TextButton(
                  focusNode: below,
                  onPressed: () {},
                  child: const Text('Below'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    slider.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, 100);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, 100);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(above.hasFocus, isTrue);
    expect(value, 100);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(slider.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(value, 95);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(below.hasFocus, isTrue);
    expect(value, 95);
    await tester.pumpWidget(const SizedBox());
  });
}
