import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/routing/workspace_navigation.dart';
import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/widgets/page_content.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../core/storage/backup_service.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../domain/payment_settings.dart';
import 'payment_settings_controller.dart';
import 'settings_image_helper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    final theme = Theme.of(context);
    return PageContent(
      children: [
        const Eyebrow('Make it yours'),
        const SizedBox(height: 12),
        Text('Settings', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        const DetailHint(
          'Business records stay on this device. Use Business backup to export a portable copy before changing phones or clearing app data.',
        ),
        const SizedBox(height: 16),
        const _BackupExport(),
        const SizedBox(height: 32),
        const Eyebrow('Notifications'),
        const SizedBox(height: 8),
        const _NotificationSettings(),
        const SizedBox(height: 24),
        const Eyebrow('Appearance'),
        const SizedBox(height: 12),
        for (final entry in [
          (
            ThemeMode.system,
            'Use device setting',
            Icons.brightness_auto_outlined,
          ),
          (ThemeMode.light, 'Light', Icons.light_mode_outlined),
          (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
        ])
          ListTile(
            leading: Icon(entry.$3, size: 22),
            title: Text(entry.$2),
            trailing: Icon(
              mode == entry.$1
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: mode == entry.$1
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            selected: mode == entry.$1,
            onTap: () async {
              try {
                await ref
                    .read(themeControllerProvider.notifier)
                    .select(entry.$1);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Your appearance setting could not be saved. Please try again.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        const SizedBox(height: 24),
        _UpiSettingsForm(key: ValueKey(ref.watch(inventoryUidProvider))),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Bill appearance'),
          subtitle: const Text(
            'Business name, logo, signature and bill layout',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () =>
              openWorkspacePage(GoRouter.of(context), '/bill-settings'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 28),
        const Eyebrow('Account'),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Your profile'),
          subtitle: const Text('Account information and sign-out'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openWorkspacePage(GoRouter.of(context), '/profile'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 28),
        const Eyebrow('About'),
        const SizedBox(height: 16),
        Text('Hyner', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Version 0.6.0 · Business workspace and QuickPrice',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Manual backup is available. Automatic multi-device sync remains a separate cloud service.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class BillAppearanceScreen extends ConsumerWidget {
  const BillAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageContent(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Back'),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Bill appearance',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      _BillSettingsForm(key: ValueKey(ref.watch(inventoryUidProvider))),
    ],
  );
}

class _BackupExport extends ConsumerStatefulWidget {
  const _BackupExport();

  @override
  ConsumerState<_BackupExport> createState() => _BackupExportState();
}

class _BackupExportState extends ConsumerState<_BackupExport> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await BackupService.exportAndShare(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup is ready to save or share.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup could not be created.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Eyebrow('Business backup'),
      const SizedBox(height: 8),
      const Text(
        'Export products, stock history, customers, sales, purchases, returns, expenses and settings as a portable backup file.',
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy ? null : _export,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_download_outlined),
        label: Text(_busy ? 'Preparing backup…' : 'Export business backup'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _restore,
        icon: const Icon(Icons.file_upload_outlined),
        label: const Text('Restore business backup'),
      ),
    ],
  );

  Future<void> _restore() async {
    if (_busy) return;
    final uid = ref.read(inventoryUidProvider);
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore business backup?'),
        content: const Text(
          'This replaces the current local business records on this device. Export a fresh backup first if you need to keep them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final restored = await BackupService.pickAndRestore(uid);
      if (mounted && restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Backup restored. Reopen Hyner to refresh all screens.',
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup could not be restored.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _NotificationSettings extends ConsumerStatefulWidget {
  const _NotificationSettings();

  @override
  ConsumerState<_NotificationSettings> createState() =>
      _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<_NotificationSettings>
    with WidgetsBindingObserver {
  bool? _enabled;
  bool _busy = false;
  bool _permissionAsked = false;
  bool _scannedLowStock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await LocalNotificationService.instance.isEnabled();
    if (mounted) setState(() => _enabled = enabled);
    if (enabled && !_scannedLowStock && mounted) {
      _scannedLowStock = true;
      await ref.read(inventoryProvider.notifier).checkAllLowStock();
    }
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (_permissionAsked) {
      await LocalNotificationService.instance.openSettings();
    } else {
      final enabled = await LocalNotificationService.instance
          .requestPermission();
      _permissionAsked = true;
      if (enabled && mounted) {
        await ref.read(inventoryProvider.notifier).checkAllLowStock();
      }
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.notifications_active_outlined),
    title: const Text('Low stock and activity alerts'),
    subtitle: Text(
      _enabled == true
          ? 'Enabled. Alerts appear when you leave Hyner.'
          : 'Allow alerts for low stock, sales, purchases, and payments.',
    ),
    trailing: _enabled == null || _busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : _enabled == true
        ? const Icon(Icons.check_circle_outline_rounded)
        : TextButton(
            onPressed: _enable,
            child: Text(_permissionAsked ? 'Open settings' : 'Enable'),
          ),
  );
}

class _UpiSettingsForm extends ConsumerStatefulWidget {
  const _UpiSettingsForm({super.key});
  @override
  ConsumerState<_UpiSettingsForm> createState() => _UpiSettingsFormState();
}

class _UpiSettingsFormState extends ConsumerState<_UpiSettingsForm> {
  final _upi = TextEditingController();
  late final String? _uid;
  bool _loading = true, _saving = false;
  bool _loaded = false;
  String? _error;

  bool get _currentAccount =>
      mounted && _uid != null && ref.read(inventoryUidProvider) == _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(inventoryUidProvider);
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_currentAccount) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ref
          .read(dependenciesProvider)
          .paymentSettings
          .read(_uid!);
      if (!_currentAccount) return;
      _upi.text = settings.upiId;
      setState(() {
        _loading = false;
        _loaded = true;
      });
    } catch (_) {
      if (_currentAccount) {
        setState(() {
          _loading = false;
          _error = 'UPI settings could not be loaded.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_currentAccount || !_loaded || _loading || _saving) return;
    final uid = _uid!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(dependenciesProvider).paymentSettings;
      final current = await repository.read(uid);
      if (!_currentAccount) return;
      await repository.save(
        uid,
        PaymentSettings(
          upiId: _upi.text,
          merchantName: current.merchantName,
          businessPhone: current.businessPhone,
          businessAddress: current.businessAddress,
          taxId: current.taxId,
          billLayout: current.billLayout,
          logoBase64: current.logoBase64,
          signatureBase64: current.signatureBase64,
          headerFontSize: current.headerFontSize,
          footerText: current.footerText,
          fontColors: current.fontColors,
        ),
      );
      if (!mounted || !_currentAccount) return;
      ref.invalidate(paymentSettingsProvider);
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI QR details saved on this device.')),
      );
    } on FormatException catch (error) {
      if (_currentAccount) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (_currentAccount) {
        setState(() {
          _saving = false;
          _error = 'UPI details could not be saved.';
        });
      }
    }
  }

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Eyebrow('UPI payment QR'),
      const SizedBox(height: 8),
      const DetailHint(
        'Hyner creates a QR with the bill’s exact INR amount. The customer pays through their own UPI app; you check the payment and mark the bill paid. Hyner does not process or verify payments.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _upi,
        enabled: _currentAccount && _loaded && !_loading && !_saving,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Your UPI ID',
          hintText: 'shop@bank',
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () =>
            openWorkspacePage(GoRouter.of(context), '/bill-settings'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit business name in Bill appearance'),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        InlineNotice(_error!, isError: true),
        if (!_loaded && !_loading)
          TextButton(onPressed: _load, child: const Text('Retry loading')),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: !_currentAccount || !_loaded || _loading || _saving
            ? null
            : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _loading
              ? 'Loading…'
              : _saving
              ? 'Saving…'
              : 'Save UPI details',
        ),
      ),
    ],
  );
}

class _BillSettingsForm extends ConsumerStatefulWidget {
  const _BillSettingsForm({super.key});
  @override
  ConsumerState<_BillSettingsForm> createState() => _BillSettingsFormState();
}

class _BillSettingsFormState extends ConsumerState<_BillSettingsForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _taxId = TextEditingController();
  final _footer = TextEditingController();
  BillLayout _layout = BillLayout.right;
  double _fontSize = 20;
  final _fontColors = <BillTextSection, int>{};
  final _invalidColors = <BillTextSection>{};
  final _colorFields = {
    for (final section in BillTextSection.values)
      section: TextEditingController(),
  };
  String _logoBase64 = '', _signatureBase64 = '';
  bool _loading = true, _saving = false;
  bool _loaded = false, _picking = false;
  late final String? _uid;
  String? _error;

  bool get _currentAccount =>
      mounted && _uid != null && ref.read(inventoryUidProvider) == _uid;

  bool get _editable =>
      _currentAccount && _loaded && !_loading && !_saving && !_picking;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(inventoryUidProvider);
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_currentAccount) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ref
          .read(dependenciesProvider)
          .paymentSettings
          .read(_uid!);
      if (!_currentAccount) return;
      _name.text = settings.merchantName;
      _phone.text = settings.businessPhone;
      _address.text = settings.businessAddress;
      _taxId.text = settings.taxId;
      _footer.text = settings.footerText;
      setState(() {
        _fontColors.clear();
        _invalidColors.clear();
        for (final section in BillTextSection.values) {
          _fontColors[section] = settings.fontColor(section);
          _colorFields[section]!.text =
              '#${settings.fontColor(section).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        }
        _layout = settings.billLayout;
        _fontSize = settings.headerFontSize.isFinite
            ? settings.headerFontSize.clamp(14.0, 32.0)
            : 20;
        _logoBase64 = settings.logoBase64;
        _signatureBase64 = settings.signatureBase64;
        _loading = false;
        _loaded = true;
      });
    } catch (_) {
      if (_currentAccount) {
        setState(() {
          _loading = false;
          _error = 'Bill settings could not be loaded.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_editable) return;
    if (_invalidColors.isNotEmpty) {
      setState(() => _error = 'Check the highlighted font colours.');
      return;
    }
    final uid = _uid!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(dependenciesProvider).paymentSettings;
      final current = await repository.read(uid);
      if (!_currentAccount) return;
      await repository.save(
        uid,
        PaymentSettings(
          upiId: current.upiId,
          merchantName: _name.text,
          businessPhone: _phone.text,
          businessAddress: _address.text,
          taxId: _taxId.text,
          billLayout: _layout,
          footerText: _footer.text,
          headerFontSize: _fontSize,
          fontColors: Map.of(_fontColors),
          logoBase64: _logoBase64,
          signatureBase64: _signatureBase64,
        ),
      );
      if (mounted && _currentAccount) {
        ref.invalidate(paymentSettingsProvider);
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill details saved on this device.')),
        );
      }
    } on FormatException catch (error) {
      if (_currentAccount) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (_currentAccount) {
        setState(() {
          _saving = false;
          _error = 'Bill details could not be saved.';
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _taxId.dispose();
    _footer.dispose();
    for (final field in _colorFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage({required bool signature}) async {
    if (!_editable) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
        allowMultiple: false,
      );
      if (!_currentAccount || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size > maxSettingsImageBytes) {
        throw const FormatException('Choose an image no larger than 8 MB.');
      }
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException(
          'This image cannot be read. Try another image.',
        );
      }
      final prepared = await prepareSettingsImage(bytes);
      if (!_currentAccount) return;
      setState(() {
        final encoded = base64Encode(prepared);
        if (signature) {
          _signatureBase64 = encoded;
        } else {
          _logoBase64 = encoded;
        }
      });
    } on FormatException catch (error) {
      if (_currentAccount) setState(() => _error = error.message);
    } catch (_) {
      if (_currentAccount) {
        setState(() => _error = 'The image picker could not open. Try again.');
      }
    } finally {
      if (_currentAccount) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Eyebrow('Printed and shared bills'),
      const SizedBox(height: 8),
      const DetailHint(
        'Only the Original is shared with customers, including on WhatsApp. A compact Duplicate is kept locally for your records.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _name,
        enabled: _editable,
        maxLength: 80,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Business name',
          helperText: 'Shown on bills and in UPI payment details.',
          helperMaxLines: 3,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        enabled: _editable,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Business phone'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _address,
        enabled: _editable,
        maxLength: 240,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Business address'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _taxId,
        enabled: _editable,
        maxLength: 40,
        decoration: const InputDecoration(
          labelText: 'Tax ID / GSTIN (optional)',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _footer,
        enabled: _editable,
        maxLength: 160,
        decoration: const InputDecoration(labelText: 'Footer message'),
      ),
      const SizedBox(height: 8),
      Text('Bill font colours', style: Theme.of(context).textTheme.titleMedium),
      const DetailHint(
        'Choose a colour for each section using a hex code: #000000 for black, #C62828 for red, #1565C0 for blue. Colours appear in shared PDFs, including WhatsApp.',
        title: 'Font colours',
      ),
      for (final section in BillTextSection.values) ...[
        TextFormField(
          key: ValueKey((_loaded, section)),
          controller: _colorFields[section],
          enabled: _editable,
          maxLength: 7,
          decoration: InputDecoration(
            labelText: '${section.label} colour',
            suffixIcon: PopupMenuButton<int>(
              tooltip: 'Choose ${section.label} colour',
              enabled: _editable,
              icon: const Icon(Icons.palette_outlined),
              itemBuilder: (_) => [
                for (final entry in const {
                  0x000000: 'Black',
                  0xc62828: 'Red',
                  0x1565c0: 'Blue',
                  0x2e7d32: 'Green',
                  0x6a1b9a: 'Purple',
                  0x64707d: 'Grey',
                }.entries)
                  PopupMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: Color(0xff000000 | entry.key),
                        ),
                        const SizedBox(width: 12),
                        Text(entry.value),
                      ],
                    ),
                  ),
              ],
              onSelected: (color) => setState(() {
                _fontColors[section] = color;
                _invalidColors.remove(section);
                _colorFields[section]!.text =
                    '#${color.toRadixString(16).padLeft(6, '0').toUpperCase()}';
              }),
            ),
            hintText: '#C62828',
            counterText: '',
            prefixIcon: Icon(
              Icons.circle,
              color: Color(0xff000000 | (_fontColors[section] ?? 0x19212b)),
            ),
            errorText: _invalidColors.contains(section)
                ? 'Use # followed by six hex digits.'
                : null,
          ),
          onChanged: (text) => setState(() {
            final valid = RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(text.trim());
            if (valid) {
              _invalidColors.remove(section);
              _fontColors[section] = int.parse(
                text.trim().replaceFirst('#', ''),
                radix: 16,
              );
            } else {
              _invalidColors.add(section);
            }
          }),
        ),
        const SizedBox(height: 14),
      ],
      Text('Header title size: ${_fontSize.round()}'),
      Slider(
        value: _fontSize,
        min: 14,
        max: 32,
        divisions: 18,
        label: '${_fontSize.round()}',
        onChanged: !_editable
            ? null
            : (value) => setState(() => _fontSize = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<BillLayout>(
        key: ValueKey((_loading, _layout)),
        isExpanded: true,
        initialValue: _layout,
        decoration: const InputDecoration(labelText: 'Bill header layout'),
        selectedItemBuilder: (context) => const [
          Text('Right aligned', maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Centered', maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        items: const [
          DropdownMenuItem(
            value: BillLayout.right,
            child: Text('Business details on the right'),
          ),
          DropdownMenuItem(
            value: BillLayout.centered,
            child: Text('Business details in the center'),
          ),
        ],
        onChanged: !_editable
            ? null
            : (value) {
                if (value != null) setState(() => _layout = value);
              },
      ),
      const SizedBox(height: 12),
      const Text(
        'PNG, JPEG or WebP, up to 8 MB. Images are resized for bills.',
      ),
      const SizedBox(height: 12),
      if (_logoBase64.isNotEmpty) ...[
        _SettingsImagePreview(label: 'Shop logo', encoded: _logoBase64),
        const SizedBox(height: 12),
      ],
      if (_signatureBase64.isNotEmpty) ...[
        _SettingsImagePreview(label: 'Signature', encoded: _signatureBase64),
        const SizedBox(height: 12),
      ],
      if (_picking) ...[
        const LinearProgressIndicator(semanticsLabel: 'Preparing bill image'),
        const SizedBox(height: 12),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: !_editable ? null : () => _pickImage(signature: false),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_logoBase64.isEmpty ? 'Add shop logo' : 'Replace logo'),
          ),
          OutlinedButton.icon(
            onPressed: !_editable ? null : () => _pickImage(signature: true),
            icon: const Icon(Icons.draw_outlined),
            label: Text(
              _signatureBase64.isEmpty ? 'Add signature' : 'Replace signature',
            ),
          ),
          if (_logoBase64.isNotEmpty)
            TextButton(
              onPressed: !_editable
                  ? null
                  : () => setState(() => _logoBase64 = ''),
              child: const Text('Remove logo'),
            ),
          if (_signatureBase64.isNotEmpty)
            TextButton(
              onPressed: !_editable
                  ? null
                  : () => setState(() => _signatureBase64 = ''),
              child: const Text('Remove signature'),
            ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        InlineNotice(_error!, isError: true),
        if (!_loaded && !_loading)
          TextButton(onPressed: _load, child: const Text('Retry loading')),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _editable ? _save : null,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          _loading
              ? 'Loading…'
              : _saving
              ? 'Saving…'
              : 'Save bill details',
        ),
      ),
    ],
  );
}

class _SettingsImagePreview extends StatelessWidget {
  const _SettingsImagePreview({required this.label, required this.encoded});

  final String label;
  final String encoded;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      // Bound legacy/corrupt stored data before decoding it for a preview.
      if (encoded.length <= (maxSavedSettingsImageBytes + 2) ~/ 3 * 4) {
        bytes = base64Decode(encoded);
      }
    } on FormatException {
      // Keep the remove/replace controls usable for invalid saved images.
    }
    final unavailable = Text(
      '$label preview unavailable. Replace or remove it.',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 144,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: bytes == null || bytes.isEmpty
              ? DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.black87),
                  child: unavailable,
                )
              : Image(
                  image: ResizeImage(
                    MemoryImage(bytes),
                    width: 512,
                    height: 240,
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.contain,
                  semanticLabel: '$label preview',
                  errorBuilder: (context, error, stackTrace) =>
                      DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.black87),
                        child: unavailable,
                      ),
                ),
        ),
      ],
    );
  }
}
