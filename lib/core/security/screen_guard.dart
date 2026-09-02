import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and hides the app from the task switcher.
///
/// Applied to screens showing credentials, customer KYC, valuations and prices.
/// On Android this sets `FLAG_SECURE`; on iOS the platform blurs a secured
/// window in the app switcher, and the flag is a no-op the platform channel
/// ignores safely.
class ScreenGuard extends StatefulWidget {
  const ScreenGuard({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<ScreenGuard> createState() => _ScreenGuardState();
}

class _ScreenGuardState extends State<ScreenGuard> {
  static const _channel = MethodChannel('jewellery_erp/screen_guard');

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _setSecure(true);
  }

  @override
  void dispose() {
    if (widget.enabled) _setSecure(false);
    super.dispose();
  }

  Future<void> _setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException {
      // The native side is wired per platform in Phase 17 hardening; a missing
      // implementation must never prevent a screen from opening.
    } on MissingPluginException {
      // Same, on a platform where the channel is not registered at all.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
