import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewellery_erp/core/network/api_client.dart';
import 'package:jewellery_erp/features/jewellery/data/jewellery_repository.dart';
import 'package:jewellery_erp/features/jewellery/domain/bulk_tag_resolution.dart';
import 'package:jewellery_erp/features/scanner/presentation/providers/scanner_providers.dart';

/// Answers `/inventory/items/by-tags` by resolving every tag that starts with
/// `ok-` and rejecting the rest, recording each request's tag list.
class _StubAdapter implements HttpClientAdapter {
  final List<List<String>> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = options.data as Map<String, dynamic>;
    final tags = (body['tags'] as List).cast<String>();
    requests.add(tags);

    final json = {
      'success': true,
      'data': {
        'resolved': [
          for (final tag in tags)
            if (tag.startsWith('ok-'))
              {
                'tag': tag,
                'item': {
                  'id': 'id-$tag',
                  'itemCode': tag.toUpperCase(),
                  'status': 'AVAILABLE',
                  'grossWeight': 1.5,
                  'productName': 'Ring $tag',
                },
              },
        ],
        'unresolved': [
          for (final tag in tags)
            if (!tag.startsWith('ok-')) tag,
        ],
      },
    };
    return ResponseBody.fromString(
      jsonEncode(json),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

JewelleryRepository _repository(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://stub'));
  dio.httpClientAdapter = adapter;
  return JewelleryRepository(ApiClient(dio));
}

void main() {
  group('BulkTagResolution.fromJson', () {
    test('parses resolved pairs and unresolved strings', () {
      final resolution = BulkTagResolution.fromJson({
        'resolved': [
          {
            'tag': 'RF-1',
            'item': {
              'id': 'i1',
              'itemCode': 'RNG-0001',
              'status': 'AVAILABLE',
              'grossWeight': 2.0,
              'productName': 'Solitaire',
            },
          },
        ],
        'unresolved': ['nope', 'still-nope'],
      });

      expect(resolution.resolvedCount, 1);
      expect(resolution.resolved.single.tag, 'RF-1');
      expect(resolution.resolved.single.item.itemCode, 'RNG-0001');
      expect(resolution.resolved.single.item.productName, 'Solitaire');
      expect(resolution.unresolved, ['nope', 'still-nope']);
      expect(resolution.itemFor('RF-1')?.id, 'i1');
      expect(resolution.itemFor('nope'), isNull);
    });

    test('tolerates missing keys and malformed entries', () {
      final resolution = BulkTagResolution.fromJson({
        'resolved': [
          'not a map',
          {'tag': 'no-item'},
          {'tag': 'x', 'item': 'not a map'},
        ],
      });
      expect(resolution.resolved, isEmpty);
      expect(resolution.unresolved, isEmpty);
      expect(resolution.hasUnresolved, isFalse);
    });

    test('merge keeps order across chunks', () {
      final a = BulkTagResolution.fromJson({
        'resolved': [
          {
            'tag': 'a',
            'item': {'id': '1', 'itemCode': 'A'},
          },
        ],
        'unresolved': ['u1'],
      });
      final b = BulkTagResolution.fromJson({
        'resolved': [
          {
            'tag': 'b',
            'item': {'id': '2', 'itemCode': 'B'},
          },
        ],
        'unresolved': ['u2'],
      });

      final merged = a.merge(b);
      expect(merged.resolved.map((e) => e.tag), ['a', 'b']);
      expect(merged.unresolved, ['u1', 'u2']);
      expect(merged.byTag.keys, ['a', 'b']);
    });
  });

  group('JewelleryRepository.chunkTags', () {
    test(
      'dedupes, trims and drops blanks while preserving first-seen order',
      () {
        final chunks = JewelleryRepository.chunkTags([
          ' b ',
          'a',
          'b',
          '',
          '   ',
          'c',
          'a',
        ]);
        expect(chunks, [
          ['b', 'a', 'c'],
        ]);
      },
    );

    test('splits at the chunk size with a short tail', () {
      final tags = List.generate(450, (i) => 't$i');
      final chunks = JewelleryRepository.chunkTags(tags);

      expect(chunks.length, 3);
      expect(chunks[0].length, JewelleryRepository.byTagsChunkSize);
      expect(chunks[1].length, JewelleryRepository.byTagsChunkSize);
      expect(chunks[2].length, 50);
      expect(chunks.expand((c) => c), tags);
    });

    test('an exact multiple produces no empty trailing chunk', () {
      final chunks = JewelleryRepository.chunkTags(
        List.generate(400, (i) => 't$i'),
      );
      expect(chunks.length, 2);
      expect(chunks.every((c) => c.length == 200), isTrue);
    });

    test('nothing to send produces no chunks', () {
      expect(JewelleryRepository.chunkTags(const []), isEmpty);
      expect(JewelleryRepository.chunkTags(const ['', ' ']), isEmpty);
    });
  });

  group('JewelleryRepository.byTags', () {
    test('issues one request per chunk and merges the results', () async {
      final adapter = _StubAdapter();
      final repository = _repository(adapter);

      final tags = [
        for (var i = 0; i < 250; i++) i.isEven ? 'ok-$i' : 'bad-$i',
      ];
      final resolution = await repository.byTags(tags);

      expect(adapter.requests.length, 2);
      expect(adapter.requests[0].length, 200);
      expect(adapter.requests[1].length, 50);
      expect(resolution.resolvedCount, 125);
      expect(resolution.unresolvedCount, 125);
      expect(resolution.itemFor('ok-0')?.itemCode, 'OK-0');
    });

    test('duplicate scans resolve once', () async {
      final adapter = _StubAdapter();
      final repository = _repository(adapter);

      final resolution = await repository.byTags(['ok-1', 'ok-1', 'ok-1']);

      expect(adapter.requests.single, ['ok-1']);
      expect(resolution.resolvedCount, 1);
    });
  });

  group('BulkScanResult', () {
    test('canonical tags substitute the item code where a scan resolved', () {
      final resolution = BulkTagResolution.fromJson({
        'resolved': [
          {
            'tag': 'barcode-77',
            'item': {'id': 'i7', 'itemCode': 'RNG-0077'},
          },
        ],
        'unresolved': ['ghost'],
      });
      final result = BulkScanResult(
        tags: const ['barcode-77', 'ghost'],
        resolution: resolution,
      );

      expect(result.canonicalTags, ['RNG-0077', 'ghost']);
      expect(result.itemsByCode.keys, ['RNG-0077']);
      expect(result.itemsByCode['RNG-0077']?.id, 'i7');
    });

    test('without a resolution the raw tags pass through unchanged', () {
      const result = BulkScanResult(tags: ['a', 'b']);
      expect(result.canonicalTags, ['a', 'b']);
      expect(result.itemsByCode, isEmpty);
    });
  });
}
