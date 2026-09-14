import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/permission_widgets.dart';
import '../../data/item_image_repository.dart';
import '../providers/jewellery_providers.dart';
import 'item_photo.dart';

final itemImageRepositoryProvider = Provider<ItemImageRepository>(
  (ref) => ItemImageRepository(ref.watch(apiClientProvider)),
);

/// Every photograph of one item, newest last. Refreshed by invalidation after
/// each mutation, so the strip always reflects what the server holds.
final itemImagesProvider = FutureProvider.autoDispose
    .family<List<ItemImage>, String>((ref, itemId) {
      ref.watch(currentUserProvider);
      return ref.watch(itemImageRepositoryProvider).list(itemId);
    });

/// A horizontal strip of an item's photographs.
///
/// Tap opens the photo full screen; long-press offers set-primary / delete.
/// Viewing needs `INVENTORY_VIEW`; adding and deleting need `INVENTORY_CREATE`
/// and `FILE_UPLOAD`. Mount with `SliverToBoxAdapter(child: ItemImageGallery(
/// itemId: item.id))` inside the passport's `CustomScrollView`.
class ItemImageGallery extends ConsumerStatefulWidget {
  const ItemImageGallery({super.key, required this.itemId});

  final String itemId;

  static const editPermissions = [
    Permission.inventoryCreate,
    Permission.fileUpload,
  ];

  @override
  ConsumerState<ItemImageGallery> createState() => _ItemImageGalleryState();
}

class _ItemImageGalleryState extends ConsumerState<ItemImageGallery> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      requires: Permission.inventoryView,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Photos', style: context.text.titleSmall),
                  ),
                  PermissionGuard(
                    requiresAll: ItemImageGallery.editPermissions,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _addPhoto,
                      icon: _busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Add photo'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 96,
              child: ref
                  .watch(itemImagesProvider(widget.itemId))
                  .when(
                    data: _strip,
                    loading: () => const Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => Center(
                      child: Text(
                        'Photos could not be loaded',
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strip(List<ItemImage> images) {
    if (images.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No photos yet',
          style: context.text.bodySmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final sorted = images.toList()
      ..sort((a, b) {
        if (a.primaryImage != b.primaryImage) return a.primaryImage ? -1 : 1;
        return a.displayOrder.compareTo(b.displayOrder);
      });

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => AppSpacing.wGapSm,
      itemBuilder: (context, index) {
        final image = sorted[index];
        return GestureDetector(
          onTap: () => _view(sorted, index),
          onLongPress: () => _actions(image),
          child: Stack(
            children: [
              ItemPhoto(storageKey: image.storageKey, size: 96, radius: 12),
              if (image.primaryImage)
                Positioned(
                  left: 6,
                  top: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.scheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'Primary',
                        style: context.text.labelSmall?.copyWith(
                          color: context.scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _view(List<ItemImage> images, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGallery(images: images, initialIndex: index),
      ),
    );
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        // Photos of stock are for identification, not print: a bounded edge
        // keeps uploads small on a showroom's connection.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } on Object {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Could not open the camera or gallery',
          tone: SnackTone.error,
        );
      }
      return;
    }
    if (picked == null || !mounted) return;

    await _run(() async {
      final bytes = await picked!.readAsBytes();
      final existing =
          ref.read(itemImagesProvider(widget.itemId)).valueOrNull ?? const [];
      final nextOrder = existing.isEmpty
          ? 0
          : existing
                    .map((i) => i.displayOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      await ref
          .read(itemImageRepositoryProvider)
          .add(
            widget.itemId,
            bytes: bytes,
            fileName: picked.name,
            contentType: picked.mimeType ?? 'image/jpeg',
            // The first photo becomes the passport image without a second tap.
            primaryImage: existing.isEmpty,
            displayOrder: nextOrder,
          );
    }, success: 'Photo added');
  }

  Future<void> _actions(ItemImage image) async {
    final permissions = ref.read(permissionsProvider);
    if (!permissions.hasAll(ItemImageGallery.editPermissions)) return;

    final action = await showModalBottomSheet<_ImageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!image.primaryImage)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Set as primary'),
                onTap: () => Navigator.of(context).pop(_ImageAction.primary),
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.danger),
              title: Text(
                'Delete photo',
                style: TextStyle(color: context.colors.danger),
              ),
              onTap: () => Navigator.of(context).pop(_ImageAction.delete),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _ImageAction.primary:
        await _run(
          () => ref
              .read(itemImageRepositoryProvider)
              .setPrimary(widget.itemId, image),
          success: 'Primary photo updated',
        );
      case _ImageAction.delete:
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Delete photo?',
          message: 'This removes the photo from the item. It cannot be undone.',
          confirmLabel: 'Delete',
          tone: ConfirmTone.danger,
        );
        if (!confirmed || !mounted) return;
        await _run(
          () => ref
              .read(itemImageRepositoryProvider)
              .remove(widget.itemId, image.id),
          success: 'Photo deleted',
        );
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(itemImagesProvider(widget.itemId));
      // The passport header reads `primaryImageKey` from the item itself.
      ref.invalidate(itemPassportProvider(widget.itemId));
      if (mounted) {
        showAppSnackBar(context, message: success, tone: SnackTone.success);
      }
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } on Object {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Something went wrong',
          tone: SnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

enum _ImageAction { primary, delete }

/// Swipeable full-screen viewer with pinch-to-zoom.
class _FullScreenGallery extends ConsumerStatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});

  final List<ItemImage> images;
  final int initialIndex;

  @override
  ConsumerState<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends ConsumerState<_FullScreenGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} of ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: ref
                  .watch(itemPhotoProvider(image.storageKey))
                  .when(
                    data: (bytes) => Image.memory(bytes, fit: BoxFit.contain),
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
            ),
          );
        },
      ),
    );
  }
}
