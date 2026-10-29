import 'package:flutter/material.dart';

import '../call/call_controller.dart';
import '../util/digit_normalizer.dart';

/// Dialer (F02): status line + 3-digit target + single-call button.
/// Repeated taps while a call is pending never create a second INVITE (T09).
class DialerPage extends StatefulWidget {
  final CallController controller;
  final VoidCallback onStartCall;

  const DialerPage({
    super.key,
    required this.controller,
    required this.onStartCall,
  });

  @override
  State<DialerPage> createState() => _DialerPageState();
}

class _DialerPageState extends State<DialerPage> {
  final _targetCtrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _statusText() {
    switch (widget.controller.state) {
      case AppCallState.idle:
        return widget.controller.micReady ? 'آماده' : 'در حال ثبت SIP…';
      case AppCallState.outgoingPending:
        return 'در حال تماس با داخلی ${widget.controller.remoteExtension}…';
      case AppCallState.incomingPending:
        return 'تماس ورودی از داخلی ${widget.controller.remoteExtension}';
      case AppCallState.connecting:
        return 'در حال اتصال…';
      case AppCallState.connected:
        return 'متصل';
      case AppCallState.ending:
        return 'در حال پایان…';
      case AppCallState.signingIn:
        return 'در حال ورود…';
      case AppCallState.error:
        return widget.controller.errorMessage ?? 'خطا';
      case AppCallState.unconfigured:
        return 'تنظیم نشده';
    }
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.controller.state == AppCallState.idle;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mini VoIP Free')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    idle && widget.controller.micReady ? Icons.check_circle : Icons.info_outline,
                    color: idle && widget.controller.micReady ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusText())),
                ],
              ),
              if (widget.controller.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(widget.controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              TextField(
                controller: _targetCtrl,
                focusNode: _focus,
                enabled: idle,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 3,
                style: const TextStyle(fontSize: 40, letterSpacing: 8),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '۱۰۲',
                  labelText: 'شماره داخلی مقصد',
                ),
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: idle ? _start : null,
                icon: const Icon(Icons.call),
                label: const Text('تماس'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    final n = DigitNormalizer.normalizeInternal(_targetCtrl.text);
    if (n == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('۳ رقم در بازه ۱۰۱ تا ۱۹۹ وارد کنید')),
      );
      return;
    }
    final started = await widget.controller.placeCall(n);
    if (started && mounted) widget.onStartCall();
  }
}
