import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';
import 'app_inputs.dart';

/// Confirmation dialogs and bottom sheets.
///
/// Centralised so that a consequential confirmation always looks and behaves
/// the same — the approval and issue flows in later phases depend on the user
/// recognising "this one matters" instantly.

enum ConfirmTone { normal, danger }

/// Asks for confirmation. Returns true only on an explicit accept.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  ConfirmTone tone = ConfirmTone.normal,
  IconData? icon,

  /// Extra detail restated before a consequential action — amount, item,
  /// recipient. Phase 14 requires this for anything carrying a value.
  Widget? detail,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: tone != ConfirmTone.danger,
    builder: (context) {
      final danger = tone == ConfirmTone.danger;
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                color: danger ? context.colors.danger : context.scheme.primary,
              ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: context.text.bodyMedium),
            if (detail != null) ...[AppSpacing.gapLg, detail],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel ?? context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: context.colors.danger,
                    foregroundColor: context.colors.onDanger,
                  )
                : null,
            child: Text(confirmLabel ?? context.l10n.actionConfirm),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

/// Collects a mandatory reason — rejections and status corrections require one,
/// and the backend enforces it, so the UI should not allow an empty submission.
Future<String?> showReasonSheet(
  BuildContext context, {
  required String title,
  String? hint,
  int minLength = 3,
}) {
  final controller = TextEditingController();

  return showAppBottomSheet<String>(
    context,
    title: title,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final valid = controller.text.trim().length >= minLength;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: controller,
              hint: hint,
              maxLines: 4,
              autofocus: true,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
            ),
            AppSpacing.gapLg,
            AppButton(
              label: context.l10n.actionConfirm,
              onPressed: valid
                  ? () => Navigator.of(context).pop(controller.text.trim())
                  : null,
            ),
          ],
        );
      },
    ),
  );
}

/// The standard modal sheet: draggable, scroll-safe, keyboard-aware.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (context) => Padding(
      // Lifts the sheet above the keyboard so a field is never covered.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: context.text.headlineSmall),
              if (subtitle != null) ...[
                AppSpacing.gapXs,
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ],
              AppSpacing.gapXl,
              builder(context),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A snackbar that carries a tone, so a failure does not look like a success.
void showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackTone tone = SnackTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              switch (tone) {
                SnackTone.success => Icons.check_circle_outline,
                SnackTone.error => Icons.error_outline,
                SnackTone.neutral => Icons.info_outline,
              },
              size: 18,
              color: switch (tone) {
                SnackTone.success => context.colors.success,
                SnackTone.error => context.colors.danger,
                SnackTone.neutral => context.scheme.onInverseSurface,
              },
            ),
            AppSpacing.wGapMd,
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}

enum SnackTone { success, error, neutral }
