import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Dismiss an input only after a real outside tap, not when a scroll starts.
///
/// TextField.onTapOutside runs on pointer *down*, before Flutter knows whether
/// a touch will turn into a drag. Keep focus until pointer up and cancel the
/// dismissal as soon as movement exceeds the gesture slop. This also handles a
/// drag that returns to its starting position and taps on other controls.
/// Owners must call [dispose] when their field/form is disposed.
class ScrollSafeUnfocus {
  int? _pointer;
  Offset? _origin;
  FocusNode? _focusNode;
  double _slop = kTouchSlop;

  void onTapOutside(PointerDownEvent event, FocusNode? focusNode) {
    _cancel();
    if (focusNode == null || !focusNode.hasFocus) return;
    _pointer = event.pointer;
    _origin = event.position;
    _focusNode = focusNode;
    _slop = computeHitSlop(event.kind, null);
    GestureBinding.instance.pointerRouter.addRoute(event.pointer, _handleEvent);
  }

  void _handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent &&
        (event.position - _origin!).distance > _slop) {
      _cancel();
    } else if (event is PointerCancelEvent) {
      _cancel();
    } else if (event is PointerUpEvent) {
      final focusNode = _focusNode;
      final moved = (event.position - _origin!).distance > _slop;
      _cancel();
      if (!moved && focusNode?.hasFocus == true) focusNode!.unfocus();
    }
  }

  void _cancel() {
    final pointer = _pointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleEvent);
    }
    _pointer = null;
    _origin = null;
    _focusNode = null;
  }

  void dispose() => _cancel();
}
