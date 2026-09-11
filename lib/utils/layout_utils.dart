import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Default breakpoints for tablet layout detection.
const double kDefaultTabletBreakpoint = 900.0;
const double kDefaultLandscapeBreakpoint = 600.0;

/// Returns `true` if the current screen should be treated as a tablet layout.
///
/// Tablet is detected when:
/// - Width >= [kDefaultTabletBreakpoint] (portrait or landscape), OR
/// - Device is in landscape AND width >= [kDefaultLandscapeBreakpoint].
bool isTabletLayout(BuildContext context) {
  final media = MediaQuery.of(context);
  final w = media.size.width;
  final isLandscape =
      media.orientation == Orientation.landscape || w > media.size.height;
  return w >= kDefaultTabletBreakpoint ||
      (isLandscape && w >= kDefaultLandscapeBreakpoint);
}

/// Whether the app runs on a desktop OS (Windows / macOS / Linux).
///
/// Web-safe: implemented via [defaultTargetPlatform] instead of `dart:io`
/// [Platform], so UI files importing this (mobile included) still compile
/// for Web. Returns `false` on Web and on Android/iOS/Fuchsia.
bool get isDesktop {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.macOS:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}
