import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/images/image_editor_screen.dart';
import '../../../core/images/profile_photo_store.dart';
import '../../../core/widgets/account_scope_guard.dart';
import '../../settings/presentation/settings_image_helper.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/page_content.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contactEmail = TextEditingController();
  final _phone = TextEditingController();
  final _photoUrl = TextEditingController();
  Uint8List? _pendingPhoto;
  String? _pendingPhotoPath;
  bool _picking = false;
  bool _editing = false;
  bool _saving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _loadFields(ref.read(sessionProvider).profile);
  }

  void _loadFields(UserProfile? profile) {
    _name.text = profile?.displayName ?? '';
    _contactEmail.text = profile?.contactEmail ?? '';
    _phone.text = profile?.phone ?? '';
    _photoUrl.text = profile?.photoUrl ?? '';
    _pendingPhoto = null;
    _pendingPhotoPath = null;
  }

  @override
  void dispose() {
    _name.dispose();
    _contactEmail.dispose();
    _phone.dispose();
    _photoUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _picking || !_form.currentState!.validate()) return;
    final uid = ref.read(sessionProvider).profile?.uid;
    if (uid == null) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      if (_pendingPhoto != null) {
        _pendingPhotoPath ??= await storeProfilePhoto(uid, _pendingPhoto!);
        if (!mounted || ref.read(sessionProvider).profile?.uid != uid) return;
        _photoUrl.text = _pendingPhotoPath!;
      }
      await ref
          .read(sessionProvider.notifier)
          .updateProfile(
            ProfileDraft(
              displayName: _name.text,
              contactEmail: _contactEmail.text,
              phone: _phone.text,
              photoUrl: _photoUrl.text.trim().isEmpty ? null : _photoUrl.text,
            ),
          );
      if (!mounted || ref.read(sessionProvider).profile?.uid != uid) return;
      setState(() {
        _pendingPhoto = null;
        _pendingPhotoPath = null;
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = AppFailure.from(error);
      });
    }
  }

  Future<void> _pickPhoto({bool edit = false}) async {
    final uid = ref.read(sessionProvider).profile?.uid;
    if (uid == null || _saving || _picking) return;
    setState(() {
      _picking = true;
      _failure = null;
    });
    bool current() => mounted && ref.read(sessionProvider).profile?.uid == uid;
    try {
      Uint8List bytes;
      if (edit && _pendingPhoto != null) {
        bytes = _pendingPhoto!;
      } else if (edit && _photoUrl.text.isNotEmpty) {
        final url = _photoUrl.text;
        if (url.startsWith('/')) {
          bytes = await readProfilePhotoFile(url);
        } else {
          final data = await NetworkAssetBundle(Uri.parse(url)).load('');
          bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
          withData: true,
          allowMultiple: false,
        );
        if (!current() || result == null || result.files.isEmpty) return;
        final file = result.files.single;
        if (file.bytes == null || file.size > maxSettingsImageBytes) {
          throw const FormatException('Choose a readable photo up to 8 MB.');
        }
        bytes = file.bytes!;
      }
      if (!mounted || !current()) return;
      final edited = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => AccountScopeGuard(
            uid: uid,
            child: ImageEditorScreen(
              bytes: bytes,
              title: 'Edit profile photo',
              profile: true,
            ),
          ),
        ),
      );
      if (edited != null && current()) {
        setState(() {
          _pendingPhoto = edited;
          _pendingPhotoPath = null;
        });
      }
    } catch (_) {
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The photo could not be opened. Choose another image.',
            ),
          ),
        );
      }
    } finally {
      if (current()) setState(() => _picking = false);
    }
  }

  Future<void> _addPasswordLogin() async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add password login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This links email/password to this same workspace. You can use it if Google access is unavailable.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save password'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) {
        return;
      }
      if (password.text.length < 6 || password.text != confirm.text) {
        setState(
          () => _failure = const AppFailure(
            FailureKind.invalidData,
            'Passwords must match and contain at least 6 characters.',
          ),
        );
        return;
      }
      setState(() => _saving = true);
      await ref
          .read(sessionProvider.notifier)
          .linkEmailPassword(profileEmail, password.text);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password login added. Use your account email and password if Google is unavailable.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = AppFailure.from(error);
        });
      }
    } finally {
      password.dispose();
      confirm.dispose();
    }
  }

  String get profileEmail => ref.read(sessionProvider).profile?.email ?? '';

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((session) => session.profile?.uid), (
      previous,
      next,
    ) {
      if (previous != next) {
        _loadFields(ref.read(sessionProvider).profile);
        _editing = false;
        _saving = false;
        _picking = false;
        _failure = null;
      }
    });
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    if (profile == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final created = MaterialLocalizations.of(context)
        .formatFullDate(profile.createdAt.toLocal());
    return PageContent(
      children: [
        const Eyebrow('Your account'),
        const SizedBox(height: 12),
        Text('Profile', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              AccountAvatar(profile: profile, radius: 48),
              const SizedBox(height: 20),
              Text(
                profile.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              SelectableText(
                profile.contactEmail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (_failure != null) ...[
          InlineNotice(_failure!.displayMessage, isError: true),
          const SizedBox(height: 16),
        ],
        if (_editing) ...[
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactEmail,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 254,
                  decoration: InputDecoration(
                    labelText: profile.localOnly
                        ? 'Contact email (optional)'
                        : 'Contact email',
                    helperText: 'Used for business contact.',
                  ),
                  validator: (value) =>
                      !(profile.localOnly && (value?.trim().isEmpty ?? true)) &&
                          (value == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim()))
                      ? 'Enter a valid email address.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 12),
                if (_pendingPhoto != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label: 'New profile photo preview',
                        image: true,
                        child: ClipOval(
                          child: Image.memory(
                            _pendingPhoto!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_picking) const LinearProgressIndicator(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('choose-profile-photo'),
                      onPressed: _saving || _picking ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose profile photo'),
                    ),
                    if (_pendingPhoto != null || _photoUrl.text.isNotEmpty)
                      OutlinedButton.icon(
                        key: const Key('edit-profile-photo'),
                        onPressed: _saving || _picking
                            ? null
                            : () => _pickPhoto(edit: true),
                        icon: const Icon(Icons.crop_rotate),
                        label: const Text('Crop or rotate photo'),
                      ),
                    if (_pendingPhoto != null || _photoUrl.text.isNotEmpty)
                      TextButton(
                        onPressed: _saving || _picking
                            ? null
                            : () => setState(() {
                                _pendingPhoto = null;
                                _pendingPhotoPath = null;
                                _photoUrl.clear();
                              }),
                        child: const Text('Remove photo'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving || _picking ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
                TextButton(
                  onPressed: _saving || _picking
                      ? null
                      : () {
                          _loadFields(profile);
                          setState(() {
                            _editing = false;
                            _failure = null;
                          });
                        },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ] else ...[
          const Divider(),
          const SizedBox(height: 20),
          _DetailRow(
            'Full name',
            profile.displayName?.trim().isNotEmpty == true
                ? profile.displayName!.trim()
                : 'Not provided',
          ),
          _DetailRow('Contact email', profile.contactEmail),
          _DetailRow(
            'Phone number',
            profile.phone.trim().isEmpty ? 'Not provided' : profile.phone,
          ),
          if (!profile.localOnly) _DetailRow('Account email', profile.email),
          _DetailRow('Account created', created),
          _DetailRow(
            'Workspace',
            profile.localOnly
                ? 'On this device · no cloud sync'
                : 'Signed-in account · records on this device',
          ),
          const SizedBox(height: 8),
          if (!profile.localOnly)
            OutlinedButton.icon(
              onPressed: _saving ? null : _addPasswordLogin,
              icon: const Icon(Icons.password_outlined),
              label: const Text('Add password login'),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _loadFields(profile);
                setState(() {
                  _editing = true;
                  _failure = null;
                });
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        if (session.failure != null) ...[
          InlineNotice(session.failure!.displayMessage, isError: true),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: session.busy || _saving
                ? null
                : () => ref.read(sessionProvider.notifier).signOut(),
            icon: session.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: Text(session.busy ? 'Signing out…' : 'Sign out'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.localOnly
              ? 'Leaving does not erase your data. Choose Use on this device to open this workspace again.'
              : 'Signing out does not erase products or bills stored on this device. Sign back into the same account to open this workspace again.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
