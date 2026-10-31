import 'dart:async';

import 'package:audiosubs_reader/reader_display.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('audiosubs_reader/audio');
  const codec = StandardMethodCodec();

  Future<void> interrupt() async {
    final response = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      channel.name,
      codec.encodeMethodCall(const MethodCall('interruption', 'focus_loss')),
      (_) => response.complete(),
    );
    await response.future;
  }

  test('an old route cannot unsubscribe a newly opened reader', () async {
    var oldInterruptions = 0;
    var newInterruptions = 0;
    final stopOld = ReaderDisplay.listenForInterruption(
      () => oldInterruptions++,
    );
    final stopNew = ReaderDisplay.listenForInterruption(
      () => newInterruptions++,
    );
    addTearDown(stopOld);
    addTearDown(stopNew);
    stopOld();
    await interrupt();
    expect(oldInterruptions, 0);
    expect(newInterruptions, 1);
    stopNew();
    var thirdInterruptions = 0;
    final stopThird = ReaderDisplay.listenForInterruption(
      () => thirdInterruptions++,
    );
    addTearDown(stopThird);
    await interrupt();
    expect(newInterruptions, 1);
    expect(thirdInterruptions, 1);
  });
}
