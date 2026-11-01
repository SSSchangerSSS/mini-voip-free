import 'dart:async';

import 'package:sip_ua/sip_ua.dart';
import 'package:logger/logger.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../call/call_controller.dart';
import '../native/native_call_bridge.dart';
// ignore: implementation_imports
import 'package:sip_ua/src/event_manager/call_events.dart' show EventStream;

/// Thin SIP adapter around sip_ua 1.1.0 (spec 2.1/10.1). Written against the REAL
/// package API (SIPUAHelper + SipUaHelperListener) verified from the pub.dev
/// archive — no guessed names. This is the ONLY file that knows the SIP stack.
///
/// ⚠ P0 GATE: still must be validated against a real Release build on both
/// platforms (cold start + REGISTER behaviour) before any claim.
class SipAdapter implements SipUaHelperListener {
  SipAdapter({SIPUAHelper? helper, Future<void> Function(bool)? audioOutput, Future<void> Function()? prepareMediaLogging})
      : _helper = helper ?? SIPUAHelper(),
        _audioOutput = audioOutput ?? rtc.Helper.setSpeakerphoneOn,
        _prepareMediaLogging = prepareMediaLogging ?? (() async {
          if (rtc.WebRTC.platformIsAndroid) await NativeCallBridge().suppressMediaLogs();
        }) {
    // Library debug traces contain complete SIP messages and configuration.
    _helper.loggingLevel = Level.off;
  }
  final SIPUAHelper _helper;
  final Future<void> Function(bool) _audioOutput;
  final Future<void> Function() _prepareMediaLogging;
  Call? _activeCall;
  String? _reportedIncoming;
  CallController? _controller;
  Completer<void> _registeredOnce = Completer<void>();
  UaSettings? _settings;

  String _domain = '';
  bool _registered = false;

  String get domain => _domain;
  bool get registered => _registered;

  bool get hasActiveCall => _activeCall != null;

  void bind(CallController controller) => _controller = controller;

  Future<void> configure({
    required String domain,
    required String username,
    required String password,
  }) async {
    _domain = domain;
    if (rtc.WebRTC.platformIsAndroid || rtc.WebRTC.platformIsIOS) {
      await rtc.WebRTC.initialize(options: {'logSeverity':'none'}); // Native INFO logs contain ephemeral ICE credentials.
    }
    await rtc.Helper.setAndroidAudioConfiguration(rtc.AndroidAudioConfiguration.communication);
    final settings = UaSettings();
    settings.transportType = TransportType.WS;
    settings.webSocketUrl = 'wss://$domain/ws';
    settings.webSocketSettings.allowBadCertificate = false; // TLS never bypassed (spec 11.1)
    settings.userAgent = 'mini-voip-free/0.1.0';
    settings.uri = 'sip:$username@$domain';
    settings.authorizationUser = username;
    settings.password = password;
    settings.displayName = 'داخلی $username';
    settings.iceServers = <Map<String, String>>[]; // Private LAN: host ICE candidates; no public Google STUN dependency.
    settings.register = true;
    settings.register_expires = 300;
    _settings = settings;
  }

  Future<void> start() async {
    final settings = _settings;
    if (settings == null) throw StateError('configure() must run before start()');
    _registeredOnce = Completer<void>();
    _helper.removeSipUaHelperListener(this);
    _helper.addSipUaHelperListener(this);
    await _helper.start(settings);
    // bounded wait for first REGISTER; callers treat not-ready explicitly
    await _registeredOnce.future.timeout(const Duration(seconds: 15));
  }

  Future<void> stop() async {
    if (_settings != null) _helper.stop();
    _helper.removeSipUaHelperListener(this);
    _registered = false;
  }

  Future<void> call(String targetUri, {required String attemptId}) async {
    await setSpeaker(false); // Set earpiece preference BEFORE AudioSwitch starts media.
    final ok = await _helper.call(targetUri, voiceOnly: true, headers: ['X-SMI-Attempt-ID: $attemptId'], customOptions: {'rtcOfferConstraints':_privateConstraints(),'rtcAnswerConstraints':_privateConstraints()}); // audio-only (spec 8.1)
    if (!ok) throw StateError('SIP engine not connected — REGISTER pending');
  }

  Future<void> setSpeaker(bool enabled) => _audioOutput(enabled);

  Future<void> hangUp() async {
    _activeCall?.hangup();
  }

  void setMuted(bool muted) {
    final call = _activeCall;
    if (call == null) return;
    if (muted) {
      call.mute(true, false); // audio only — there is no video track ever
    } else {
      call.unmute(true, false);
    }
  }

  /// Answer the pending remote INVITE exactly once (spec 5.2 step 13).
  /// The microphone starts only after this user action — ringing stays mic-free.
  Future<void> answerPendingOnce() async {
    await setSpeaker(false);
    _activeCall?.answer(<String, dynamic>{
      'rtcAnswerConstraints':_privateConstraints(),
      'rtcOfferConstraints':_privateConstraints(),
      'mediaConstraints': <String, dynamic>{
        'audio': true,
        'video': false, // audio-only product — no camera permission is ever requested
      },
    });
  }

  Future<void> rejectPendingOnce() async {
    // sip_ua 1.1.0 has no Call.reject — hangup on the early session rejects it
    _activeCall?.hangup();
  }

  // ── SipUaHelperListener (real interface, 6 members) ──────────────────────

  @override
  void transportStateChanged(TransportState state) {
    // WS lifecycle is policy-managed; background closure is not a failure (spec 10.4)
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _registered = state.state == RegistrationStateEnum.REGISTERED;
    if (_registered && !_registeredOnce.isCompleted) _registeredOnce.complete();
    if (!_registered && _registeredOnce.isCompleted) _registeredOnce = Completer<void>();
    // registration alone never implies an incoming call is ready (spec 4.3)
  }

  Map<String,dynamic> _privateConstraints()=>{
    'mandatory': {'OfferToReceiveAudio':true,'OfferToReceiveVideo':false},
    'optional': <dynamic>[],
    // sip_ua awaits modifiers AFTER offer/answer creation, BEFORE setLocalDescription.
    'offerModifiers': <Future<rtc.RTCSessionDescription> Function(rtc.RTCSessionDescription)>[
      (description) async { await _prepareMediaLogging(); return description; },
    ],
  };

  @override
  void callStateChanged(Call call, CallState state) {
    if(state.state==CallStateEnum.CALL_INITIATION && rtc.WebRTC.platformIsAndroid){
      call.session.on(EventStream(),(EventStream event){
        if(event.originator==Originator.local){
          unawaited(NativeCallBridge().suppressMediaLogs().catchError((Object _){call.hangup();}));
        }
      });
    }
    switch (state.state) {
      case CallStateEnum.PROGRESS:
        _activeCall = call;
        if (call.direction == Direction.incoming && _reportedIncoming != call.id) {
          _reportedIncoming = call.id;
          _activeCall = call;
          // correlation with the server callId happens in the controller (spec 5.2 step 13)
          _controller?.onSipIncoming(call.session.request?.getHeader('X-SMI-Call-ID') as String?);
        }
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        _activeCall = call;
        _controller?.onSipConnected();
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _activeCall = null;
        _reportedIncoming = null;
        _controller?.onSipRemoteEnded(failed: state.state == CallStateEnum.FAILED);
        break;
      case CallStateEnum.NONE:
      case CallStateEnum.STREAM:
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.CALL_INITIATION:
        _activeCall = call;
        if (call.direction == Direction.incoming && _reportedIncoming != call.id) {
          _reportedIncoming = call.id;
          _controller?.onSipIncoming(call.session.request?.getHeader('X-SMI-Call-ID') as String?);
        }
        break;
      case CallStateEnum.REFER:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
        break;
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    if (msg.originator == Originator.remote && msg.request?.body == 'smi-call') {
      _controller?.onForegroundCallHint();
    }
  }

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}
}
