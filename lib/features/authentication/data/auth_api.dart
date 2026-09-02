import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user.dart';

/// Raw HTTP for the authentication endpoints.
///
/// Deliberately given its own bare [Dio] with **no auth interceptor**. Login and
/// refresh must never carry a bearer token, and a refresh that went through the
/// interceptor chain would recurse into itself when the token it is trying to
/// replace is the one that just failed.
class AuthApi {
  AuthApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Builds the isolated client. Shares only the base URL and timeouts.
  static Dio createClient({
    required String baseUrl,
    required Duration connectTimeout,
    required Duration receiveTimeout,
    List<Interceptor> interceptors = const [],
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    dio.interceptors.addAll(interceptors);
    return dio;
  }

  Future<AuthPayload> login({
    required String username,
    required String password,
  }) async {
    return _call(
      () => _dio.post<dynamic>(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      ),
    );
  }

  Future<AuthPayload> refresh(String refreshToken) async {
    return _call(
      () => _dio.post<dynamic>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      ),
    );
  }

  /// Revokes the presented refresh token.
  ///
  /// Failures are the caller's to swallow: local credentials are cleared either
  /// way, because a user who taps "sign out" must end up signed out.
  Future<void> logout(String refreshToken) async {
    await _call<void>(
      () => _dio.post<dynamic>(
        ApiEndpoints.logout,
        data: {'refreshToken': refreshToken},
      ),
      parse: (_) {},
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String accessToken,
  }) async {
    await _call<void>(
      () => _dio.post<dynamic>(
        ApiEndpoints.changePassword,
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      ),
      parse: (_) {},
    );
  }

  /// Current profile, roles and permissions.
  Future<AppUser> me(String accessToken) async {
    return _call<AppUser>(
      () => _dio.get<dynamic>(
        ApiEndpoints.me,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      ),
      parse: (data) => AppUser.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(Object? data)? parse,
  }) async {
    try {
      final response = await request();
      final body = response.data;
      final data = body is Map<String, dynamic> && body.containsKey('success')
          ? body['data']
          : body;

      if (parse != null) return parse(data);
      return AuthPayload.fromJson(data! as Map<String, dynamic>) as T;
    } on DioException catch (error) {
      throw ErrorMapper.map(error);
    }
  }
}

/// The backend's `AuthResponse`, split into the parts the app stores separately.
class AuthPayload {
  const AuthPayload({
    required this.tokens,
    required this.user,
    required this.mustChangePassword,
  });

  final TokenBundle tokens;
  final AppUser user;
  final bool mustChangePassword;

  factory AuthPayload.fromJson(Map<String, dynamic> json) {
    return AuthPayload(
      tokens: TokenBundle(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
        // The backend tells us when the token dies, so the client can refresh
        // before a 401 rather than discovering it through a failure.
        expiresAt: DateTime.tryParse(
          json['accessTokenExpiresAt'] as String? ?? '',
        ),
      ),
      user: AppUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
    );
  }
}
