import 'dart:convert';

import '../../../shared/widgets/status_badge.dart';

/// Mirrors the backend's `RepairStatus`.
enum RepairStatus {
  received('RECEIVED', 'Received', StatusTone.info),
  inspection('INSPECTION', 'Inspection', StatusTone.warning),
  estimation('ESTIMATION', 'Estimating', StatusTone.warning),
  approvalPending('APPROVAL_PENDING', 'Awaiting customer', StatusTone.warning),
  declined('DECLINED', 'Declined', StatusTone.danger),
  inProgress('IN_PROGRESS', 'In progress', StatusTone.warning),
  qualityCheck('QUALITY_CHECK', 'Quality check', StatusTone.info),
  ready('READY', 'Ready', StatusTone.success),
  delivered('DELIVERED', 'Delivered', StatusTone.neutral),
  cancelled('CANCELLED', 'Cancelled', StatusTone.neutral),
  unknown('UNKNOWN', 'Unknown', StatusTone.neutral);

  const RepairStatus(this.code, this.label, this.tone);

  final String code;
  final String label;
  final StatusTone tone;

  static RepairStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => RepairStatus.unknown,
  );

  /// The board columns, in workflow order.
  static const board = [
    RepairStatus.received,
    RepairStatus.inspection,
    RepairStatus.estimation,
    RepairStatus.approvalPending,
    RepairStatus.inProgress,
    RepairStatus.qualityCheck,
    RepairStatus.ready,
    RepairStatus.delivered,
  ];
}

/// One transition in a repair's history.
class RepairHistoryEntry {
  const RepairHistoryEntry({
    this.fromStatus,
    this.toStatus,
    this.performedBy,
    this.notes,
    this.occurredAt,
  });

  final RepairStatus? fromStatus;
  final RepairStatus? toStatus;
  final String? performedBy;
  final String? notes;
  final DateTime? occurredAt;

  factory RepairHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RepairHistoryEntry(
        fromStatus: json['fromStatus'] == null
            ? null
            : RepairStatus.fromCode(json['fromStatus'] as String?),
        toStatus: json['toStatus'] == null
            ? null
            : RepairStatus.fromCode(json['toStatus'] as String?),
        performedBy: json['performedBy'] as String?,
        notes: json['notes'] as String?,
        occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? ''),
      );
}

/// A photo attached to a repair.
///
/// `conditionPhotoKeys` on the backend is an opaque free-text field capped at
/// 1000 characters, stored verbatim. The app therefore owns the format: a JSON
/// array of `{key, type}` so before/damage/after can be told apart. Without
/// typing, the before/after comparison the specification asks for would be
/// impossible.
class RepairPhoto {
  const RepairPhoto({required this.key, required this.type});

  final String key;
  final String type;

  Map<String, dynamic> toJson() => {'key': key, 'type': type};

  factory RepairPhoto.fromJson(Map<String, dynamic> json) => RepairPhoto(
    key: json['key'] as String? ?? '',
    type: json['type'] as String? ?? 'before',
  );
}

class RepairJob {
  const RepairJob({
    required this.id,
    required this.requestNumber,
    required this.status,
    required this.allowedTransitions,
    this.customerId,
    this.jewelleryItemId,
    this.itemDescription,
    this.receivedDate,
    this.promisedDate,
    this.reportedProblem,
    this.conditionOnArrival,
    this.receivedWeight,
    this.deliveredWeight,
    this.estimatedCost,
    this.estimatedDays,
    this.estimateNotes,
    this.customerApproved = false,
    this.declineReason,
    this.assignedTo,
    this.finalCost,
    this.currency,
    this.readyAt,
    this.deliveredAt,
    this.deliveredTo,
    this.notes,
    this.photos = const [],
    this.history = const [],
  });

  final String id;
  final String requestNumber;
  final RepairStatus status;

  /// The backend's own state machine, returned with every repair.
  final Set<RepairStatus> allowedTransitions;

  final String? customerId;
  final String? jewelleryItemId;
  final String? itemDescription;
  final DateTime? receivedDate;
  final DateTime? promisedDate;
  final String? reportedProblem;
  final String? conditionOnArrival;

  final double? receivedWeight;
  final double? deliveredWeight;

  final double? estimatedCost;
  final int? estimatedDays;
  final String? estimateNotes;
  final bool customerApproved;
  final String? declineReason;
  final String? assignedTo;
  final double? finalCost;
  final String? currency;
  final DateTime? readyAt;
  final DateTime? deliveredAt;
  final String? deliveredTo;
  final String? notes;

  final List<RepairPhoto> photos;
  final List<RepairHistoryEntry> history;

  /// A promised repair that slips is a reputational event, so it is flagged
  /// rather than left to be noticed.
  bool get isOverdue =>
      promisedDate != null &&
      promisedDate!.isBefore(DateTime.now()) &&
      status != RepairStatus.delivered &&
      status != RepairStatus.cancelled;

  /// For gold, an unexplained weight change is the first thing a customer
  /// checks on collection.
  double? get weightDelta => (receivedWeight != null && deliveredWeight != null)
      ? deliveredWeight! - receivedWeight!
      : null;

  factory RepairJob.fromJson(Map<String, dynamic> json) => RepairJob(
    id: json['id'] as String? ?? '',
    requestNumber: json['requestNumber'] as String? ?? '',
    status: RepairStatus.fromCode(json['status'] as String?),
    allowedTransitions: ((json['allowedTransitions'] as List?) ?? const [])
        .whereType<String>()
        .map(RepairStatus.fromCode)
        .toSet(),
    customerId: json['customerId'] as String?,
    jewelleryItemId: json['jewelleryItemId'] as String?,
    itemDescription: json['itemDescription'] as String?,
    receivedDate: DateTime.tryParse(json['receivedDate'] as String? ?? ''),
    promisedDate: DateTime.tryParse(json['promisedDate'] as String? ?? ''),
    reportedProblem: json['reportedProblem'] as String?,
    conditionOnArrival: json['conditionOnArrival'] as String?,
    receivedWeight: (json['receivedWeight'] as num?)?.toDouble(),
    deliveredWeight: (json['deliveredWeight'] as num?)?.toDouble(),
    estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
    estimatedDays: (json['estimatedDays'] as num?)?.toInt(),
    estimateNotes: json['estimateNotes'] as String?,
    customerApproved: json['customerApproved'] as bool? ?? false,
    declineReason: json['declineReason'] as String?,
    assignedTo: json['assignedTo'] as String?,
    finalCost: (json['finalCost'] as num?)?.toDouble(),
    currency: json['currency'] as String?,
    readyAt: DateTime.tryParse(json['readyAt'] as String? ?? ''),
    deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
    deliveredTo: json['deliveredTo'] as String?,
    notes: json['notes'] as String?,
    photos: _decodePhotos(json['conditionPhotoKeys'] as String?),
    history: ((json['history'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RepairHistoryEntry.fromJson)
        .toList(growable: false),
  );

  /// Tolerates both the app's JSON format and a plain comma-separated list,
  /// since the field is free text and may already hold data written elsewhere.
  static List<RepairPhoto> _decodePhotos(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final trimmed = raw.trim();

    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(RepairPhoto.fromJson)
              .toList(growable: false);
        }
      } on FormatException {
        // Fall through to the comma-separated reading.
      }
    }

    return trimmed
        .split(',')
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .map((key) => RepairPhoto(key: key, type: 'before'))
        .toList(growable: false);
  }

  /// Encodes photos back into the single free-text field.
  ///
  /// The backend caps it at 1000 characters, so the list is trimmed rather
  /// than allowed to fail the save.
  static String encodePhotos(List<RepairPhoto> photos) {
    var encoded = jsonEncode(photos.map((p) => p.toJson()).toList());
    var trimmed = List<RepairPhoto>.from(photos);

    while (encoded.length > 1000 && trimmed.isNotEmpty) {
      trimmed.removeLast();
      encoded = jsonEncode(trimmed.map((p) => p.toJson()).toList());
    }
    return encoded;
  }
}
