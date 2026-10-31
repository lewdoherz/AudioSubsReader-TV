import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws a stable, high-contrast outline without adding a traversal stop.
/// Also reveals controls inside scrollable dialogs as focus moves with a remote.
class TvFocusFrame extends StatefulWidget {
  const TvFocusFrame({super.key, required this.child});

  final Widget child;

  @override
  State<TvFocusFrame> createState() => _TvFocusFrameState();
}

class _TvFocusFrameState extends State<TvFocusFrame> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      setState(() => _focused = focused);
      if (focused) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
    },
    child: Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          width: 3,
          color: _focused
              ? Theme.of(context).colorScheme.onSurface
              : Colors.transparent,
        ),
      ),
      child: widget.child,
    ),
  );
}

/// Stock Slider consumes all four arrows. A TV needs Up/Down for traversal.
class TvRemoteSlider extends StatelessWidget {
  const TvRemoteSlider({
    super.key,
    required this.slider,
    required this.step,
    this.focusNode,
  });

  final Slider slider;
  final double step;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    debugLabel: 'Remote slider',
    canRequestFocus: slider.onChanged != null,
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      if (key != LogicalKeyboardKey.arrowLeft &&
          key != LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.ignored;
      }
      if (slider.onChanged == null) return KeyEventResult.ignored;
      final next =
          (slider.value + (key == LogicalKeyboardKey.arrowRight ? step : -step))
              .clamp(slider.min, slider.max)
              .toDouble();
      if (next != slider.value) {
        slider.onChangeStart?.call(slider.value);
        slider.onChanged!(next);
        slider.onChangeEnd?.call(next);
      }
      return KeyEventResult.handled;
    },
    child: ExcludeFocus(child: slider),
  );
}
