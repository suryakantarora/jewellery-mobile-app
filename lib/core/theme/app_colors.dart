import 'package:flutter/material.dart';

/// Semantic colours that carry business meaning and therefore must not be
/// derived from the accent palette — a "rejected" chip has to read the same
/// whichever brand colour the tenant picked.
///
/// Attached to [ThemeData] as an extension so widgets reach them through
/// `context.colors` and never hardcode a hex value at a call site.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.neutral,
    required this.onNeutral,
    required this.neutralContainer,
    required this.vault,
    required this.onVault,
    required this.vaultContainer,
    required this.gold,
    required this.silver,
    required this.platinumMetal,
    required this.diamond,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.backdropTint,
  });

  /// In stock, approved, matched, passed.
  final Color success;
  final Color onSuccess;
  final Color successContainer;

  /// Pending, in transit, awaiting approval.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  /// Rejected, missing, failed, blacklisted.
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;

  /// Draft, informational, unread.
  final Color info;
  final Color onInfo;
  final Color infoContainer;

  /// Cancelled, inactive, closed.
  final Color neutral;
  final Color onNeutral;
  final Color neutralContainer;

  /// Secured and high-value operations — vault, dual authorisation.
  final Color vault;
  final Color onVault;
  final Color vaultContainer;

  /// Metal indicators used on purity and material chips.
  final Color gold;
  final Color silver;
  final Color platinumMetal;
  final Color diamond;

  /// Skeleton loader gradient stops.
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Very low-opacity wash used by decorative backgrounds.
  final Color backdropTint;

  static const light = AppColors(
    success: Color(0xFF1B7A4B),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD8F0E2),
    warning: Color(0xFF8A5800),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFBEBD0),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFF9DEDC),
    info: Color(0xFF2C5F8A),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDCEAF6),
    neutral: Color(0xFF5C6670),
    onNeutral: Color(0xFFFFFFFF),
    neutralContainer: Color(0xFFE7EAED),
    vault: Color(0xFF6A4BA8),
    onVault: Color(0xFFFFFFFF),
    vaultContainer: Color(0xFFE9E0F8),
    gold: Color(0xFFC9A227),
    silver: Color(0xFF9AA5B1),
    platinumMetal: Color(0xFF7E8B99),
    diamond: Color(0xFF6FA8C7),
    shimmerBase: Color(0xFFE9ECEF),
    shimmerHighlight: Color(0xFFF7F9FA),
    backdropTint: Color(0x0D000000),
  );

  static const dark = AppColors(
    success: Color(0xFF62D89C),
    onSuccess: Color(0xFF00391F),
    successContainer: Color(0xFF17402C),
    warning: Color(0xFFF0BC5E),
    onWarning: Color(0xFF3D2A00),
    warningContainer: Color(0xFF4A3612),
    danger: Color(0xFFF2B8B5),
    onDanger: Color(0xFF601410),
    dangerContainer: Color(0xFF562220),
    info: Color(0xFF8FC2E8),
    onInfo: Color(0xFF06304F),
    infoContainer: Color(0xFF1D394F),
    neutral: Color(0xFFA9B3BD),
    onNeutral: Color(0xFF262C32),
    neutralContainer: Color(0xFF333A41),
    vault: Color(0xFFC7B2F0),
    onVault: Color(0xFF351B63),
    vaultContainer: Color(0xFF3F2E63),
    gold: Color(0xFFD9B44A),
    silver: Color(0xFFB4BEC8),
    platinumMetal: Color(0xFF9AA7B4),
    diamond: Color(0xFF8FC4DD),
    shimmerBase: Color(0xFF23282D),
    shimmerHighlight: Color(0xFF2E353B),
    backdropTint: Color(0x14FFFFFF),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? neutral,
    Color? onNeutral,
    Color? neutralContainer,
    Color? vault,
    Color? onVault,
    Color? vaultContainer,
    Color? gold,
    Color? silver,
    Color? platinumMetal,
    Color? diamond,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? backdropTint,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      vault: vault ?? this.vault,
      onVault: onVault ?? this.onVault,
      vaultContainer: vaultContainer ?? this.vaultContainer,
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      platinumMetal: platinumMetal ?? this.platinumMetal,
      diamond: diamond ?? this.diamond,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      backdropTint: backdropTint ?? this.backdropTint,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onNeutral: Color.lerp(onNeutral, other.onNeutral, t)!,
      neutralContainer: Color.lerp(
        neutralContainer,
        other.neutralContainer,
        t,
      )!,
      vault: Color.lerp(vault, other.vault, t)!,
      onVault: Color.lerp(onVault, other.onVault, t)!,
      vaultContainer: Color.lerp(vaultContainer, other.vaultContainer, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      platinumMetal: Color.lerp(platinumMetal, other.platinumMetal, t)!,
      diamond: Color.lerp(diamond, other.diamond, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      backdropTint: Color.lerp(backdropTint, other.backdropTint, t)!,
    );
  }
}
