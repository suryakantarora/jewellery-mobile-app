import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/permissions.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_dialogs.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_timeline.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/data_display.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/customer_models.dart';
import '../providers/customer_providers.dart';

/// Customer search, phone-first.
class CustomerSearchScreen extends ConsumerWidget {
  const CustomerSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(customerSearchProvider);
    final canCreate = ref
        .watch(permissionsProvider)
        .has(Permission.customerManage);

    return AppScaffold(
      title: context.l10n.screenCustomers,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('New'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppSearchField(
              hint: 'Phone number or name',
              onChanged: (value) =>
                  ref.read(customerQueryProvider.notifier).set(value),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<Customer>>(
              value: results,
              onRetry: () => ref.invalidate(customerSearchProvider),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No customers found',
                message: 'Search by phone number for the fastest match.',
              ),
              data: (list) => ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _CustomerRow(customer: list[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showAppBottomSheet<Customer>(
      context,
      title: 'New customer',
      subtitle: 'Phone number is checked for an existing record first.',
      builder: (context) => const _CreateCustomerForm(),
    );

    if (created != null && context.mounted) {
      ref.invalidate(customerSearchProvider);
      unawaited(context.push(AppRoutes.customerPath(created.id)));
    }
  }
}

class _CustomerRow extends ConsumerWidget {
  const _CustomerRow({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatters = ref.watch(formattersProvider);
    final canSeeFullPhone = ref
        .watch(permissionsProvider)
        .has(Permission.customerManage);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        backgroundColor: customer.isBlacklisted
            ? context.colors.dangerContainer
            : context.scheme.surfaceContainerHighest,
        child: Text(
          customer.displayName.isEmpty
              ? '?'
              : customer.displayName[0].toUpperCase(),
          style: context.text.titleSmall,
        ),
      ),
      title: Text(customer.displayName),
      subtitle: Text(
        [
          // Masked by default: a customer list on a counter device is visible
          // to whoever is standing there.
          canSeeFullPhone
              ? (customer.phone ?? '—')
              : formatters.masked(customer.phone),
          customer.customerCode,
        ].join('  ·  '),
        style: context.text.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (customer.isBlacklisted)
            StatusBadge(
              label: customer.status.label,
              tone: customer.status.tone,
              dense: true,
            )
          else if (customer.kycStatus == KycStatus.verified)
            StatusBadge(
              label: 'KYC',
              tone: customer.kycStatus.tone,
              dense: true,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.push(AppRoutes.customerPath(customer.id)),
    );
  }
}

/// Customer creation.
///
/// The phone number is checked against existing records before the form can be
/// submitted — a duplicate record for an existing customer is the most common
/// and most annoying data-quality failure in retail CRM.
class _CreateCustomerForm extends ConsumerStatefulWidget {
  const _CreateCustomerForm();

  @override
  ConsumerState<_CreateCustomerForm> createState() =>
      _CreateCustomerFormState();
}

class _CreateCustomerFormState extends ConsumerState<_CreateCustomerForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  Customer? _duplicate;
  bool _checking = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _checkDuplicate() async {
    final phone = _phone.text.trim();
    if (phone.length < 6) {
      setState(() => _duplicate = null);
      return;
    }

    setState(() => _checking = true);
    final match = await ref.read(customerRepositoryProvider).byPhone(phone);
    if (mounted) {
      setState(() {
        _duplicate = match;
        _checking = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(customerRepositoryProvider)
          .create(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            registeredBranchId: ref.read(currentBranchProvider)?.id,
          );
      if (mounted) Navigator.of(context).pop(created);
    } on AppException catch (error) {
      if (mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _name.text.trim().isNotEmpty &&
        _phone.text.trim().length >= 6 &&
        _duplicate == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _name,
          label: 'Full name',
          prefixIcon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _phone,
          label: 'Phone',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          onChanged: (_) {
            setState(() {});
            _checkDuplicate();
          },
          suffix: _checking
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        if (_duplicate != null) ...[
          AppSpacing.gapMd,
          AppCard(
            tone: context.colors.warningContainer.withValues(alpha: 0.5),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: context.colors.warning,
                ),
                AppSpacing.wGapMd,
                Expanded(
                  child: Text(
                    '${_duplicate!.displayName} already has this number.',
                    style: context.text.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_duplicate),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),
        ],
        AppSpacing.gapMd,
        AppTextField(
          controller: _email,
          label: 'Email (optional)',
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
        ),
        AppSpacing.gapXl,
        AppButton(
          label: 'Create customer',
          busy: _busy,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

/// Customer 360 — one backend call, rendered as profile, stats and timeline.
class Customer360Screen extends ConsumerWidget {
  const Customer360Screen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customer360Provider(customerId));
    final detail = ref.watch(customerDetailProvider(customerId));
    final formatters = ref.watch(formattersProvider);
    final permissions = ref.watch(permissionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: AsyncValueView<Customer360>(
        value: profile,
        loading: const Center(child: CircularProgressIndicator()),
        onRetry: () => ref.invalidate(customer360Provider(customerId)),
        data: (data) {
          final customer = detail.valueOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.huge,
            ),
            children: [
              if (customer?.isBlacklisted ?? false) ...[
                AppCard(
                  tone: context.colors.dangerContainer.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: context.colors.danger),
                      AppSpacing.wGapMd,
                      Expanded(
                        child: Text(
                          'This customer is blacklisted.',
                          style: context.text.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
              ],

              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: context.scheme.primaryContainer,
                    child: Text(
                      data.fullName.isEmpty
                          ? '?'
                          : data.fullName[0].toUpperCase(),
                      style: context.text.titleLarge,
                    ),
                  ),
                  AppSpacing.wGapLg,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.fullName, style: context.text.titleLarge),
                        AppSpacing.gapXxs,
                        Text(
                          [
                            data.customerCode,
                            // Masked unless the viewer manages customers.
                            permissions.has(Permission.customerManage)
                                ? (data.phone ?? '—')
                                : formatters.masked(data.phone),
                          ].join('  ·  '),
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                        if (data.kycVerified) ...[
                          AppSpacing.gapSm,
                          const StatusBadge(
                            label: 'KYC verified',
                            tone: StatusTone.success,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.gapXl,

              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Lifetime value',
                      value: formatters.money(
                        data.purchaseTotal,
                        data.purchaseCurrency,
                        compact: true,
                      ),
                      caption: data.purchaseCount == null
                          ? null
                          : '${data.purchaseCount} purchases',
                      icon: Icons.payments_outlined,
                      sensitive: true,
                    ),
                  ),
                  AppSpacing.wGapMd,
                  Expanded(
                    child: StatTile(
                      label: 'Loyalty',
                      value: data.loyaltyPoints == null
                          ? '—'
                          : formatters.count(data.loyaltyPoints),
                      caption: data.loyaltyTier,
                      icon: Icons.card_giftcard_outlined,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapXl,

              _WishlistSection(customerId: customerId),
              AppSpacing.gapLg,

              if (data.openFollowUps.isNotEmpty) ...[
                SectionCard(
                  title: 'Open follow-ups (${data.openFollowUps.length})',
                  icon: Icons.flag_outlined,
                  child: Column(
                    children: [
                      for (final followUp in data.openFollowUps)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            Icons.circle,
                            size: 10,
                            color: followUp.isOverdue
                                ? context.colors.danger
                                : context.colors.warning,
                          ),
                          title: Text(followUp.title),
                          subtitle: followUp.dueDate == null
                              ? null
                              : Text(
                                  'Due ${formatters.date(followUp.dueDate)}',
                                  style: context.text.labelSmall?.copyWith(
                                    color: followUp.isOverdue
                                        ? context.colors.danger
                                        : null,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
              ],

              SectionCard(
                title: 'Activity',
                icon: Icons.timeline,
                trailing: TextButton(
                  onPressed: () => _logActivity(context, ref, data.customerId),
                  child: const Text('Log'),
                ),
                child: data.recentActivity.isEmpty
                    ? Text(
                        'No activity recorded yet.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.scheme.onSurfaceVariant,
                        ),
                      )
                    : AppTimeline(
                        formatTimestamp: formatters.relative,
                        events: [
                          for (final activity in data.recentActivity)
                            TimelineEvent(
                              title: activity.subject ?? activity.activityType,
                              subtitle: activity.notes,
                              actor: activity.performedBy,
                              timestamp: activity.occurredAt,
                              tone: activity.tone,
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logActivity(
    BuildContext context,
    WidgetRef ref,
    String customerId,
  ) async {
    const types = ['CALL', 'VISIT', 'MESSAGE', 'MEETING', 'COMPLAINT', 'NOTE'];

    final type = await showAppBottomSheet<String>(
      context,
      title: 'Log activity',
      builder: (context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final option in types)
            ActionChip(
              label: Text(option),
              onPressed: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );

    if (type == null || !context.mounted) return;

    final note = await showReasonSheet(
      context,
      title: '$type note',
      hint: 'What happened?',
    );
    if (note == null) return;

    try {
      await ref
          .read(customerRepositoryProvider)
          .logActivity(customerId: customerId, activityType: type, notes: note);
      ref.invalidate(customer360Provider(customerId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: 'Activity logged',
          tone: SnackTone.success,
        );
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    }
  }
}

/// The customer's wishlist: pieces they asked about, or products and designs
/// they want "one like".
///
/// Tapping a piece opens its passport; an entry with only a product or design
/// has no passport to open and says so. Swipe or the icon removes an entry.
class _WishlistSection extends ConsumerWidget {
  const _WishlistSection({required this.customerId});

  final String customerId;

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    WishlistEntry entry,
  ) async {
    try {
      await ref
          .read(customerRepositoryProvider)
          .removeFromWishlist(customerId, entry.id);
      ref.invalidate(customerWishlistProvider(customerId));
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: '${entry.title} removed from wishlist',
          tone: SnackTone.success,
        );
      }
    } on AppException catch (error) {
      ref.invalidate(customerWishlistProvider(customerId));
      if (context.mounted) {
        showAppSnackBar(context, message: error.message, tone: SnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(customerWishlistProvider(customerId));
    final formatters = ref.watch(formattersProvider);
    final canManage = ref.watch(permissionsProvider).hasAny({
      Permission.customerManage,
      Permission.saleCreate,
    });
    final count = wishlist.valueOrNull?.length;

    return SectionCard(
      title: count == null ? 'Wishlist' : 'Wishlist ($count)',
      icon: Icons.favorite_border,
      child: AsyncValueView<List<WishlistEntry>>(
        value: wishlist,
        loading: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        onRetry: () => ref.invalidate(customerWishlistProvider(customerId)),
        isEmpty: (list) => list.isEmpty,
        empty: Text(
          'Nothing on the wishlist yet. Add pieces from Sales Assistance.',
          style: context.text.bodySmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        data: (entries) => Column(
          children: [
            for (final entry in entries)
              Dismissible(
                key: ValueKey(entry.id),
                direction: canManage
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  color: context.colors.dangerContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: context.colors.danger,
                  ),
                ),
                onDismissed: (_) => _remove(context, ref, entry),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    entry.hasItem
                        ? Icons.diamond_outlined
                        : Icons.category_outlined,
                    color: entry.hasItem
                        ? context.scheme.primary
                        : context.scheme.outline,
                  ),
                  title: Text(entry.title),
                  subtitle: Text(
                    [
                      if (entry.hasItem && entry.productName != null)
                        entry.productName!,
                      if (entry.hasItem && entry.itemStatus != null)
                        entry.itemStatus!,
                      if (!entry.hasItem) 'No specific piece chosen',
                      if (entry.currentPrice != null)
                        formatters.money(entry.currentPrice, entry.currency),
                      if (entry.note != null && entry.note!.isNotEmpty)
                        entry.note!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove',
                          onPressed: () => _remove(context, ref, entry),
                        )
                      : null,
                  onTap: entry.hasItem
                      ? () => context.push(
                          AppRoutes.itemDetailPath(entry.jewelleryItemId!),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
