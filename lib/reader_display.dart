import 'package:flutter/services.dart';

/// Controls the reader's native window without changing playback or appearance.
abstract final class ReaderDisplay {
  static const MethodChannel _channel = MethodChannel(
    'audiosubs_reader/display',
  );

  /// Completes once the platform has applied the requested presentation.
  /// Native failures are reported as [PlatformException]s.
  static Future<void> setFullscreen(bool enabled) =>
      _channel.invokeMethod<void>('setFullscreen', enabled);

  static const MethodChannel _audio = MethodChannel('audiosubs_reader/audio');
  static void Function()? _interruptionListener;

  /// The activity owns focus so transient interruptions never auto-resume.
  static void Function() listenForInterruption(void Function() listener) {
    _interruptionListener = listener;
    _audio.setMethodCallHandler((call) async {
      if (call.method == 'interruption') _interruptionListener?.call();
    });
    return () {
      // A fading-out route must not remove a newly opened reader's listener.
      if (identical(_interruptionListener, listener)) {
        _interruptionListener = null;
        _audio.setMethodCallHandler(null);
      }
    };
  }

  static Future<bool> requestAudioFocus() async =>
      await _audio.invokeMethod<bool>('requestFocus') ?? false;

  static Future<void> abandonAudioFocus() =>
      _audio.invokeMethod<void>('abandonFocus');
}
