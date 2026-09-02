import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/providers.dart';
import '../../../../shared/extensions/context_extensions.dart';

/// Bytes for one stored file, keyed by its storage key.
///
/// Not `autoDispose`: a photo scrolled off a list and back should not be
/// re-downloaded, and the same key is shared by the list row and the passport
/// header. Keys are immutable, so a cached image can never be stale.
final itemPhotoProvider = FutureProvider.family<Uint8List, String>((
  ref,
  storageKey,
) async {
  final bytes = await ref
      .watch(apiClientProvider)
      .getBytes(ApiEndpoints.files, query: {'key': storageKey});
  return Uint8List.fromList(bytes);
});

/// A photograph of a piece, with a placeholder when it has none.
///
/// Most stock has no photo yet, so the empty case is the common one and is
/// drawn deliberately rather than left as a broken-image icon.
class ItemPhoto extends ConsumerWidget {
  const ItemPhoto({
    super.key,
    required this.storageKey,
    this.size = 56,
    this.radius = 12,
    this.fallbackIcon = Icons.diamond_outlined,
  });

  final String? storageKey;
  final double size;
  final double radius;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = storageKey;
    if (key == null || key.isEmpty) return _placeholder(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: ref
            .watch(itemPhotoProvider(key))
            .when(
              data: (bytes) => Image.memory(
                bytes,
                fit: BoxFit.cover,
                // A corrupt or non-image file must not take the row down with it.
                errorBuilder: (context, _, __) => _placeholder(context),
              ),
              loading: () => ColoredBox(
                color: context.scheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => _placeholder(context),
            ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      color: context.scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(
      fallbackIcon,
      size: size * 0.45,
      color: context.scheme.onSurfaceVariant,
    ),
  );
}
