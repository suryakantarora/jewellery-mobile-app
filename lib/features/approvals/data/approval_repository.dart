import '../../../core/connectivity/offline_guard.dart';
import '../../../core/network/api_client.dart';
import '../domain/approval_models.dart';

/// The unified approvals API, `/api/v1/approvals`.
///
/// One list, already scoped by the backend to what the caller may approve and
/// to the branches they can see; one decision call for every type. The client
/// no longer fans out to each module or infers approvability from permissions.
class ApprovalRepository {
  ApprovalRepository(this._client, {OfflineGuard? offlineGuard})
    : _offlineGuard = offlineGuard;

  final ApiClient _client;
  final OfflineGuard? _offlineGuard;

  Future<T> _guarded<T>(Future<T> Function() action) =>
      _offlineGuard?.run(action) ?? action();

  static const _base = '/approvals';
  static String _item(ApprovalKind kind, String id) =>
      '$_base/${kind.code}/$id';

  /// Oldest first, at most 200. Unknown types are skipped, not fatal.
  Future<List<ApprovalItem>> pending({String? branchId, ApprovalKind? kind}) {
    return _client.get<List<ApprovalItem>>(
      '$_base/pending',
      query: {
        if (branchId != null) 'branchId': branchId,
        if (kind != null) 'type': kind.code,
      },
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(ApprovalItem.fromJson)
                .whereType<ApprovalItem>()
                .toList(growable: false)
          : const [],
    );
  }

  Future<ApprovalCounts> counts({String? branchId}) => _client.get(
    '$_base/pending/count',
    query: {if (branchId != null) 'branchId': branchId},
    parse: (data) => data is Map<String, dynamic>
        ? ApprovalCounts.fromJson(data)
        : ApprovalCounts.empty,
  );

  /// Records a decision. [idempotencyKey] is minted once per user intent so a
  /// retried tap cannot register twice.
  Future<ApprovalDecisionResult> decide(
    ApprovalItem item, {
    required ApprovalDecision decision,
    String? reason,
    String? idempotencyKey,
  }) {
    return _guarded(
      () => _client.post<ApprovalDecisionResult>(
        '${_item(item.kind, item.id)}/decision',
        body: {
          'decision': decision.code,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
        idempotencyKey: idempotencyKey,
        parse: (data) =>
            ApprovalDecisionResult.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }

  Future<List<InformationRequest>> information(ApprovalKind kind, String id) =>
      _client.get<List<InformationRequest>>(
        '${_item(kind, id)}/information',
        parse: (data) => data is List
            ? data
                  .whereType<Map<String, dynamic>>()
                  .map(InformationRequest.fromJson)
                  .toList(growable: false)
            : const [],
      );

  Future<InformationRequest> answer(
    ApprovalKind kind,
    String id, {
    required String requestId,
    required String answer,
  }) {
    return _guarded(
      () => _client.post<InformationRequest>(
        '${_item(kind, id)}/information/$requestId/answer',
        body: {'answer': answer},
        parse: (data) =>
            InformationRequest.fromJson(data! as Map<String, dynamic>),
      ),
    );
  }
}
