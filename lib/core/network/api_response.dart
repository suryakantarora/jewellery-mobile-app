/// The backend's success envelope: `{success, data, message, timestamp}`.
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.data,
    this.message,
    this.timestamp,
  });

  final bool success;
  final T? data;
  final String? message;
  final DateTime? timestamp;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) fromData,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? true,
      data: json.containsKey('data') && json['data'] != null
          ? fromData(json['data'])
          : null,
      message: json['message'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}

/// The backend's paged envelope, returned by every list endpoint.
class PageResponse<T> {
  const PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  /// Terminator for infinite scroll — the backend tells us when to stop rather
  /// than the client inferring it from a short page.
  final bool last;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> item) fromItem,
  ) {
    final rawContent = json['content'];
    return PageResponse<T>(
      content: rawContent is List
          ? rawContent
                .whereType<Map<String, dynamic>>()
                .map(fromItem)
                .toList(growable: false)
          : const [],
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      last: json['last'] as bool? ?? true,
    );
  }

  static PageResponse<T> empty<T>() => PageResponse<T>(
    content: const [],
    page: 0,
    size: 0,
    totalElements: 0,
    totalPages: 0,
    last: true,
  );

  bool get isEmpty => content.isEmpty;
  bool get hasMore => !last;

  PageResponse<T> merge(PageResponse<T> next) => PageResponse<T>(
    content: [...content, ...next.content],
    page: next.page,
    size: next.size,
    totalElements: next.totalElements,
    totalPages: next.totalPages,
    last: next.last,
  );
}
