import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:jewellery_erp/core/network/api_client.dart';
import 'package:jewellery_erp/features/jewellery/data/reference_data_service.dart';
import 'package:jewellery_erp/features/jewellery/presentation/providers/jewellery_providers.dart';
import 'package:jewellery_erp/features/jewellery/presentation/widgets/reference_gate.dart';

/// The gate exists because the reference cache is a mutable service behind a
/// plain Provider: filling its maps notifies nobody, so a screen built while
/// the prefetch is still running keeps its blanks forever.
///
/// Observed on a device: an item scanned straight after sign-in showed
/// "Metal: Gold" next to "Purity: —", because purities load in a second wave
/// after the metals they hang off. Nothing errored; the field simply stayed
/// empty until the route was rebuilt by hand.
void main() {
  Widget harness(Completer<ReferenceDataService> completer) {
    return ProviderScope(
      overrides: [
        referenceDataReadyProvider.overrideWith((ref) => completer.future),
      ],
      child: const MaterialApp(
        home: ReferenceGate(child: Text('names resolved')),
      ),
    );
  }

  testWidgets('the child is withheld until the cache has loaded', (
    tester,
  ) async {
    final completer = Completer<ReferenceDataService>();
    await tester.pumpWidget(harness(completer));

    expect(
      find.text('names resolved'),
      findsNothing,
      reason: 'a screen rendered mid-prefetch shows unresolved ids',
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(ReferenceDataService(ApiClient(Dio())));
    await tester.pumpAndSettle();

    expect(find.text('names resolved'), findsOneWidget);
  });

  testWidgets('a cache that fails to load still renders the screen', (
    tester,
  ) async {
    final completer = Completer<ReferenceDataService>();
    await tester.pumpWidget(harness(completer));

    completer.completeError(StateError('reference data unavailable'));
    await tester.pumpAndSettle();

    expect(
      find.text('names resolved'),
      findsOneWidget,
      reason: 'names are supporting detail; losing them must not block work',
    );
  });
}
