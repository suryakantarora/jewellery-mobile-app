import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/jewellery_providers.dart';

/// Holds a screen back until the reference cache has loaded.
///
/// The cache is a mutable service behind a plain `Provider`, so filling its
/// maps notifies no one: a screen built while the prefetch is still running
/// keeps whatever was missing at that moment until something else rebuilds it.
///
/// The failure is quiet and uneven, which is what makes it worth a shared
/// guard. Purities load in a second wave, after the metals they hang off, so an
/// item scanned straight after sign-in rendered "Metal: Gold" beside
/// "Purity: —" — one field resolved, its neighbour blank, no error anywhere.
///
/// Wrap any screen that turns ids into names. Screens that only show data the
/// API returned in full do not need it.
class ReferenceGate extends ConsumerWidget {
  const ReferenceGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(referenceDataReadyProvider)
        .when(
          data: (_) => child,
          loading: () => const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          // Names are supporting detail, never the point of the screen. If the
          // cache cannot load, the screen still renders — ids simply stay
          // unresolved — rather than blocking the work behind it.
          error: (error, _) => child,
        );
  }
}
