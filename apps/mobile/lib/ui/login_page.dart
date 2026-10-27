import 'package:flutter/material.dart';

import '../call/call_controller.dart';
import '../secure/secure_credential_store.dart';
import '../util/digit_normalizer.dart';

/// Onboarding/login (F01): domain + extension + password.
/// Order follows spec 10.1: validate → login → secure save → permissions/push → SIP.
class LoginPage extends StatefulWidget {
  final CallController controller;
  final SecureCredentialStore store;
  final VoidCallback onSignedIn;

  const LoginPage({
    super.key,
    required this.controller,
    required this.store,
    required this.onSignedIn,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _domainFocus = FocusNode();
  final _domainCtrl = TextEditingController();
  final _extCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _domainFocus.requestFocus());
  }

  @override
  void dispose() {
    _domainFocus.dispose();
    _domainCtrl.dispose();
    _extCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await widget.controller.signIn(
      domain: _domainCtrl.text.trim().toLowerCase(),
      extension: _extCtrl.text,
      password: _passCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.controller.errorMessage;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mini VoIP Free — ورود')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _domainCtrl,
                    focusNode: _domainFocus,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    decoration: const InputDecoration(
                        labelText: 'دامنه سرور', hintText: 'phone.example.com'),
                    validator: (v) {
                      final s = v?.trim().toLowerCase() ?? '';
                      if (s.isEmpty) return 'دامنه را وارد کنید';
                      // hostname only — no scheme, no path, no userinfo (spec 10.1)
                      if (s.contains('/') || s.contains(':') || s.contains('@') ||
                          s.contains(' ')) {
                        return 'فقط نام دامنه، بدون http و مسیر';
                      }
                      if (!s.contains('.')) return 'دامنه معتبر نیست';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _extCtrl,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'شماره داخلی (مثلاً ۱۰۲)'),
                    validator: (v) {
                      final n = DigitNormalizer.normalizeInternal(v);
                      if (n == null) return '۳ رقم در بازه ۱۰۱ تا ۱۹۹';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'رمز داخلی'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'رمز را وارد کنید' : null,
                  ),
                  const SizedBox(height: 20),
                  if (error != null) ...[
                    Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('ورود'),
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
