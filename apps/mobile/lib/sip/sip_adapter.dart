import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';

import '../call/call_controller.dart';

/// Thin SIP adapter around sip_ua 1.1.0 (spec 2.1/10.1). It owns NO business
/// logic: it forwards SIP lifecycle to CallController and exposes a minimal
/// control surface. This is the ONLY file that knows about the SIP stack.
///
/// ⚠ P0 GATE: this surface must be validated against a real Release build on both
/// platforms (cold start + REGISTER behaviour) before any claim.
class SipAdapter implements SipUaHelperDelegate {
  SipAdapter();

  UA? _ua;
  Call? _activeCall;
  CallController? _controller;
  Completer<void> _registeredOnce = Completer<void>();

  String _domain = '';
  bool _registered = false;

  String get domain => _domain;
  bool get registered => _registered;

  void bind(CallController controller) => _controller = controller;

  Future<void> configure({
    required String domain,
    required String username,
    required String password,
  }) async {
    _domain = domain;
    final settings = UaSettings();
    settings.webSocketUrl = 'wss://$domain/ws';
    settings.webSocketSettings.allowBadCertificate = false; // TLS never bypassed (spec 11.1)
    settings.userAgent = 'mini-voip-free/0.1.0';
    settings.sipUri = 'sip:$username@$domain';
    settings.authorizationUserName = username;
    settings.password = password;
    settings.displayName = 'داخلی $username';
    settings.register = true;

    _ua = UA(settings, delegate: this);
  }

  Future<void> start() async {
    _registeredOnce = Completer<void>();
    _ua?.start();
    // best-effort bounded wait for first REGISTER; callers treat false as not-ready
    await _registeredOnce.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  Future<void> stop() async {
    _ua?.stop();
    _registered = false;
  }

  Future<void> call(String targetUri) async {
    final ua = _ua;
    if (ua == null) throw StateError('SIP engine not started');
    // voice-only: no video track is ever created (spec 8.1)
    ua.call(targetUri, true);
  }

  Future<void> hangUp() async {
    _activeCall?.hangup();
  }

  void setMuted(bool muted) {
    final call = _activeCall;
    if (call == null) return;
    if (muted) {
      call.mute();
    } else {
      call.unmute();
    }
  }

  /// Answer the pending remote INVITE exactly once (spec 5.2 step 13).
  /// The microphone starts only after this user action — ringing stays mic-free.
  Future<void> answerPendingOnce() async {
    final call = _activeCall;
    if (call == null) return;
    call.answer(<String, dynamic>{
      'mediaConstraints': <String, dynamic>{
        'audio': true,
        'video': false, // audio-only product — no camera permission is ever requested
      },
    });
  }

  Future<void> rejectPendingOnce() async {
    _activeCall?.reject();
  }

  // ── SipUaHelperDelegate ───────────────────────────────────────────────────

  @override
  void registrationStateChanged(RegistrationState state) {
    _registered = state.state == RegistrationStateEnum.REGISTRATION_SUCCESS;
    if (_registered && !_registeredOnce.isCompleted) _registeredOnce.complete();
    if (!_registered && _registeredOnce.isCompleted) _registeredOnce = Completer<void>();
    // registration alone never implies an incoming call is ready (spec 4.3)
  }

  @override
  void callStateChanged(Call call, CallState state) {
    switch (state) {
      case CallState.CALL_INCOMING:
        _activeCall = call;
        // correlation with the server callId happens in the controller (spec 5.2 step 13)
        _controller?.onSipIncoming(null);
        break;
      case CallState.CALL_ACCEPTED:
      case CallState.CALL_CONFIRMED:
        _activeCall = call;
        _controller?.onSipConnected();
        break;
      case CallState.CALL_ENDED:
      case CallState.CALL_FAILED:
      case CallState.CALL_TERMINATED:
        _activeCall = null;
        _controller?.onSipRemoteEnded();
        break;
      default:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    // WS lifecycle is policy-managed; background closure is not a failure (spec 10.4)
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify nctf) {}
}
