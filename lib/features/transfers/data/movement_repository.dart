import 'package:uuid/uuid.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../domain/movement.dart';

/// Stock movements: transfers, and the issue/return operations Phase 8 uses.
class MovementRepository {
  MovementRepository(this._client);

  final ApiClient _client;
  static const _uuid = Uuid();

  Future<PageResponse<Movement>> search({
    MovementStatus? status,
    MovementType? movementType,
    String? fromLocationId,
    String? toLocationId,
    int page = 0,
    int size = 20,
  }) {
    return _client.getPage<Movement>(
      ApiEndpoints.transfers,
      query: {
        'page': page,
        'size': size,
        if (status != null) 'status': status.code,
        if (movementType != null) 'movementType': movementType.code,
        if (fromLocationId != null) 'fromLocationId': fromLocationId,
        if (toLocationId != null) 'toLocationId': toLocationId,
      },
      parseItem: Movement.fromJson,
    );
  }

  Future<int> count({MovementStatus? status, String? toLocationId}) async {
    final page = await search(
      status: status,
      toLocationId: toLocationId,
      size: 1,
    );
    return page.totalElements;
  }

  Future<Movement> byId(String id) => _client.get<Movement>(
    ApiEndpoints.transfer(id),
    parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
  );

  /// Raises a movement.
  ///
  /// `idempotencyKey` is generated once per user intent by the caller — not per
  /// retry — so a double tap on a flaky connection cannot create two transfers
  /// of the same items. The backend does not yet honour the header on this
  /// endpoint (only sales, payments and goods receipts do), but sending it
  /// costs nothing and the protection lands the moment it does.
  Future<Movement> create({
    required MovementType movementType,
    required String toLocationId,
    required List<String> itemIds,
    String? fromLocationId,
    String? notes,
    String? idempotencyKey,
  }) {
    return _client.post<Movement>(
      ApiEndpoints.transfers,
      body: {
        'movementType': movementType.code,
        'toLocationId': toLocationId,
        'itemIds': itemIds,
        if (fromLocationId != null) 'fromLocationId': fromLocationId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
      parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<Movement> approve(String id) => _client.post<Movement>(
    ApiEndpoints.transferApprove(id),
    parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
  );

  Future<Movement> reject(String id, String reason) => _client.post<Movement>(
    ApiEndpoints.transferReject(id),
    body: {'reason': reason},
    parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
  );

  Future<Movement> dispatch(String id) => _client.post<Movement>(
    ApiEndpoints.transferDispatch(id),
    parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
  );

  /// Confirms receipt, optionally recording re-weighed values and per-item
  /// discrepancy notes.
  ///
  /// The backend accepts `{lines: [{jewelleryItemId, receivedWeight,
  /// discrepancyNote}], notes}`, so a short receipt is reported rather than
  /// silently accepted.
  Future<Movement> receive(
    String id, {
    List<ReceivedLine> lines = const [],
    String? notes,
  }) {
    return _client.post<Movement>(
      ApiEndpoints.transferReceive(id),
      body: {
        if (lines.isNotEmpty)
          'lines': [
            for (final line in lines)
              {
                'jewelleryItemId': line.jewelleryItemId,
                if (line.receivedWeight != null)
                  'receivedWeight': line.receivedWeight,
                if (line.discrepancyNote != null)
                  'discrepancyNote': line.discrepancyNote,
              },
          ],
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
    );
  }

  Future<Movement> cancel(String id) => _client.post<Movement>(
    ApiEndpoints.transferCancel(id),
    parse: (data) => Movement.fromJson(data! as Map<String, dynamic>),
  );
}

/// One line of a receipt confirmation.
class ReceivedLine {
  const ReceivedLine({
    required this.jewelleryItemId,
    this.receivedWeight,
    this.discrepancyNote,
  });

  final String jewelleryItemId;
  final double? receivedWeight;
  final String? discrepancyNote;
}
