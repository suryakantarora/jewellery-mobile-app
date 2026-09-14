import '../../../core/connectivity/offline_guard.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/customer_models.dart';

class CustomerRepository {
  CustomerRepository(this._client, {OfflineGuard? offlineGuard})
    : _offlineGuard = offlineGuard;

  final ApiClient _client;

  /// Refuses mutations while offline. Null in tests that construct the
  /// repository directly; the provider always supplies one.
  final OfflineGuard? _offlineGuard;

  Future<T> _guarded<T>(Future<T> Function() action) =>
      _offlineGuard?.run(action) ?? action();

  static String _wishlist(String customerId) =>
      '${ApiEndpoints.customer(customerId)}/wishlist';

  Future<PageResponse<Customer>> search({
    String? query,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<Customer>(
      ApiEndpoints.customers,
      query: {
        'page': page,
        'size': size,
        if (query != null && query.trim().isNotEmpty) 'search': query.trim(),
      },
      parseItem: Customer.fromJson,
    );
  }

  /// The fast path: a returning customer is identified by their phone number.
  Future<Customer?> byPhone(String phone) async {
    try {
      return await _client.get<Customer?>(
        ApiEndpoints.customerByPhone,
        query: {'phone': phone},
        parse: (data) =>
            data is Map<String, dynamic> ? Customer.fromJson(data) : null,
      );
    } on Object {
      return null;
    }
  }

  Future<Customer> byId(String id) => _client.get<Customer>(
    ApiEndpoints.customer(id),
    parse: (data) => Customer.fromJson(data! as Map<String, dynamic>),
  );

  Future<Customer360> profile360(String id) => _client.get<Customer360>(
    ApiEndpoints.customer360(id),
    parse: (data) => Customer360.fromJson(data! as Map<String, dynamic>),
  );

  Future<Customer> create({
    required String fullName,
    required String phone,
    String? email,
    String? customerType,
    String? registeredBranchId,
    String? notes,
  }) {
    return _guarded(
      () => _client.post<Customer>(
        ApiEndpoints.customers,
        body: {
          'fullName': fullName,
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          if (customerType != null) 'customerType': customerType,
          if (registeredBranchId != null)
            'registeredBranchId': registeredBranchId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        parse: (data) => Customer.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  Future<void> logActivity({
    required String customerId,
    required String activityType,
    String? subject,
    String? notes,
  }) {
    return _guarded(
      () => _client.send(
        ApiEndpoints.activities,
        body: {
          'customerId': customerId,
          'activityType': activityType,
          if (subject != null) 'subject': subject,
          if (notes != null) 'notes': notes,
        },
      ),
    );
  }

  /// Follow-ups assigned to the signed-in user — the dashboard's task list.
  Future<List<FollowUp>> myFollowUps() => _client.get<List<FollowUp>>(
    ApiEndpoints.myFollowUps,
    parse: (data) => data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(FollowUp.fromJson)
              .toList(growable: false)
        : const [],
  );

  // --- Wishlist ------------------------------------------------------------

  Future<List<WishlistEntry>> wishlist(String customerId) =>
      _client.get<List<WishlistEntry>>(
        _wishlist(customerId),
        parse: (data) => data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(WishlistEntry.fromJson)
                  .toList(growable: false)
            : const [],
      );

  /// Adds a piece, product or design. Exactly one id is expected; the backend
  /// returns the existing entry rather than a duplicate if it is already listed.
  Future<WishlistEntry> addToWishlist(
    String customerId, {
    String? jewelleryItemId,
    String? productId,
    String? designId,
    String? note,
    String? branchId,
  }) {
    return _guarded(
      () => _client.post<WishlistEntry>(
        _wishlist(customerId),
        body: {
          if (jewelleryItemId != null) 'jewelleryItemId': jewelleryItemId,
          if (productId != null) 'productId': productId,
          if (designId != null) 'designId': designId,
          if (note != null && note.isNotEmpty) 'note': note,
          if (branchId != null) 'branchId': branchId,
        },
        parse: (data) => WishlistEntry.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  Future<void> removeFromWishlist(String customerId, String entryId) =>
      _guarded(
        () =>
            _client.send('${_wishlist(customerId)}/$entryId', method: 'DELETE'),
      );
}
