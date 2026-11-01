import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../call/call_controller.dart';
import '../util/digit_normalizer.dart';
import 'directory_page.dart';
import 'server_settings_page.dart';
import 'reception_setup_page.dart';

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
        return !widget.controller.micReady ? 'در حال ثبت SIP…' : widget.controller.backgroundReceptionReady ? (widget.controller.receptionWarning == null ? 'آماده' : 'تنظیمات دریافت نیازمند بررسی') : 'دریافت پس‌زمینه آماده نیست';
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
        appBar: AppBar(title: const Text('Mini VoIP Free'), actions:[
          IconButton(tooltip:'تنظیمات سرور',icon:const Icon(Icons.settings_outlined),onPressed:idle?()=>Navigator.of(context).push(MaterialPageRoute<bool>(builder:(_)=>ServerSettingsPage(controller:widget.controller))):null),
          if(defaultTargetPlatform==TargetPlatform.android) IconButton(tooltip:'تنظیمات اعلان و تماس قفل',icon:const Icon(Icons.notifications_outlined),onPressed:_openSetup),
          IconButton(tooltip:'فهرست داخلی‌ها',icon:const Icon(Icons.people_outline),
              onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>DirectoryPage(controller:widget.controller)))),
        ]),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    idle && widget.controller.micReady && widget.controller.backgroundReceptionReady && widget.controller.receptionWarning == null ? Icons.check_circle : Icons.info_outline,
                    color: idle && widget.controller.micReady && widget.controller.backgroundReceptionReady && widget.controller.receptionWarning == null ? Colors.green : Colors.orange,
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
              if (widget.controller.receptionWarning != null) ...[
                const SizedBox(height: 8),
                Text(widget.controller.receptionWarning!),
                TextButton(onPressed: _openSetup,
                    child: const Text('فعال‌کردن دریافت در پس‌زمینه')),
              ],
              if (defaultTargetPlatform == TargetPlatform.android && widget.controller.receptionWarning == null)
                TextButton(onPressed: _openSetup, child: const Text('راه‌اندازی تماس پس‌زمینه')),
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

  Future<void> _openSetup() async {
    _focus.unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceptionSetupPage(
      load: widget.controller.receptionCapabilities,
      open: widget.controller.openReceptionSetting,
      callChanges: widget.controller,
      callActive: () => const [AppCallState.incomingPending, AppCallState.outgoingPending,
          AppCallState.connecting, AppCallState.connected, AppCallState.ending].contains(widget.controller.state),
    )));
    await widget.controller.checkDirectReception();
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
