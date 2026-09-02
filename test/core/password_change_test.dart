import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The forced password change is the first thing every new member of staff
/// does, and it was broken for all of them.
///
/// The change itself succeeded, but the app then carried on with the tokens it
/// had arrived with. The backend revokes every token on a credential change —
/// deliberately — so the next call came back 403 and the screen reported
/// "You do not have permission to perform this action" for a password that had
/// just been changed successfully.
///
/// The user would then retry with the old password, which no longer worked,
/// with nothing on screen to explain why.
///
/// This pins the ordering the fix depends on: re-authenticate with the *new*
/// password before doing anything else that needs a token.
void main() {
  test('a password change re-authenticates before using the session', () {
    final source = _controllerSource();

    final changeBody = source.substring(
      source.indexOf('Future<void> changePassword('),
      source.indexOf('Future<void> _establish('),
    );

    expect(
      changeBody.contains('signIn('),
      isTrue,
      reason:
          'the new password must buy fresh tokens before the session is used',
    );
    expect(
      changeBody.contains('_establish(user)'),
      isFalse,
      reason:
          'establishing directly reuses tokens the backend has just revoked',
    );
  });
}

String _controllerSource() {
  const path = 'lib/core/security/session_controller.dart';
  return File(path).readAsStringSync();
}
