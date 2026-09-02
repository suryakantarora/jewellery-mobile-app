import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/security/session_state.dart';

/// A deliberate sign-out must never be reported as an expiry.
///
/// The sign-out request is sent with the very token that may already have
/// expired, so its 401 came back through `onAuthenticationLost` and relabelled
/// the reason. Anyone who left the app overnight and then tapped Sign out was
/// told "your session expired" — reporting a fault where the user had simply
/// made a choice.
void main() {
  group('Sign-out reason', () {
    test('the login screen only announces an expiry for a real one', () {
      // The login screen keys its notice off this exact condition.
      bool announcesExpiry(SessionState state) =>
          state is SessionUnauthenticated &&
          state.reason == SignOutReason.sessionExpired;

      expect(
        announcesExpiry(
          const SessionState.unauthenticated(
            reason: SignOutReason.userInitiated,
          ),
        ),
        isFalse,
        reason: 'the user chose to leave; nothing failed',
      );
      expect(
        announcesExpiry(
          const SessionState.unauthenticated(
            reason: SignOutReason.sessionExpired,
          ),
        ),
        isTrue,
      );
      expect(
        announcesExpiry(const SessionState.unauthenticated()),
        isFalse,
        reason: 'a first launch has no expiry to report',
      );
    });
  });
}
