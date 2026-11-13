import '../../../core/widgets/document_action_button.dart';
import '../../../core/widgets/financial_amount.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/page_content.dart';
import '../../../core/widgets/account_scope_guard.dart';
import '../../customers/domain/customer.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../pricing/application/calculator_session.dart';
import '../../pricing/application/estimate_builder.dart';
import '../../pricing/presentation/workspace_quickprice_screen.dart';
import '../../auth/presentation/session_controller.dart';
import '../../sales/data/bill_pdf_actions.dart';
import '../../sales/data/bill_pdf_service.dart';
import '../../sales/domain/sale.dart';
import '../../settings/domain/payment_settings.dart';
import '../../settings/presentation/payment_settings_controller.dart';
import '../domain/quotation.dart';
import 'quotation_controller.dart';

class QuickPriceQuotationScreen extends ConsumerWidget {
  const QuickPriceQuotationScreen({super.key, required this.estimateId});
  final String estimateId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scope = profile.localOnly ? null : profile.uid;
    return ref
        .watch(pricingWorkspaceProvider(scope))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Quotation')),
            body: Center(
              child: TextButton(
                onPressed: () =>
                    ref.invalidate(pricingWorkspaceProvider(scope)),
                child: const Text('Retry calculator workspace'),
              ),
            ),
          ),
          data: (workspace) => _EstimateQuotationLoader(
            key: ValueKey((profile.uid, estimateId)),
            uid: profile.uid,
            estimateId: estimateId,
            load: () async {
              final estimate = await EstimateRepository(workspace).load();
              if (estimate.id != estimateId ||
                  estimate.lines.isEmpty ||
                  estimate.businessId != workspace.businessId) {
                throw StateError(
                  'Open the current estimate in QuickPrice to create a quotation.',
                );
              }
              return estimate.toCheckoutSeed(profile.uid).lines;
            },
          ),
        );
  }
}

class _EstimateQuotationLoader extends StatefulWidget {
  const _EstimateQuotationLoader({
    super.key,
    required this.uid,
    required this.estimateId,
    required this.load,
  });
  final String uid, estimateId;
  final Future<List<SaleLine>> Function() load;
  @override
  State<_EstimateQuotationLoader> createState() =>
      _EstimateQuotationLoaderState();
}

class _EstimateQuotationLoaderState extends State<_EstimateQuotationLoader> {
  late Future<List<SaleLine>> _future = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<List<SaleLine>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return QuotationEditor(uid: widget.uid, lines: snapshot.data!);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Quotation')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(pricingError(snapshot.error!)),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _future = widget.load()),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}

class QuotationEditor extends ConsumerStatefulWidget {
  const QuotationEditor({super.key, required this.uid, required this.lines});
  final String uid;
  final List<SaleLine> lines;
  @override
  ConsumerState<QuotationEditor> createState() => _QuotationEditorState();
}

class _QuotationEditorState extends ConsumerState<QuotationEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _address = TextEditingController();
  final _id = 'Q-${DateTime.now().toUtc().microsecondsSinceEpoch}';
  final _created = DateTime.now().toUtc();
  Quotation? _pending, _saved;
  bool _busy = false, _leaving = false;
  String? _error;
  bool get _current => mounted && ref.read(inventoryUidProvider) == widget.uid;
  bool get _dirty =>
      _name.text.isNotEmpty ||
      _phone.text.isNotEmpty ||
      _address.text.isNotEmpty;
  Future<void> _leave() async {
    if (_busy || _leaving) return;
    _leaving = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this quotation?'),
        content: const Text('The customer details have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (mounted && _current && leave == true) {
      setState(() => _leaving = true);
      Navigator.pop(context);
    } else {
      _leaving = false;
    }
  }

  Future<void> _generate() async {
    if (_busy || !_current || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final quote = _pending ??= Quotation(
        id: _id,
        createdAt: _created,
        draft: SaleDraft(
          currency: widget.lines.first.pricing?.currency ?? 'INR',
          lines: widget.lines,
          customerName: _name.text.trim(),
          customerPhone: _phone.text.trim(),
          customerAddress: _address.text.trim(),
          initialPaymentMinor: 0,
        ),
      );
      await ref.read(quotationRepositoryProvider).save(widget.uid, quote);
      if (!_current) return;
      ref.invalidate(quotationsProvider);
      setState(() => _saved = quote);
    } catch (e) {
      if (_current) setState(() => _error = pricingError(e));
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(inventoryUidProvider) != widget.uid) {
      return const Scaffold(
        body: Center(
          child: Text('Reopen QuickPrice in your current workspace.'),
        ),
      );
    }
    final saved = _saved;
    if (saved != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quotation')),
        body: QuotationDocument(quote: saved, uid: widget.uid),
      );
    }
    return PopScope(
      canPop: !_busy && (!_dirty || _leaving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Quotation')),
        body: PageContent(
          children: [
            Text(
              'For your customer',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.lines.length} items · ${formatMoney(widget.lines.fold(0, (sum, line) => sum + line.totalMinor), widget.lines.first.pricing?.currency ?? 'INR')}',
            ),
            const SizedBox(height: 20),
            Form(
              key: _form,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('quotation-customer-name'),
                    controller: _name,
                    enabled: !_busy && _pending == null,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Customer name',
                      counterText: '',
                    ),
                    validator: (v) => v?.trim().isNotEmpty == true
                        ? null
                        : 'Enter the customer name.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('quotation-customer-phone'),
                    controller: _phone,
                    enabled: !_busy && _pending == null,
                    maxLength: 40,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      counterText: '',
                    ),
                    validator: (v) => validCustomerMobile(v ?? '')
                        ? null
                        : 'Enter a valid mobile number.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('quotation-customer-address'),
                    controller: _address,
                    enabled: !_busy && _pending == null,
                    maxLength: 240,
                    maxLines: 3,
                    keyboardType: TextInputType.streetAddress,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) InlineNotice(_error!, isError: true),
                  FilledButton.icon(
                    key: const Key('generate-quotation'),
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _busy
                          ? 'Saving…'
                          : _pending == null
                          ? 'Generate quotation PDF'
                          : 'Retry saving quotation',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final line in widget.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(line.name),
                subtitle: Text('${line.quantity} units'),
                trailing: FinancialAmount(
                  formatMoney(
                    line.totalMinor,
                    widget.lines.first.pricing?.currency ?? 'INR',
                  ),
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SavedQuotationScreen extends ConsumerWidget {
  const SavedQuotationScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(inventoryUidProvider);
    if (uid == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Quotation')),
      body: _SavedQuotation(key: ValueKey((uid, id)), uid: uid, id: id),
    );
  }
}

class _SavedQuotation extends ConsumerStatefulWidget {
  const _SavedQuotation({super.key, required this.uid, required this.id});
  final String uid, id;
  @override
  ConsumerState<_SavedQuotation> createState() => _SavedQuotationState();
}

class _SavedQuotationState extends ConsumerState<_SavedQuotation> {
  late Future<Quotation> _future = ref
      .read(quotationRepositoryProvider)
      .get(widget.uid, widget.id);
  @override
  Widget build(BuildContext context) => FutureBuilder<Quotation>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return QuotationDocument(quote: snapshot.data!, uid: widget.uid);
      }
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(
              () => _future = ref
                  .read(quotationRepositoryProvider)
                  .get(widget.uid, widget.id),
            ),
            child: const Text('Could not open quotation. Retry'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    },
  );
}

class QuotationDocument extends ConsumerStatefulWidget {
  const QuotationDocument({super.key, required this.quote, required this.uid});
  final Quotation quote;
  final String uid;
  @override
  ConsumerState<QuotationDocument> createState() => _QuotationDocumentState();
}

class _QuotationDocumentState extends ConsumerState<QuotationDocument> {
  final _branding = BillBrandingCache();
  bool _busy = false;
  String? _error;
  PaymentSettings? _settings;
  Future<Uint8List>? _pdf;
  bool get _current => mounted && ref.read(inventoryUidProvider) == widget.uid;
  Future<Uint8List> _bytes(PaymentSettings settings) {
    if (!identical(_settings, settings)) {
      _settings = settings;
      _pdf = null;
    }
    return _pdf ??= BillPdfService.build(
      sale: widget.quote.document,
      settings: settings,
      quotation: true,
      brandingCache: _branding,
    );
  }

  Future<void> _action(String action, PaymentSettings settings) async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await _bytes(settings);
      if (!mounted || !_current) return;
      final name = 'hyner-quotation-${widget.quote.id}.pdf';
      if (action == 'save') {
        final saved = await BillPdfActions.save(bytes, name);
        if (mounted && _current && saved != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Quotation PDF saved.')));
        }
      } else if (action == 'copy') {
        await BillPdfActions.copyPdf(bytes, name);
        if (mounted && _current) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PDF copied. Paste into an app that accepts files.',
              ),
            ),
          );
        }
      } else if (action == 'whatsapp') {
        await BillPdfActions.shareWhatsApp(
          bytes,
          name,
          phone: widget.quote.draft.customerPhone,
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AccountScopeGuard(
              uid: widget.uid,
              child: Scaffold(
                appBar: AppBar(title: const Text('Quotation preview')),
                body: PdfPreview(
                  build: (_) async => bytes,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  allowSharing: false,
                  allowPrinting: false,
                ),
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (_current) {
        _pdf = null;
        setState(
          () => _error = 'The PDF action could not finish. Your quotation is saved; try again.',
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _branding.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(inventoryUidProvider) != widget.uid) {
      return const SizedBox.shrink();
    }
    final quote = widget.quote;
    return PageContent(
      children: [
        const Eyebrow('Quotation'),
        Text(
          quote.draft.customerName!,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(quote.draft.customerPhone!),
        if (quote.draft.customerAddress?.isNotEmpty == true)
          Text(quote.draft.customerAddress!),
        const SizedBox(height: 8),
        Text(saleDate(quote.createdAt)),
        Text('Reference: ${quote.id}'),
        const SizedBox(height: 20),
        Text('Total · ${quote.draft.units} units'),
        FinancialAmount(
          formatMoney(quote.draft.totalMinor, quote.draft.currency),
          style: Theme.of(context).textTheme.headlineMedium,
          prominent: true,
        ),
        const SizedBox(height: 16),
        ref
            .watch(paymentSettingsProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(paymentSettingsProvider),
                child: const Text('Retry business details'),
              ),
              data: (settings) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DocumentActionButton(
                    primary: true,
                    key: const Key('quotation-whatsapp'),
                    onPressed: _busy
                        ? null
                        : () => _action('whatsapp', settings),
                    icon: Icons.send_outlined,
                    label: 'WhatsApp PDF',
                  ),
                  DocumentActionButton(
                    key: const Key('quotation-download'),
                    onPressed: _busy ? null : () => _action('save', settings),
                    icon: Icons.download_outlined,
                    label: 'Download PDF',
                    filename: 'hyner-quotation-${quote.id}.pdf',
                  ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android)
                    DocumentActionButton(
                      key: const Key('quotation-copy'),
                      onPressed: _busy ? null : () => _action('copy', settings),
                      icon: Icons.copy_outlined,
                      label: 'Copy PDF',
                    ),
                  TextButton.icon(
                    key: const Key('quotation-preview'),
                    onPressed: _busy
                        ? null
                        : () => _action('preview', settings),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview PDF'),
                  ),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => context.push<void>('/bill-settings'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('PDF appearance'),
                  ),
                ],
              ),
            ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) InlineNotice(_error!, isError: true),
        const SizedBox(height: 20),
        for (final line in quote.draft.lines) ...[
          Text(line.name, style: Theme.of(context).textTheme.titleMedium),
          for (final p in line.parameters) Text('${p.name}: ${p.value}'),
          Text(
            '${line.quantity} × ${formatMoney(line.unitPriceMinor, quote.draft.currency)}',
          ),
          FinancialAmount(
            formatMoney(line.totalMinor, quote.draft.currency),
            compact: true,
          ),
          const Divider(),
        ],
      ],
    );
  }
}
