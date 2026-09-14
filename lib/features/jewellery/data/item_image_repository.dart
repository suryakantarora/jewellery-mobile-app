import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

/// One photograph linked to a physical piece.
///
/// Mirrors `ItemImageResponse`. The bytes live behind `GET /files?key=` and
/// are fetched through `itemPhotoProvider`, never embedded here.
class ItemImage {
  const ItemImage({
    required this.id,
    required this.storageKey,
    this.fileName,
    this.contentType,
    this.sizeBytes,
    this.primaryImage = false,
    this.displayOrder = 0,
  });

  final String id;
  final String storageKey;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;
  final bool primaryImage;
  final int displayOrder;

  factory ItemImage.fromJson(Map<String, dynamic> json) => ItemImage(
    id: json['id'] as String? ?? '',
    storageKey: json['storageKey'] as String? ?? '',
    fileName: json['fileName'] as String?,
    contentType: json['contentType'] as String?,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
    primaryImage: json['primaryImage'] as bool? ?? false,
    displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
  );
}

/// What `POST /files` returns for an uploaded file.
class UploadedFile {
  const UploadedFile({required this.storageKey, this.contentType, this.size});

  final String storageKey;
  final String? contentType;
  final int? size;

  factory UploadedFile.fromJson(Map<String, dynamic> json) => UploadedFile(
    // The backend has used both names; accept either rather than guess.
    storageKey:
        json['storageKey'] as String? ??
        json['key'] as String? ??
        json['fileKey'] as String? ??
        '',
    contentType: json['contentType'] as String?,
    size: (json['sizeBytes'] as num? ?? json['size'] as num?)?.toInt(),
  );
}

/// Photographs of an item.
///
/// Upload happens in two steps — bytes to `/files`, then a link row — so a
/// transfer that fails midway leaves no half-written image row.
class ItemImageRepository {
  ItemImageRepository(this._client);

  final ApiClient _client;

  static String _images(String itemId) => '${ApiEndpoints.item(itemId)}/images';

  Future<List<ItemImage>> list(String itemId) => _client.get<List<ItemImage>>(
    _images(itemId),
    parse: (data) => data is List
        ? data
              .whereType<Map<String, dynamic>>()
              .map(ItemImage.fromJson)
              .toList()
        : const [],
  );

  Future<UploadedFile> upload({
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) => _client.upload<UploadedFile>(
    ApiEndpoints.files,
    bytes: bytes,
    fileName: fileName,
    contentType: contentType,
    parse: (data) => data is Map<String, dynamic>
        ? UploadedFile.fromJson(data)
        : const UploadedFile(storageKey: ''),
  );

  Future<ItemImage> link(
    String itemId, {
    required String storageKey,
    required String fileName,
    String? contentType,
    int? sizeBytes,
    required bool primaryImage,
    required int displayOrder,
  }) => _client.post<ItemImage>(
    _images(itemId),
    body: {
      'storageKey': storageKey,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'primaryImage': primaryImage,
      'displayOrder': displayOrder,
    },
    parse: (data) => data is Map<String, dynamic>
        ? ItemImage.fromJson(data)
        : ItemImage(id: '', storageKey: storageKey),
  );

  /// Adds a photo end to end: upload, then link.
  Future<ItemImage> add(
    String itemId, {
    required List<int> bytes,
    required String fileName,
    String? contentType,
    required bool primaryImage,
    required int displayOrder,
  }) async {
    final uploaded = await upload(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    return link(
      itemId,
      storageKey: uploaded.storageKey,
      fileName: fileName,
      contentType: contentType ?? uploaded.contentType,
      sizeBytes: bytes.length,
      primaryImage: primaryImage,
      displayOrder: displayOrder,
    );
  }

  /// Promotes an image to primary; the backend demotes the previous one.
  Future<ItemImage> setPrimary(String itemId, ItemImage image) => _client.put(
    '${_images(itemId)}/${image.id}',
    body: {'primaryImage': true},
    parse: (data) => ItemImage.fromJson(data as Map<String, dynamic>),
  );

  Future<void> remove(String itemId, String imageId) =>
      _client.send('${_images(itemId)}/$imageId', method: 'DELETE');
}
