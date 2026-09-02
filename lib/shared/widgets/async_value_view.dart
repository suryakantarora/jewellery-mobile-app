import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_motion.dart';
import 'skeletons.dart';
import 'state_views.dart';

/// Maps a Riverpod [AsyncValue] to loading, error, empty and data states.
///
/// This is the load-state contract for every screen in the app. Building it
/// once here is why the remaining phases do not each reinvent "what does this
/// list look like while it is loading, and what if it comes back empty".
///
/// Data is cross-faded in rather than snapping, and a refresh keeps the old
/// content on screen instead of flashing a skeleton over data the user is
/// already reading.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.skeletonCount = 6,
  });

  final AsyncValue<T> value;

  final Widget Function(T data) data;

  /// Defaults to a skeleton list; pass a shape that matches the real content.
  final Widget? loading;

  final Widget Function(AppException error)? error;
  final VoidCallback? onRetry;

  /// Lets a list report emptiness without this widget knowing its type.
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  final int skeletonCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => KeyedSubtree(
        key: const ValueKey('loading'),
        child: loading ?? SkeletonList(itemCount: skeletonCount),
      ),
      error: (raw, stack) {
        final exception = raw is AppException ? raw : const ServerException();
        return KeyedSubtree(
          key: const ValueKey('error'),
          child:
              error?.call(exception) ??
              ErrorState(error: exception, onRetry: onRetry),
        );
      },
      data: (result) {
        if (isEmpty?.call(result) ?? false) {
          return KeyedSubtree(
            key: const ValueKey('empty'),
            child: empty ?? const EmptyState(),
          );
        }
        return KeyedSubtree(key: const ValueKey('data'), child: data(result));
      },
    );
  }
}

/// The sliver form, for screens built from a [CustomScrollView].
class SliverAsyncValueView<T> extends StatelessWidget {
  const SliverAsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(child: SkeletonList()),
      error: (raw, stack) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorState(
          error: raw is AppException ? raw : const ServerException(),
          onRetry: onRetry,
        ),
      ),
      data: (result) {
        if (isEmpty?.call(result) ?? false) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: empty ?? const EmptyState(),
          );
        }
        return data(result);
      },
    );
  }
}
