import '../../../core/connectivity/offline_guard.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/repair_models.dart';

class RepairRepository {
  RepairRepository(this._client, {OfflineGuard? offlineGuard})
    : _offlineGuard = offlineGuard;

  final ApiClient _client;

  /// Refuses mutations while offline. Null in tests that construct the
  /// repository directly; the provider always supplies one.
  final OfflineGuard? _offlineGuard;

  Future<T> _guarded<T>(Future<T> Function() action) =>
      _offlineGuard?.run(action) ?? action();

  Future<PageResponse<RepairJob>> search({
    RepairStatus? status,
    String? customerId,
    String? branchId,
    String? assignedTo,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<RepairJob>(
      ApiEndpoints.repairs,
      query: {
        'page': page,
        'size': size,
        if (status != null) 'status': status.code,
        if (customerId != null) 'customerId': customerId,
        if (branchId != null) 'branchId': branchId,
        if (assignedTo != null) 'assignedTo': assignedTo,
      },
      parseItem: RepairJob.fromJson,
    );
  }

  Future<int> count({RepairStatus? status, String? branchId}) async {
    final page = await search(status: status, branchId: branchId, size: 1);
    return page.totalElements;
  }

  Future<RepairJob> byId(String id) => _client.get<RepairJob>(
    ApiEndpoints.repair(id),
    parse: (data) => RepairJob.fromJson(data! as Map<String, dynamic>),
  );

  Future<List<RepairJob>> overdue(String branchId) =>
      _client.get<List<RepairJob>>(
        ApiEndpoints.overdueRepairs,
        query: {'branchId': branchId},
        parse: (data) => data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(RepairJob.fromJson)
                  .toList(growable: false)
            : const [],
      );

  Future<RepairJob> receive({
    required String customerId,
    required String branchId,
    required String itemDescription,
    String? jewelleryItemId,
    double? receivedWeight,
    String? reportedProblem,
    String? conditionOnArrival,
    DateTime? promisedDate,
    List<RepairPhoto> photos = const [],
  }) {
    return _guarded(
      () => _client.post<RepairJob>(
        ApiEndpoints.repairs,
        body: {
          'customerId': customerId,
          'branchId': branchId,
          'itemDescription': itemDescription,
          if (jewelleryItemId != null) 'jewelleryItemId': jewelleryItemId,
          if (receivedWeight != null) 'receivedWeight': receivedWeight,
          if (reportedProblem != null) 'reportedProblem': reportedProblem,
          if (conditionOnArrival != null)
            'conditionOnArrival': conditionOnArrival,
          if (promisedDate != null)
            'promisedDate': promisedDate.toIso8601String().split('T').first,
          if (photos.isNotEmpty)
            'conditionPhotoKeys': RepairJob.encodePhotos(photos),
        },
        parse: (data) => RepairJob.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  Future<RepairJob> _step(String id, String step, Map<String, dynamic> body) =>
      _guarded(
        () => _client.post<RepairJob>(
          '${ApiEndpoints.repair(id)}/$step',
          body: body,
          parse: (data) => RepairJob.fromJson(data! as Map<String, dynamic>),
        ),
      );

  Future<RepairJob> inspect(
    String id, {
    required String findings,
    List<RepairPhoto> photos = const [],
  }) => _step(id, 'inspection', {
    'findings': findings,
    if (photos.isNotEmpty) 'conditionPhotoKeys': RepairJob.encodePhotos(photos),
  });

  Future<RepairJob> estimate(
    String id, {
    required double cost,
    required int days,
    String? notes,
  }) => _step(id, 'estimate', {
    'estimatedCost': cost,
    'estimatedDays': days,
    if (notes != null) 'estimateNotes': notes,
  });

  Future<RepairJob> customerDecision(
    String id, {
    required bool approved,
    String? declineReason,
  }) => _step(id, 'customer-decision', {
    'approved': approved,
    if (declineReason != null) 'declineReason': declineReason,
  });

  Future<RepairJob> assign(String id, String artisan) =>
      _step(id, 'assign', {'assignedTo': artisan});

  Future<RepairJob> completeWork(
    String id, {
    double? finalCost,
    String? notes,
    List<RepairPhoto> photos = const [],
  }) => _step(id, 'complete-work', {
    if (finalCost != null) 'finalCost': finalCost,
    if (notes != null) 'notes': notes,
    if (photos.isNotEmpty) 'conditionPhotoKeys': RepairJob.encodePhotos(photos),
  });

  Future<RepairJob> qualityCheck(
    String id, {
    required bool passed,
    String? notes,
  }) => _step(id, 'quality-check', {
    'passed': passed,
    if (notes != null) 'notes': notes,
  });

  Future<RepairJob> deliver(
    String id, {
    required String deliveredTo,
    double? deliveredWeight,
  }) => _step(id, 'deliver', {
    'deliveredTo': deliveredTo,
    if (deliveredWeight != null) 'deliveredWeight': deliveredWeight,
  });
}
