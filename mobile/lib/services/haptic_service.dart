import 'package:flutter/services.dart';

/// Service for providing haptic feedback throughout the app.
/// Follows Apple HIG recommendations for haptic feedback usage.
class HapticService {
  /// Light feedback for minor UI interactions (taps, selections)
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// Medium feedback for state changes (toggles, confirmations)
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy feedback for significant actions (deletions, important confirmations)
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback for picking items (lists, carousels)
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  /// Success feedback for completed actions
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Warning feedback for caution actions
  static void warning() {
    HapticFeedback.heavyImpact();
  }

  /// Error feedback for failed actions
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
