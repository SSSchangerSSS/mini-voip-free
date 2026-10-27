import 'package:flutter/material.dart';

import 'call/call_controller.dart';
import 'native/native_call_bridge.dart';
import 'secure/secure_credential_store.dart';
import 'sip/sip_adapter.dart';
import 'ui/call_page.dart';
import 'ui/dialer_page.dart';
import 'ui/login_page.dart';

/// App bootstrap (spec 10.1): minimal pages only — login, dialer, call.
/// One engine, one controller; nothing SIP-related is created per screen.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final native = NativeCallBridge();
  final sip = SipAdapter();
  final controller = CallController(
    api: ControlApiClient(domain: 'not-yet-configured.invalid'),
    sip: sip,
    native: native,
    store: SecureCredentialStore(native),
  );
  sip.bind(controller);
  // Cold-start safe: restoreSession must work without any visible page
  // (the native call flow never waits for Flutter UI, spec 10.3).
  await controller.restoreSession();
  runApp(MiniVoipApp(controller: controller));
}

class MiniVoipApp extends StatelessWidget {
  final CallController controller;
  const MiniVoipApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini VoIP Free',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0), useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF1565C0),
          brightness: Brightness.dark,
          useMaterial3: true),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => _root(controller),
      ),
    );
  }

  Widget _root(CallController c) {
    switch (c.state) {
      case AppCallState.unconfigured:
      case AppCallState.signingIn:
      case AppCallState.error:
        return LoginShell(controller: c);
      case AppCallState.incomingPending:
      case AppCallState.outgoingPending:
      case AppCallState.connecting:
      case AppCallState.connected:
      case AppCallState.ending:
        return CallPage(controller: c);
      case AppCallState.idle:
        return DialerPage(controller: c, onStartCall: () {});
    }
  }
}

class DialerShell extends StatelessWidget {
  final CallController controller;
  const DialerShell({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CallPage(controller: controller),
    );
  }
}

class LoginShell extends StatelessWidget {
  final CallController controller;
  const LoginShell({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LoginPage(
      controller: controller,
      store: SecureCredentialStore(NativeCallBridge()),
      onSignedIn: () {},
    );
  }
}
