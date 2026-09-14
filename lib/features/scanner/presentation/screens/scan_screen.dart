import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../jewellery/domain/bulk_tag_resolution.dart';
import '../../../jewellery/presentation/providers/jewellery_providers.dart';
import '../../domain/scan_session.dart';
import '../providers/scanner_providers.dart';

/// The scanning screen.
///
/// Speed is the whole design. A successful single scan resolves and navigates
/// straight to the passport with no confirmation step — a staff member scanning
/// forty items must not tap "OK" forty times.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.request = const ScanRequest()});

  final ScanRequest request;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late final ScanSession _session = ScanSession(
    expected: widget.request.expected,
  );

  StreamSubscription? _subscription;
  bool _bulkMode = false;
  bool _resolving = false;
  String? _lastMessage;
  bool _lastWasError = false;

  @override
  void initState() {
    super.initState();
    _bulkMode = widget.request.intent == ScanIntent.bulk;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final scanner = ref.read(cameraScannerProvider);
    _subscription = scanner.scans.listen(_onScan);
    try {
      await scanner.start();
    } on Object {
      // Permission denial and missing hardware are both surfaced by the
      // MobileScanner widget's own error builder, so nothing to do here.
    }
  }

  Future<void> _onScan(dynamic result) async {
    final tag = result.rawValue as String;
    final feedback = ref.read(scanFeedbackProvider);

    final outcome = _session.record(tag);
    // A decoder re-reading a tag still in frame must stay silent, or staff
    // learn to ignore the feedback entirely.
    if (outcome == ScanOutcome.repeat) return;

    await feedback.forOutcome(outcome);

    if (_bulkMode) {
      setState(() {
        _lastMessage = switch (outcome) {
          ScanOutcome.duplicate => '$tag already scanned',
          ScanOutcome.unexpected => '$tag was not expected',
          _ => tag,
        };
        _lastWasError = outcome == ScanOutcome.unexpected;
      });
      return;
    }

    await _resolveAndOpen(tag);
  }

  /// Single-scan path: resolve the tag and go straight to the passport.
  Future<void> _resolveAndOpen(String tag) async {
    if (_resolving) return;
    setState(() => _resolving = true);

    try {
      final item = await ref.read(jewelleryRepositoryProvider).byTag(tag);
      if (!mounted) return;

      ref.read(recentItemsProvider.notifier).record(item);
      await ref.read(scanFeedbackProvider).success();
      if (!mounted) return;

      await ref.read(cameraScannerProvider).stop();
      if (!mounted) return;
      context.pushReplacement(AppRoutes.itemDetailPath(item.id));
    } on NotFoundException {
      // An unknown tag in a warehouse is a finding, not an error — so the
      // camera stays live and the value is shown for the next decision.
      await ref.read(scanFeedbackProvider).notFound();
      if (mounted) {
        setState(() {
          _lastMessage = 'No item matches $tag';
          _lastWasError = true;
        });
      }
      _session.remove(tag);
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _lastMessage = error.message;
          _lastWasError = true;
        });
      }
      _session.remove(tag);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final tag = await showAppBottomSheet<String>(
      context,
      title: 'Enter code',
      subtitle: 'For a damaged or unreadable tag.',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: controller,
            label: 'Item code, barcode or RFID',
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          AppSpacing.gapLg,
          AppButton(
            label: context.l10n.actionConfirm,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          ),
        ],
      ),
    );

    if (tag == null || tag.isEmpty || !mounted) return;

    final outcome = _session.record(tag);
    if (_bulkMode) {
      setState(() => _lastMessage = tag);
      return;
    }
    if (outcome != ScanOutcome.repeat) await _resolveAndOpen(tag);
  }

  /// Bulk path: resolve everything scanned to items, show what did and did
  /// not match, then hand both back to the caller as a [BulkScanResult].
  Future<void> _finishBulk() async {
    if (_resolving) return;
    final tags = _session.scanned.toList(growable: false);
    final navigator = Navigator.of(context);

    if (tags.isEmpty) {
      navigator.pop(
        const BulkScanResult(tags: [], resolution: BulkTagResolution.empty),
      );
      return;
    }

    setState(() => _resolving = true);
    final BulkTagResolution resolution;
    try {
      resolution = await ref.read(jewelleryRepositoryProvider).byTags(tags);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _resolving = false);
      // The scans themselves are not lost with the lookup. The operator
      // decides whether raw codes are good enough for the flow they are in.
      final keep = await showConfirmationDialog(
        context,
        title: 'Could not look up items',
        message:
            '${error.message}\n\nKeep the ${tags.length} scanned codes '
            'without item details?',
        tone: ConfirmTone.danger,
        icon: Icons.cloud_off_outlined,
        confirmLabel: 'Keep scans',
      );
      if (!mounted) return;
      if (keep) navigator.pop(BulkScanResult(tags: tags));
      return;
    }
    if (!mounted) return;
    setState(() => _resolving = false);

    await showAppBottomSheet<void>(
      context,
      title: 'Scan results',
      builder: (context) => _ResolutionSummary(resolution: resolution),
    );
    if (!mounted) return;
    navigator.pop(BulkScanResult(tags: tags, resolution: resolution));
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(cameraScannerProvider);
    final rfidAvailable = ref.watch(rfidAvailableProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scanner.controller,
            errorBuilder: (context, error, _) => _CameraError(error: error),
            fit: BoxFit.cover,
          ),
          _ScanOverlay(resolving: _resolving),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: widget.request.title,
                  rfidAvailable: rfidAvailable,
                  onToggleTorch: scanner.toggleTorch,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (_lastMessage != null)
                  _ScanMessage(message: _lastMessage!, isError: _lastWasError),
                if (_bulkMode) _BulkBar(session: _session),
                _BottomBar(
                  bulkMode: _bulkMode,
                  allowModeSwitch: widget.request.intent == ScanIntent.lookup,
                  onModeChanged: (bulk) => setState(() => _bulkMode = bulk),
                  onManual: _enterManually,
                  onDone: _bulkMode ? _finishBulk : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the server made of a bulk scan, before the caller sees it.
///
/// Unresolved tags are listed with copy affordances because the usual next
/// step is pasting them into a message to whoever tagged the stock.
class _ResolutionSummary extends StatelessWidget {
  const _ResolutionSummary({required this.resolution});

  final BulkTagResolution resolution;

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showAppSnackBar(context, message: 'Copied', tone: SnackTone.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unresolved = resolution.unresolved;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _Counter(
              label: 'Resolved',
              value: resolution.resolvedCount,
              tone: context.colors.success,
            ),
            _Counter(
              label: 'Unresolved',
              value: resolution.unresolvedCount,
              tone: unresolved.isEmpty
                  ? context.scheme.onSurfaceVariant
                  : context.colors.warning,
            ),
          ],
        ),
        if (unresolved.isNotEmpty) ...[
          AppSpacing.gapLg,
          Row(
            children: [
              Expanded(
                child: Text(
                  'No item matches these codes',
                  style: context.text.labelMedium?.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                label: const Text('Copy all'),
                onPressed: () => _copy(context, unresolved.join('\n')),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: unresolved.length,
              itemBuilder: (context, index) {
                final tag = unresolved[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: context.colors.warning,
                  ),
                  title: Text(tag, style: AppTypography.mono(context)),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: 'Copy',
                    onPressed: () => _copy(context, tag),
                  ),
                );
              },
            ),
          ),
        ],
        AppSpacing.gapLg,
        AppButton(
          label: context.l10n.actionContinue,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.resolving});

  final bool resolving;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            children: [
              // Dimmed surround focuses the eye on the reticle without hiding
              // enough of the frame to make aiming harder.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: resolving
                          ? context.colors.success
                          : Colors.white.withValues(alpha: 0.85),
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
              if (resolving)
                const Center(
                  child: SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.rfidAvailable,
    required this.onToggleTorch,
    required this.onClose,
  });

  final String? title;
  final bool rfidAvailable;
  final VoidCallback onToggleTorch;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
            tooltip: context.l10n.actionClose,
          ),
          Expanded(
            child: Text(
              title ?? context.l10n.actionScan,
              style: context.text.titleMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          if (rfidAvailable)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: StatusBadge(
                label: 'RFID',
                tone: StatusTone.success,
                dense: true,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.flashlight_on_outlined, color: Colors.white),
            onPressed: onToggleTorch,
            tooltip: 'Torch',
          ),
        ],
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({required this.session});

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    final hasExpected = session.expected.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Counter(label: 'Scanned', value: session.scannedCount),
          if (hasExpected) ...[
            _Counter(
              label: 'Matched',
              value: session.matched.length,
              tone: context.colors.success,
            ),
            _Counter(
              label: 'Missing',
              value: session.missing.length,
              tone: context.colors.danger,
            ),
            _Counter(
              label: 'Unexpected',
              value: session.unexpected.length,
              tone: context.colors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, this.tone});

  final String label;
  final int value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: AppTypography.numeric(
            context,
            size: 20,
            color: tone ?? Colors.white,
          ),
        ),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _ScanMessage extends StatelessWidget {
  const _ScanMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: (isError ? context.colors.danger : context.colors.success)
            .withValues(alpha: 0.92),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: Colors.white,
          ),
          AppSpacing.wGapSm,
          Expanded(
            child: Text(
              message,
              style: context.text.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.bulkMode,
    required this.allowModeSwitch,
    required this.onModeChanged,
    required this.onManual,
    required this.onDone,
  });

  final bool bulkMode;
  final bool allowModeSwitch;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onManual;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            bulkMode
                ? 'Keep scanning — items are collected as you go'
                : 'Point at a barcode, QR code or tag',
            style: context.text.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapMd,
          Row(
            children: [
              if (allowModeSwitch)
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Single')),
                      ButtonSegment(value: true, label: Text('Bulk')),
                    ],
                    selected: {bulkMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => onModeChanged(s.first),
                  ),
                ),
              if (onDone != null)
                Expanded(
                  child: AppButton(label: 'Done', onPressed: onDone),
                ),
              AppSpacing.wGapMd,
              IconButton.filledTonal(
                icon: const Icon(Icons.keyboard),
                onPressed: onManual,
                tooltip: 'Enter manually',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Camera unavailable — permission denied, no hardware, or a runtime failure.
///
/// Always offers manual entry: a dead end here would block the fastest path in
/// the whole application.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
                size: 44,
                color: Colors.white70,
              ),
              AppSpacing.gapLg,
              Text(
                denied ? 'Camera access is off' : 'Camera unavailable',
                style: context.text.titleMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
              Text(
                denied
                    ? 'Allow camera access in Settings to scan tags. You can '
                          'still enter a code by hand.'
                    : 'This device could not start the camera. You can still '
                          'enter a code by hand.',
                style: context.text.bodySmall?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
