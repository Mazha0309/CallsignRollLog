import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Scale the layout as well as its paint and hit-test coordinates. Keeping
/// this subtree in place at 100% preserves editors, focus and open routes.
class AppScale extends StatelessWidget {
  const AppScale({super.key, required this.scale, required this.child});
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final factor = scale.isFinite && scale > 0 ? scale : 1.0;
    final media = MediaQuery.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest / factor;
      return ClipRect(
          child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: Transform.scale(
          scale: factor,
          alignment: Alignment.topLeft,
          child: MediaQuery(
            data: media.copyWith(
              size: size,
              devicePixelRatio: media.devicePixelRatio * factor,
              padding: media.padding / factor,
              viewPadding: media.viewPadding / factor,
              viewInsets: media.viewInsets / factor,
              systemGestureInsets: media.systemGestureInsets / factor,
              displayFeatures: [
                for (final feature in media.displayFeatures)
                  ui.DisplayFeature(
                    bounds: Rect.fromLTWH(
                        feature.bounds.left / factor,
                        feature.bounds.top / factor,
                        feature.bounds.width / factor,
                        feature.bounds.height / factor),
                    type: feature.type,
                    state: feature.state,
                  ),
              ],
            ),
            child: child,
          ),
        ),
      ));
    });
  }
}
