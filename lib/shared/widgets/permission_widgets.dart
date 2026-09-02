import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/permissions.dart';
import '../../core/security/session_controller.dart';
import '../extensions/context_extensions.dart';

/// Renders [child] only when the permission is held.
///
/// Used for navigation, quick actions and whole screens — places where showing
/// a disabled control would advertise capabilities the user cannot have and
/// clutter the interface.
class PermissionGuard extends ConsumerWidget {
  const PermissionGuard({
    super.key,
    required this.child,
    this.requires,
    this.requiresAny,
    this.requiresAll,
    this.fallback,
  });

  final Widget child;
  final Permission? requires;
  final List<Permission>? requiresAny;
  final List<Permission>? requiresAll;

  /// Shown instead of [child]; defaults to nothing at all.
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    return _allows(permissions) ? child : (fallback ?? const SizedBox.shrink());
  }

  bool _allows(PermissionSet permissions) {
    if (requires != null && !permissions.has(requires!)) return false;
    if (requiresAny != null && !permissions.hasAny(requiresAny!)) return false;
    if (requiresAll != null && !permissions.hasAll(requiresAll!)) return false;
    return true;
  }
}

/// Shows [child] but disables it, with a tooltip explaining why.
///
/// The right choice inside a detail screen: hiding an action there makes the
/// screen look broken or incomplete, whereas a visibly disabled control tells
/// staff what exists and what they would need rights for.
class PermissionDisabled extends ConsumerWidget {
  const PermissionDisabled({
    super.key,
    required this.child,
    required this.requires,
    this.message,
  });

  final Widget child;
  final Permission requires;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(permissionsProvider).has(requires);
    if (allowed) return child;

    return Tooltip(
      message: message ?? context.l10n.stateNoPermission,
      child: Opacity(opacity: 0.4, child: IgnorePointer(child: child)),
    );
  }
}

/// Builder form, for deciding between two renderings rather than showing or
/// hiding one.
class PermissionBuilder extends ConsumerWidget {
  const PermissionBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, PermissionSet permissions)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      builder(context, ref.watch(permissionsProvider));
}
