import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/app_dependencies.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/hyner_mark.dart';
import '../../../core/widgets/page_content.dart';
import 'session_controller.dart';
import '../domain/auth_repository.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final dependencies = ref.watch(dependenciesProvider);
    final signingIn = session.status == SessionStatus.signingIn;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to welcome',
          onPressed: () => context.go('/welcome'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: HynerMark(size: 64),
                ),
                const SizedBox(height: 32),
                Text('Welcome to Hyner', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Sign in to open your register. Products and bills are saved on this device.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('google-sign-in'),
                    onPressed:
                        signingIn ||
                            session.busy ||
                            !dependencies.config.isConfigured
                        ? null
                        : () => ref.read(sessionProvider.notifier).signIn(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (signingIn)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Image.asset(
                              'assets/branding/google-g.png',
                              width: 20,
                              height: 20,
                              excludeFromSemantics: true,
                            ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              signingIn
                                  ? 'Connecting…'
                                  : 'Continue with Google',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (dependencies.auth is DeviceAccess) ...[
                  OutlinedButton.icon(
                    onPressed: signingIn || session.busy
                        ? null
                        : () => ref.read(sessionProvider.notifier).useDevice(),
                    icon: const Icon(Icons.phone_android_outlined),
                    label: const Text('Use on this device'),
                  ),
                  const SizedBox(height: 20),
                ],
                const _EmailAccessForm(),
                const SizedBox(height: 20),
                if (dependencies.config.issue != null)
                  InlineNotice(dependencies.config.issue!),
                if (session.failure != null)
                  InlineNotice(
                    session.failure!.displayMessage,
                    isError: session.failure!.kind != FailureKind.cancelled,
                  ),
                if (dependencies.startupNotice != null) ...[
                  const SizedBox(height: 12),
                  InlineNotice(dependencies.startupNotice!),
                ],
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Google handles Google sign-in. Email/password access is secured by Firebase; Hyner does not see your password.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailAccessForm extends ConsumerStatefulWidget {
  const _EmailAccessForm();
  @override
  ConsumerState<_EmailAccessForm> createState() => _EmailAccessFormState();
}

class _EmailAccessFormState extends ConsumerState<_EmailAccessForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false, _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _message = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final controller = ref.read(sessionProvider.notifier);
    if (_create) {
      await controller.createAccountWithEmail(email, password);
    } else {
      await controller.signInWithEmail(email, password);
    }
    if (!mounted) return;
    final failure = ref.read(sessionProvider).failure;
    setState(() {
      _busy = false;
      _message = failure?.displayMessage;
    });
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(
        () => _message = 'Enter your email first, then choose reset password.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(sessionProvider.notifier).sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _busy = false;
          _message = 'Password reset email sent. Check your inbox.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = AppFailure.from(error).displayMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(dependenciesProvider).config.isConfigured;
    final session = ref.watch(sessionProvider);
    final disabled =
        _busy ||
        !configured ||
        session.busy ||
        session.status == SessionStatus.signingIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _create ? 'Create with email' : 'Sign in with email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: disabled
                    ? null
                    : () => setState(() {
                        _create = !_create;
                        _message = null;
                      }),
                child: Text(_create ? 'I have an account' : 'Create account'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          enabled: !disabled,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email address'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          enabled: !disabled,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: disabled ? null : _submit,
          child: Text(
            _busy
                ? 'Working…'
                : (_create ? 'Create account' : 'Sign in with email'),
          ),
        ),
        if (!_create)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: disabled ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class AccountSetupScreen extends ConsumerWidget {
  const AccountSetupScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionProvider);
    final failed = state.status == SessionStatus.profileError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const HynerMark(size: 68),
                  const SizedBox(height: 32),
                  Text(
                    failed
                        ? 'Let’s reconnect your account'
                        : 'Getting your workspace ready',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  if (failed)
                    InlineNotice(state.failure!.displayMessage, isError: true)
                  else ...[
                    const Text(
                      'Securely loading your account details.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    const CircularProgressIndicator(
                      semanticsLabel: 'Loading account profile',
                    ),
                  ],
                  if (failed) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state.busy
                            ? null
                            : () => ref
                                  .read(sessionProvider.notifier)
                                  .retryProfile(),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => ref.read(sessionProvider.notifier).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
