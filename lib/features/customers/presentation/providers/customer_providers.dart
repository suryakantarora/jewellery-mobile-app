import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/security/session_controller.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer_models.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(
    ref.watch(apiClientProvider),
    offlineGuard: ref.watch(offlineGuardProvider),
  ),
);

final customerQueryProvider = NotifierProvider<CustomerQueryController, String>(
  CustomerQueryController.new,
);

class CustomerQueryController extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final customerSearchProvider = FutureProvider.autoDispose<List<Customer>>((
  ref,
) async {
  final query = ref.watch(customerQueryProvider);
  final repository = ref.watch(customerRepositoryProvider);

  // Digits mean a phone number, which resolves to exactly one customer — the
  // way a returning customer is actually identified at a counter.
  final digitsOnly = RegExp(r'^[\d\s+\-()]{6,}$').hasMatch(query.trim());
  if (digitsOnly) {
    final match = await repository.byPhone(query.trim());
    return match == null ? const [] : [match];
  }

  final page = await repository.search(query: query, size: 50);
  return page.content;
});

final customer360Provider = FutureProvider.autoDispose
    .family<Customer360, String>(
      (ref, id) => ref.watch(customerRepositoryProvider).profile360(id),
    );

final customerDetailProvider = FutureProvider.autoDispose
    .family<Customer, String>(
      (ref, id) => ref.watch(customerRepositoryProvider).byId(id),
    );

/// Follow-ups assigned to the signed-in user. Drives the dashboard task list.
final myFollowUpsProvider = FutureProvider.autoDispose<List<FollowUp>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(customerRepositoryProvider).myFollowUps();
});

/// A customer's wishlist. Invalidated after every add or remove.
final customerWishlistProvider = FutureProvider.autoDispose
    .family<List<WishlistEntry>, String>(
      (ref, customerId) =>
          ref.watch(customerRepositoryProvider).wishlist(customerId),
    );
