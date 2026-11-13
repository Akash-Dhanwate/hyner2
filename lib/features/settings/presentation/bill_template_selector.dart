import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/account_scope_guard.dart';
import '../../sales/data/bill_pdf_service.dart';
import '../../sales/domain/sale.dart';
import '../domain/payment_settings.dart';

Sale billPreviewSale() => Sale(
  id: 'PREVIEW',
  createdAt: DateTime(2026, 11, 12, 10, 30),
  draft: SaleDraft(
    currency: 'INR',
    customerId: 'preview-customer',
    customerName: 'Sample customer',
    customerPhone: '9876543210',
    customerAddress: 'Customer address',
    initialPaymentMinor: 0,
    lines: [
      SaleLine(
        sku: 'SAMPLE',
        name: 'Flush door',
        quantity: 2,
        unitPriceMinor: 16500,
      ),
    ],
  ),
);

PaymentSettings settingsWithLayout(
  PaymentSettings settings,
  BillLayout layout,
) => PaymentSettings(
  upiId: settings.upiId,
  merchantName: settings.merchantName,
  businessPhone: settings.businessPhone,
  businessAddress: settings.businessAddress,
  taxId: settings.taxId,
  billLayout: layout,
  logoBase64: settings.logoBase64,
  signatureBase64: settings.signatureBase64,
  headerFontSize: settings.headerFontSize,
  footerText: settings.footerText,
  fontColors: settings.fontColors,
);

class BillTemplateSelector extends StatefulWidget {
  const BillTemplateSelector({
    super.key,
    required this.settings,
    required this.enabled,
    required this.onChanged,
    required this.uid,
  });
  final PaymentSettings settings;
  final bool enabled;
  final String? uid;
  final ValueChanged<BillLayout> onChanged;
  @override
  State<BillTemplateSelector> createState() => _BillTemplateSelectorState();
}

class _BillTemplateSelectorState extends State<BillTemplateSelector> {
  int _generation = 0;
  final _timeouts = <Timer, Completer<bool>>{};
  Future<bool>? _rasterAvailable;
  final _thumbnails = <BillLayout, Uint8List>{};
  bool _previewing = false;
  Object _visualKey(PaymentSettings s) => (
    s.merchantName,
    s.businessAddress,
    s.businessPhone,
    s.taxId,
    s.logoBase64,
    s.signatureBase64,
    s.headerFontSize,
    s.footerText,
    s.fontColors.toString(),
  );
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(BillTemplateSelector old) {
    super.didUpdateWidget(old);
    if (_visualKey(old.settings) != _visualKey(widget.settings) ||
        (!old.enabled && widget.enabled)) {
      _schedule();
    }
  }

  void _schedule() {
    final generation = ++_generation;
    if (!widget.enabled) return;
    scheduleMicrotask(() async {
      final settings = widget.settings;
      final cache = BillBrandingCache();
      try {
        if (!await (_rasterAvailable ??= Printing.info().then(
          (info) => info.canRaster,
        ))) {
          return;
        }
        for (final layout in BillLayout.values) {
          if (!mounted || generation != _generation) return;
          try {
            final bytes = await BillPdfService.build(
              sale: billPreviewSale(),
              settings: settingsWithLayout(settings, layout),
              brandingCache: cache,
            );
            if (!mounted || generation != _generation) return;
            final iterator = StreamIterator(
              Printing.raster(bytes, pages: [0], dpi: 32),
            );
            final timeout = Completer<bool>();
            final timer = Timer(
              const Duration(seconds: 15),
              () => timeout.complete(false),
            );
            _timeouts[timer] = timeout;
            Uint8List? thumbnail;
            try {
              if (await Future.any([iterator.moveNext(), timeout.future])) {
                thumbnail = await iterator.current.toPng();
              }
            } finally {
              timer.cancel();
              _timeouts.remove(timer);
              await iterator.cancel();
            }
            if (thumbnail == null) continue;
            if (mounted && generation == _generation) {
              setState(() => _thumbnails[layout] = thumbnail!);
            }
          } catch (_) {
            /* Schematic remains available on hosts without a rasterizer. */
          }
        }
      } finally {
        cache.clear();
      }
    });
  }

  Future<void> _preview() async {
    if (_previewing || !widget.enabled || widget.uid == null) return;
    setState(() => _previewing = true);
    final settings = widget.settings;
    final uid = widget.uid!;
    try {
      final bytes = await BillPdfService.build(
        sale: billPreviewSale(),
        settings: settings,
      );
      if (!mounted || !widget.enabled || widget.uid != uid) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AccountScopeGuard(
            uid: uid,
            child: Scaffold(
              appBar: AppBar(
                title: Text('${settings.billLayout.label} preview'),
              ),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The preview could not open. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    for (final entry in _timeouts.entries) {
      entry.key.cancel();
      if (!entry.value.isCompleted) entry.value.complete(false);
    }
    _timeouts.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('PDF style', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text('Used for bills and quotations.'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
          final width = largeText
              ? constraints.maxWidth
              : (constraints.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final layout in BillLayout.values)
                SizedBox(
                  width: width,
                  child: Semantics(
                    selected: widget.settings.billLayout == layout,
                    button: true,
                    label: '${layout.label} PDF style',
                    child: InkWell(
                      key: ValueKey('pdf-template-${layout.name}'),
                      onTap: widget.enabled
                          ? () => widget.onChanged(layout)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.settings.billLayout == layout
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: widget.settings.billLayout == layout ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: largeText ? 150 : width * 1.25,
                              child: _thumbnails[layout] != null
                                  ? Image.memory(
                                      _thumbnails[layout]!,
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true,
                                    )
                                  : CustomPaint(
                                      size: const Size(110, 155),
                                      painter: _TemplateOutline(layout),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(layout.label, textAlign: TextAlign.center),
                            Icon(
                              widget.settings.billLayout == layout
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        key: const Key('preview-bill-template'),
        onPressed: widget.enabled && !_previewing ? _preview : null,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: Text(_previewing ? 'Opening…' : 'Preview selected PDF'),
      ),
    ],
  );
}

class _TemplateOutline extends CustomPainter {
  _TemplateOutline(this.layout);
  final BillLayout layout;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paint = Paint()
      ..color = const Color(0xff55615b)
      ..strokeWidth = 1;
    final left = layout == BillLayout.right
        ? size.width * .45
        : size.width * .08;
    final right = layout == BillLayout.centered
        ? size.width * .8
        : size.width * .92;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(left, 10.0 + i * 5),
        Offset(right, 10.0 + i * 5),
        paint,
      );
    }
    if (layout != BillLayout.right) {
      canvas.drawLine(Offset(8, 31), Offset(size.width - 8, 31), paint);
    }
    canvas.drawRect(
      Rect.fromLTWH(8, 40, size.width - 16, 15),
      Paint()..color = const Color(0xffe9ecea),
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(8, 65.0 + i * 10),
        Offset(size.width - 8, 65.0 + i * 10),
        paint,
      );
    }
    if (layout == BillLayout.ledger) {
      for (var i = 1; i <= 3; i++) {
        canvas.drawLine(
          Offset(size.width * i / 4, 60),
          Offset(size.width * i / 4, 105),
          paint,
        );
      }
    }
    canvas.drawLine(
      Offset(size.width * .5, 120),
      Offset(size.width - 8, 120),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TemplateOutline old) => old.layout != layout;
}
