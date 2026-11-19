import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/page_content.dart';
import '../../auth/data/device_access_repository.dart';
import '../../auth/data/account_deletion_service.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../pricing/application/pricing_workspace_provider.dart';
import '../../pricing/data/device_workspace.dart';
import '../../../main.dart' show HynerLauncher;

const supportEmail = String.fromEnvironment('HYNER_SUPPORT_EMAIL');
const privacyUrl = String.fromEnvironment('HYNER_PRIVACY_URL');
const deletionUrl = String.fromEnvironment('HYNER_DELETION_URL');

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});
  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool busy = false;
  String? error;
  Future<void> _delete() async {
    final uid = ref.read(inventoryUidProvider);
    if (uid == null || uid == deviceOwnerUid || busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete your Hyner account and data?'),
        content: const SingleChildScrollView(
          child: Text(
            'This permanently deletes your sign-in account, any legacy account data stored by Hyner in Firebase, and this account’s business records and calculators on this device. Other devices and copies you exported or shared must be cleared separately. Save a complete backup first if you need to retain business records. This cannot be undone. You may need to sign in again before deleting.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account and data'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        ref.read(inventoryUidProvider) != uid) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final navigator = Navigator.of(context, rootNavigator: true);
    final restart = HynerLauncher.restartAction(context);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Deleting your account. Keep Hyner open.')),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(progress));
    try {
      final workspace = await ref.read(pricingWorkspaceProvider(uid).future);
      if (!mounted || ref.read(inventoryUidProvider) != uid) return;
      final values = workspace.values;
      if (values is! DeviceWorkspaceValues) {
        throw StateError(
          'Open this account on Android to manage its local data.',
        );
      }
      await AccountDeletionService.delete(
        uid,
        closePricing: workspace.close,
        isCurrent: () => mounted && ref.read(inventoryUidProvider) == uid,
      );
      restart?.call();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (navigator.mounted && progress.isActive) {
        navigator.removeRoute(progress);
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _link(String title, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: SelectableText(value),
    onTap: () async {
      final url = title == 'Support' ? 'mailto:$value' : value;
      try {
        await const MethodChannel('hyner/external')
            .invokeMethod<void>('open', {'url': url});
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Link copied. Open it in your browser or email app.',
              ),
            ),
          );
        }
      }
    },
    trailing: IconButton(
      tooltip: 'Copy',
      onPressed: () => Clipboard.setData(ClipboardData(text: value)),
      icon: const Icon(Icons.copy_outlined),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(inventoryUidProvider);
    return PopScope(
      canPop: !busy,
      child: PageContent(
        children: [
          Text(
            'Privacy and account data',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const Text('Your shop records'),
          const SizedBox(height: 6),
          const Text(
            'Products, customers, bills, payment records, calculators and business settings are stored on this device. Signing in does not automatically back up or synchronize these records.',
          ),
          const SizedBox(height: 16),
          const Text('Account services'),
          const SizedBox(height: 6),
          const Text(
            'Google or email sign-in uses Firebase Authentication. Google sign-in shares the account information needed to sign in. Older versions may also have saved profile and inventory data under your account in Firebase. Device-only mode does not require an online account.',
          ),
          const SizedBox(height: 16),
          const Text('Photos, PDFs and backups'),
          const SizedBox(height: 6),
          const Text(
            'Selected logos and signatures are saved with your business settings; profile images are saved locally. PDF sharing and backups include the business and customer information you choose to export. Complete backups include both local databases, settings and required profile images, but exclude passwords and authentication tokens. Exported backups are readable files. Keep them private.',
          ),
          const SizedBox(height: 16),
          const Text('Payments and messages'),
          const SizedBox(height: 6),
          const Text(
            'Hyner records payments you confirm. It does not process or automatically verify UPI payments. WhatsApp opens a draft or attachment for you to send. Marketing consent is optional and can be withdrawn in the customer record.',
          ),
          const SizedBox(height: 16),
          const Text('Deletion'),
          const SizedBox(height: 6),
          const Text(
            'Account deletion removes the account and its Hyner-managed legacy cloud records, then clears its local records on this installation. Exported files, shared PDFs, records on other devices and data held by recipient apps are outside this deletion. Keep any records you need before proceeding.',
          ),
          if (privacyUrl.isNotEmpty)
            _link('Published privacy policy', privacyUrl),
          if (deletionUrl.isNotEmpty)
            _link('Request deletion outside the app', deletionUrl),
          if (supportEmail.isNotEmpty) _link('Support', supportEmail),
          if (error != null) InlineNotice(error!, isError: true),
          if (busy) const LinearProgressIndicator(),
          if (uid != null && uid != deviceOwnerUid)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: FilledButton.tonal(
                onPressed: busy ? null : _delete,
                child: const Text('Delete account and data'),
              ),
            ),
          if (uid == deviceOwnerUid)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'You are using this device without an online account. There is no sign-in account to delete. Android’s Clear storage action erases this installation’s local records; save a complete backup first if needed.',
              ),
            ),
        ],
      ),
    );
  }
}
