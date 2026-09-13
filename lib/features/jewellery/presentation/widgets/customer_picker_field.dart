import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_inputs.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../customers/presentation/providers/customer_providers.dart';

/// Finds a customer by name or phone, for the reserve and repair sheets.
///
/// Searches through the customers repository directly rather than the shared
/// `customerSearchProvider`: that provider is bound to the Customers screen's
/// query state, and typing in a sheet must not rewrite what the Customers tab
/// is showing underneath.
class CustomerPickerField extends ConsumerStatefulWidget {
  const CustomerPickerField({
    super.key,
    required this.onSelected,
    this.selected,
    this.autofocus = false,
  });

  final Customer? selected;
  final ValueChanged<Customer?> onSelected;
  final bool autofocus;

  @override
  ConsumerState<CustomerPickerField> createState() =>
      _CustomerPickerFieldState();
}

class _CustomerPickerFieldState extends ConsumerState<CustomerPickerField> {
  final _debouncer = Debouncer();
  final _controller = TextEditingController();

  List<Customer> _results = const [];
  bool _searching = false;
  String? _error;
  int _requestSerial = 0;

  static final _phoneLike = RegExp(r'^[\d\s+\-()]{6,}$');

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    if (query.length < 2) {
      _debouncer.cancel();
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debouncer.run(() => _search(query));
  }

  Future<void> _search(String query) async {
    final serial = ++_requestSerial;
    final repository = ref.read(customerRepositoryProvider);

    try {
      final List<Customer> found;
      if (_phoneLike.hasMatch(query)) {
        // Digits mean a phone number — the way a returning customer is
        // identified at the counter — and resolve to exactly one record.
        final match = await repository.byPhone(query);
        found = match == null ? const [] : [match];
      } else {
        final page = await repository.search(query: query, size: 20);
        found = page.content;
      }
      // A slower earlier request must not overwrite a newer result.
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _results = found;
        _searching = false;
        _error = null;
      });
    } on AppException catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _searching = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    if (selected != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Text(
            selected.fullName.isEmpty
                ? '?'
                : selected.fullName.substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(selected.fullName),
        subtitle: Text(
          [
            selected.customerCode,
            if (selected.phone != null) selected.phone!,
          ].join(' · '),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Change customer',
          onPressed: () => widget.onSelected(null),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller,
          hint: 'Customer name or phone',
          prefixIcon: Icons.person_search_outlined,
          autofocus: widget.autofocus,
          autocorrect: false,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
        ),
        if (_searching) ...[
          AppSpacing.gapMd,
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_error != null) ...[
          AppSpacing.gapSm,
          Text(
            _error!,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.danger,
            ),
          ),
        ],
        if (!_searching &&
            _error == null &&
            _results.isEmpty &&
            _controller.text.trim().length >= 2) ...[
          AppSpacing.gapSm,
          Text(
            'No customer matches. Register them under Customers first.',
            style: context.text.bodySmall?.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_results.isNotEmpty) ...[
          AppSpacing.gapSm,
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final customer = _results[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(customer.fullName),
                  subtitle: Text(
                    [
                      customer.customerCode,
                      if (customer.phone != null) customer.phone!,
                    ].join(' · '),
                  ),
                  onTap: () => widget.onSelected(customer),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
