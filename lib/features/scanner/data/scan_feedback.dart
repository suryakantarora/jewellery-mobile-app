import 'package:flutter/services.dart';

import '../domain/scan_session.dart';

/// Haptic and audio feedback for scanning.
///
/// Distinct patterns per outcome are the actual speed win: staff learn the
/// feel and stop looking at the screen, which is what makes a 250-item vault
/// count take thirty minutes instead of an hour.
class ScanFeedback {
  const ScanFeedback();

  Future<void> forOutcome(ScanOutcome outcome) async {
    switch (outcome) {
      case ScanOutcome.matched:
      case ScanOutcome.accepted:
        // A short, light tick — the sound of progress.
        await HapticFeedback.lightImpact();
        await SystemSound.play(SystemSoundType.click);
      case ScanOutcome.unexpected:
        // Heavier and doubled: something is here that should not be.
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.heavyImpact();
      case ScanOutcome.duplicate:
        // Softer: not an error, just already counted.
        await HapticFeedback.selectionClick();
      case ScanOutcome.repeat:
        // The decoder re-read a tag still in frame. Silence is correct —
        // buzzing here would train staff to ignore the feedback entirely.
        break;
    }
  }

  Future<void> notFound() async {
    await HapticFeedback.vibrate();
  }

  Future<void> success() async {
    await HapticFeedback.mediumImpact();
  }
}
