import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/authentication/data/auth_api.dart';
import '../providers.dart';

/// Where the running build stands against the backend's published versions.
enum UpdateStatus {
  /// The check could not run — offline, endpoint missing, malformed payload.
  ///
  /// The app must never be blocked by a failing version check, so this is the
  /// default and the gate treats it exactly like [upToDate].
  unknown,
  upToDate,

  /// A newer build exists but the current one is still supported.
  updateAvailable,

  /// The current build is below `minSupported`; the app is blocked.
  forced,
}

/// The backend's `GET /app/version` payload, plus the verdict for this build.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.status,
    this.currentVersion,
    this.minSupported,
    this.latest,
    this.storeUrl,
    this.message,
  });

  static const unknown = AppUpdateInfo(status: UpdateStatus.unknown);

  final UpdateStatus status;
  final String? currentVersion;
  final String? minSupported;
  final String? latest;
  final String? storeUrl;

  /// Backend-authored copy for the gate, when it has something specific to
  /// say ("this release fixes a pricing bug"). Null means use the default.
  final String? message;

  bool get isForced => status == UpdateStatus.forced;
  bool get hasUpdate =>
      status == UpdateStatus.updateAvailable || status == UpdateStatus.forced;

  /// Decides the verdict from a payload and the running version.
  ///
  /// The backend's `forceUpdate` flag wins when present; the semver comparison
  /// is the fallback so the gate still works if the flag is ever omitted.
  factory AppUpdateInfo.evaluate({
    required Map<String, dynamic> json,
    required String currentVersion,
  }) {
    final minSupported = json['minSupported'] as String?;
    final latest = json['latest'] as String?;
    final forceFlag = json['forceUpdate'] as bool?;

    final forced =
        forceFlag ??
        (minSupported != null &&
            compareSemver(currentVersion, minSupported) < 0);
    final behindLatest =
        latest != null && compareSemver(currentVersion, latest) < 0;

    return AppUpdateInfo(
      status: forced
          ? UpdateStatus.forced
          : behindLatest
          ? UpdateStatus.updateAvailable
          : UpdateStatus.upToDate,
      currentVersion: currentVersion,
      minSupported: minSupported,
      latest: latest,
      storeUrl: json['storeUrl'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// Compares two semantic versions numerically, ignoring build metadata.
///
/// Returns a negative number when [a] < [b], zero when equal, positive when
/// [a] > [b]. Tolerates `+build` suffixes (`1.2.0+45` is `1.2.0`),
/// pre-release suffixes (`1.2.0-rc.1` sorts below `1.2.0`, per semver), a
/// leading `v`, and versions with fewer than three segments (`1.2` is `1.2.0`).
int compareSemver(String a, String b) {
  final left = _SemVer.parse(a);
  final right = _SemVer.parse(b);

  for (var i = 0; i < 3; i++) {
    final diff = left.numbers[i].compareTo(right.numbers[i]);
    if (diff != 0) return diff;
  }

  // Equal core versions: a pre-release is lower than a release.
  if (left.preRelease == null && right.preRelease == null) return 0;
  if (left.preRelease == null) return 1;
  if (right.preRelease == null) return -1;
  return _comparePreRelease(left.preRelease!, right.preRelease!);
}

int _comparePreRelease(String a, String b) {
  final left = a.split('.');
  final right = b.split('.');
  final length = left.length < right.length ? left.length : right.length;

  for (var i = 0; i < length; i++) {
    final l = int.tryParse(left[i]);
    final r = int.tryParse(right[i]);
    final diff = l != null && r != null
        ? l.compareTo(r)
        : l != null
        ? -1 // Numeric identifiers sort below alphanumeric ones.
        : r != null
        ? 1
        : left[i].compareTo(right[i]);
    if (diff != 0) return diff;
  }
  return left.length.compareTo(right.length);
}

class _SemVer {
  const _SemVer(this.numbers, this.preRelease);

  final List<int> numbers;
  final String? preRelease;

  static _SemVer parse(String raw) {
    var value = raw.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }

    // Build metadata never participates in precedence.
    final plus = value.indexOf('+');
    if (plus >= 0) value = value.substring(0, plus);

    String? preRelease;
    final dash = value.indexOf('-');
    if (dash >= 0) {
      preRelease = value.substring(dash + 1);
      value = value.substring(0, dash);
    }

    final parts = value.split('.');
    final numbers = List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      return int.tryParse(parts[i].trim()) ?? 0;
    });

    return _SemVer(numbers, preRelease?.isEmpty ?? true ? null : preRelease);
  }
}

/// Talks to the public version endpoint.
///
/// Takes a bare [Dio] rather than the authenticated client on purpose: the
/// endpoint is public, and the gate has to work before sign-in — a user whose
/// build is too old to log in still needs to be told to update.
class AppVersionService {
  AppVersionService({required Dio dio, required this.platform}) : _dio = dio;

  final Dio _dio;

  /// `ANDROID` or `IOS`, as the backend spells them.
  final String platform;

  static const path = '/app/version';

  /// Never throws. Any failure yields [AppUpdateInfo.unknown].
  Future<AppUpdateInfo> check(String currentVersion) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: {'platform': platform, 'current': currentVersion},
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );

      final body = response.data;
      final data = body is Map<String, dynamic> && body.containsKey('success')
          ? body['data']
          : body;
      if (data is! Map<String, dynamic>) return AppUpdateInfo.unknown;

      return AppUpdateInfo.evaluate(json: data, currentVersion: currentVersion);
    } on Object catch (error) {
      debugPrint('Version check skipped: $error');
      return AppUpdateInfo.unknown;
    }
  }

  static String platformName() {
    if (kIsWeb) return 'WEB';
    return Platform.isIOS ? 'IOS' : 'ANDROID';
  }
}

/// The running build's version and build number, read once.
final installedVersionProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final appVersionServiceProvider = Provider<AppVersionService>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppVersionService(
    dio: AuthApi.createClient(
      baseUrl: config.apiRoot,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
    ),
    platform: AppVersionService.platformName(),
  );
});

/// The update verdict for this build. Never errors: a failed check resolves to
/// [AppUpdateInfo.unknown], and the gate lets the app through.
///
/// Invalidate to re-check (the "Check for updates" row does this).
final appUpdateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  try {
    final info = await ref.watch(installedVersionProvider.future);
    return ref.watch(appVersionServiceProvider).check(info.version);
  } on Object {
    return AppUpdateInfo.unknown;
  }
});

/// Whether the "update available" nudge has been shown this session.
///
/// The soft prompt appears once per launch, not once per screen — anything
/// more is nagging, and a person on a counter cannot update mid-sale anyway.
final updateNudgeShownProvider = NotifierProvider<UpdateNudgeShown, bool>(
  UpdateNudgeShown.new,
);

class UpdateNudgeShown extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}
