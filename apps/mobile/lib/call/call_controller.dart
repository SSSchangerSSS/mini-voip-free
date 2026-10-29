import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;

import '../api/api_models.dart';
import '../api/control_api_client.dart';
import '../native/native_call_bridge.dart';
import '../native/native_event_queue.dart';
import '../secure/secure_credential_store.dart';
import '../sip/sip_adapter.dart';
import '../util/digit_normalizer.dart';

/// App-level call states (spec 6.2) — exactly these, no extra parallel states.
enum AppCallState {
  unconfigured,
  signingIn,
  idle,
  outgoingPending,
  incomingPending,
  connecting,
  connected,
  ending,
  error,
}

/// Human-safe outcome mapping (spec F06) — raw SIP/stack errors never reach UI.
enum CallOutcome { busy, noAnswer, unavailable, cancelled, disconnected, endedNormally, failedSetup }

/// A single, testable CallController owns ALL call state (spec 6.2/10.1).
/// UI, SIP events and native events all feed this one controller — there are no
/// separate "flutter call"/"push call"/"CallKit call" singletons.
class CallController extends ChangeNotifier {
  CallController({
    required ControlApiClient api,
    required SipAdapter sip,
    required NativeCallBridge native,
    required SecureCredentialStore store,
    DateTime Function()? clock,
    Future<void> Function(Duration)? restoreDelay,
  })  : _api = api,
        _sip = sip,
        _native = native,
        _store = store,
        _now = clock ?? (() => DateTime.now().toUtc()),
        _restoreDelay = restoreDelay ?? Future<void>.delayed {
    _queue = NativeEventQueue();
  }

  final ControlApiClient _api;
  final SipAdapter _sip;
  final NativeCallBridge _native;
  final SecureCredentialStore _store;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _restoreDelay;
  bool _restoringAccount = false;
  bool _savedAccountAvailable = false;
  bool _lastFailureRetryable = false;
  bool _engineStartAttempted = false;
  bool _disposed = false;
  String _startupStage = 'account-read';
  String? _startupFailureKind;

  late final NativeEventQueue _queue;
  StreamSubscription<NativeEvent>? _nativeSub;
  Timer? _pollTimer;

  AppCallState _state = AppCallState.unconfigured;
  String? _callId;
  String? _attemptId;
  String? _nativeCallUuid;
  int _deviceGeneration = 0;
  DateTime? _deadline;
  String? _remoteExtension;
  String? _extension;
  String? _incomingSipCallId;
  bool _muted = false;
  bool _speakerOn = false;
  String? _errorMessage;

  // answer intent binding (spec 6.2): AnswerRequested is bound to a callId and
  // survives until it can be applied exactly once — missing Dart/INVITE must not
  // destroy it.
  final Set<String> _answerIntents = <String>{};
  final Set<String> _answeredSipCalls = <String>{};
  final Set<String> _readySent = <String>{};

  AppCallState get state => _state;
  String? get callId => _callId;
  String? get remoteExtension => _remoteExtension;
  String? get errorMessage => _errorMessage;
  bool get muted => _muted;
  bool get speakerOn => _speakerOn;
  bool get micReady => _sip.registered;
  int get deviceGeneration => _deviceGeneration;
  DateTime? get deadline => _deadline;
  bool get restoringAccount => _restoringAccount;
  bool get canRetrySavedAccount => _savedAccountAvailable && _lastFailureRetryable;
  String? get startupFailureKind => _startupFailureKind;

  // ── lifecycle ────────────────────────────────────────────────────────────

  Future<void> restoreSession() async {
    if (_restoringAccount || _disposed ||
        (_state != AppCallState.unconfigured && _state != AppCallState.error)) { return; }
    _restoringAccount = true;
    _state = AppCallState.signingIn;
    _errorMessage = null;
    notifyListeners();
    try {
      _startupStage = 'account-read';
      final saved = await _store.load();
      if (_disposed) return;
      _savedAccountAvailable = saved != null;
      if (saved == null) {
        _state = AppCallState.unconfigured;
        return;
      }
      // Only transient failures get bounded retries. Never replace credentials,
      // change installation identity, bypass TLS or extend a call's deadline.
      const delays = [Duration(seconds: 2), Duration(seconds: 5)];
      for (var attempt = 0; attempt <= delays.length && !_disposed; attempt++) {
        if (await signIn(domain: saved.domain, extension: saved.extension,
            password: saved.password)) { break; }
        if (!_lastFailureRetryable || attempt == delays.length) break;
        debugPrint('SMI_STARTUP retry attempt=${attempt + 2}');
        await _restoreDelay(delays[attempt]);
      }
    } catch (error) {
      _recordStartupFailure(error);
      _state = AppCallState.error;
      _errorMessage = 'دسترسی به حساب ذخیره‌شده ممکن نشد؛ دوباره تلاش کنید.';
    } finally {
      _restoringAccount = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> signIn({
    required String domain,
    required String extension,
    required String password,
  }) async {
    _state = AppCallState.signingIn;
    _errorMessage = null;
    _lastFailureRetryable = false;
    _startupFailureKind = null;
    notifyListeners();

    try {
      _startupStage = 'account-read';
      final installationId = await _ensureInstallationId();
      _api.setDomain(domain);
      _startupStage = 'api-login';
      final result = await _api.login(
        extension: extension,
        password: password,
        installationId: installationId,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      _api.setToken(result.accessToken);
      _deviceGeneration = result.deviceGeneration;
      _extension = result.extension;
      _startupStage = 'account-write';
      await _store.saveAccount(
        domain: domain,
        extension: result.extension,
        password: password,
        sipPassword: result.sipPassword,
        installationId: installationId,
        accessToken: result.accessToken,
      );
      _savedAccountAvailable = true;
      _startupStage = 'push-bind';
      await _registerPushToken();
      await _startEngine(
        domain: domain,
        extension: result.extension,
        password: result.sipPassword,
        installationId: installationId,
        relogin: true,
      );
      return true;
    } on ApiProblem catch (e) {
      _recordStartupFailure(e);
      await _closeFailedStartupEngine();
      _state = AppCallState.error;
      _errorMessage = _friendlyLoginError(e);
      notifyListeners();
      return false;
    } catch (error) {
      // Transport/TLS and native-store failures must end the progress state.
      // Never expose raw exception text or weaken certificate verification.
      _state = AppCallState.error;
      _recordStartupFailure(error);
      await _closeFailedStartupEngine();
      _errorMessage = error is HandshakeException
          ? 'اعتبار گواهی امن سرور تأیید نشد.'
          : _lastFailureRetryable
              ? 'اتصال برقرار نشد؛ دوباره تلاش کنید.'
              : 'ورود انجام نشد؛ اتصال امن سرور و مجوزهای برنامه را بررسی کنید.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _closeFailedStartupEngine() async {
    if (!_engineStartAttempted) return;
    try {
      await _sip.stop();
      _engineStartAttempted = false;
    } catch (_) {
      _lastFailureRetryable = false;
      debugPrint('SMI_STARTUP cleanup failed; automatic retry stopped');
    }
  }

  void _recordStartupFailure(Object error) {
    _lastFailureRetryable = error is TimeoutException || error is SocketException ||
        error is http.ClientException ||
        (error is ApiProblem && [502, 503, 504].contains(error.status));
    _startupFailureKind = error is HandshakeException ? 'tls'
        : error is TimeoutException ? 'timeout'
        : error is SocketException || error is http.ClientException ? 'network'
        : error is ApiProblem ? 'api-${error.status}'
        : error is PlatformException ? 'native' : 'protocol-or-internal';
    // Never log exception messages, request bodies, account identifiers or tokens.
    debugPrint('SMI_STARTUP failure stage=$_startupStage kind=$_startupFailureKind retryable=$_lastFailureRetryable');
  }

  String _friendlyLoginError(ApiProblem e) {
    switch (e.code) {
      case 'DEVICE_ALREADY_BOUND':
        return 'این شماره داخلی روی دستگاه دیگری فعال است. با مدیر سامانه تماس بگیرید.';
      case 'RATE_LIMITED':
        return 'تلاش‌های ناموفق زیاد است؛ کمی بعد دوباره امتحان کنید.';
      case 'INVALID_CREDENTIALS':
        return 'شماره داخلی یا رمز درست نیست.';
      default:
        return 'ورود انجام نشد؛ اتصال سرور را بررسی کنید.';
    }
  }

  Future<String> _ensureInstallationId() async {
    final saved = await _store.load();
    if (saved != null && saved.installationId.isNotEmpty) return saved.installationId;
    final fresh = _newUuid();
    await _native.secureWrite('smi.installationId', fresh);
    return fresh;
  }

  Future<void> _registerPushToken() async {
    try {
      final token = await _native.getPushToken();
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      if (token == null || token.isEmpty) {
        _errorMessage = 'اعلان پس‌زمینه فعال نیست؛ دریافت تماس فعلاً فقط هنگام باز بودن اپ ممکن است.';
      }
      await _api.registerPush(
        provider: isIos ? 'apns' : 'fcm',
        token: token ?? '',
        environment: 'production',
      );
    } on ApiProblem {
      // push registration failure must not hide behind a green ready state (spec 10.1)
      _errorMessage = 'ثبت توکن اعلان ناموفق بود؛ دریافت تماس در پس‌زمینه ممکن نیست.';
    }
  }

  Future<void> _startEngine({
    required String domain,
    required String extension,
    required String password,
    required String installationId,
    required bool relogin,
  }) async {
    _startupStage = 'native-setup';
    await _native.configure(domain: domain);
    _native.startListening();
    _nativeSub ??= _native.events.listen(_onNativeEvent);

    // reconcile pending native events BEFORE trusting any new state (spec 10.3)
    for (final e in await _native.getPendingEvents()) {
      _onNativeEvent(e);
      await _native.ackEvent(e.eventId);
    }

    _startupStage = 'sip-configure';
    await _sip.configure(
      domain: domain,
      username: extension,
      password: password,
    );
    _startupStage = 'sip-register';
    _engineStartAttempted = true;
    await _sip.start();

    // app open is NOT a sign of readiness; poll the server for a live call (spec 5.2 step 9)
    _startupStage = 'call-reconcile';
    await _reconcileWithServer();
    _startPollingWhilePending();

    if (_state == AppCallState.unconfigured || _state == AppCallState.signingIn) {
      _state = AppCallState.idle;
    }
    notifyListeners();
  }

  // ── outgoing (F02) ───────────────────────────────────────────────────────

  Future<bool> placeCall(String rawTarget) async {
    final target = DigitNormalizer.normalizeInternal(rawTarget);
    if (target == null) {
      _errorMessage = 'شماره داخلی نامعتبر است (۳ رقم در بازه ۱۰۱ تا ۱۹۹).';
      notifyListeners();
      return false;
    }
    if (_state != AppCallState.idle) return false; // one outgoing INVITE per tap (T09)
    if (!_sip.registered) {
      _errorMessage = 'ثبت SIP کامل نیست؛ چند لحظه بعد دوباره تلاش کنید.';
      notifyListeners();
      return false;
    }
    _attemptId = _newUuid();
    _nativeCallUuid = _attemptId;
    _deadline = _now().add(const Duration(seconds: 40));
    _state = AppCallState.outgoingPending;
    _remoteExtension = target;
    _errorMessage = null;
    notifyListeners();

    try {
      await _native.reportOutgoing(_attemptId!);
      await _sip.call('sip:$target@${_sip.domain}', attemptId: _attemptId!);
    } catch (_) {
      _state = AppCallState.idle;
      _errorMessage = 'شروع تماس ناموفق بود.';
      notifyListeners();
      return false;
    }
    return true;
  }

  // ── incoming + intents ───────────────────────────────────────────────────

  void _onNativeEvent(NativeEvent e) {
    final expired = e.expiresAt != null && e.expiresAt!.isBefore(_now());
    switch (e.type) {
      case NativeEventType.incomingReported:
        if (expired) return; // never attach a dead call (spec 5.4)
        _callId = e.callId;
        _remoteExtension = e.callerExtension;
        _deadline = e.expiresAt;
        _state = AppCallState.incomingPending;
        notifyListeners();
        break;
      case NativeEventType.answerRequested:
        if (e.callId != null) _answerIntents.add(e.callId!);
        if (_state == AppCallState.incomingPending && e.callId == _callId) {
          _acceptIntent();
        }
        break;
      case NativeEventType.declineRequested:
        if (e.callId != null && e.callId == _callId) declineIncoming();
        break;
      case NativeEventType.endRequested:
      case NativeEventType.nativeCallReset:
        if (_callId == null || e.callId == null || e.callId == _callId) {
          _teardown(outcome: CallOutcome.disconnected, silent: e.type == NativeEventType.endRequested);
        }
        break;
      case NativeEventType.audioActivated:
      case NativeEventType.audioDeactivated:
      case NativeEventType.capabilityChanged:
      case NativeEventType.pushTokenChanged:
        _registerPushToken();
        break;
    }
  }

  /// User tapped answer (maybe before INVITE arrived): intent first, SIP second (spec 5.2 steps 13–14).
  Future<void> answerIncoming() async {
    if (_callId == null) return;
    _answerIntents.add(_callId!);
    await _acceptIntent();
  }

  Future<void> _acceptIntent() async {
    if (_callId == null) return;
    if (_state == AppCallState.incomingPending) {
      _state = AppCallState.connecting;
      notifyListeners();
    }
    try {
      final response = await _api.callAction('accept', _callId!,
          idempotencyKey: 'accept-$_callId'); // POST /accept registers intent only
      if (response.isTerminal) { onServerState(response); return; }
      if (_incomingSipCallId == _callId) await _answerSipOnce(_callId!);
    } on ApiProblem catch (e) {
      if (e.code == 'CALL_ENDED' || e.code == 'CALL_EXPIRED') {
        _teardown(outcome: CallOutcome.cancelled);
      }
    }
  }

  Future<void> declineIncoming() async {
    if (_callId == null) return;
    final id = _callId!;
    _state = AppCallState.ending;
    notifyListeners();
    try {
      await _api.callAction('decline', id, idempotencyKey: 'decline-$id');
    } on ApiProblem catch (e) {
      if (e.code == 'CALL_ENDED' || e.code == 'CALL_EXPIRED') {
        // server already terminal — align UI, never revive
      }
    }
    await _native.endCall(_nativeCallUuid ?? id, 'declined');
    _teardown(outcome: CallOutcome.endedNormally);
  }

  // ── SIP adapter callbacks ────────────────────────────────────────────────

  /// Called by SipAdapter when the remote INVITE for a pending server call arrives.
  /// Matching is by the X-SMI-Call-ID header value (server UUID, spec 5.2 step 13).
  Future<void> onSipIncoming(String? smiCallId) async {
    if (smiCallId == null) { await _sip.rejectPendingOnce(); return; }
    _incomingSipCallId = smiCallId;
    await _reconcileWithServer();
    // late INVITE after decline/terminal → reject on the SIP path too (spec 5.3)
    if (_answerIntents.contains(smiCallId) && smiCallId == _callId) {
      await _answerSipOnce(smiCallId);
    } else if (smiCallId != _callId) {
      await _sip.rejectPendingOnce();
    }
  }

  Future<void> _answerSipOnce(String id) async {
    if (!_answeredSipCalls.add(id)) return;
    try { await _sip.answerPendingOnce(); }
    catch (_) { _answeredSipCalls.remove(id); rethrow; }
  }

  Future<void> onForegroundCallHint() => _reconcileWithServer();

  void onSipConnected() {
    if (_state == AppCallState.outgoingPending ||
        _state == AppCallState.connecting) {
      // Fetch PBX bridge evidence; SIP acceptance alone is not Connected.
      _reconcileWithServer();
      notifyListeners();
    }
  }

  /// SIP path terminated (remote BYE/CANCEL/failure). The server remains the
  /// source of truth; UI falls back to idle immediately so no ghost call remains.
  void onSipRemoteEnded() {
    if (_state == AppCallState.connected ||
        _state == AppCallState.connecting ||
        _state == AppCallState.incomingPending ||
        _state == AppCallState.outgoingPending) {
      _teardown(outcome: CallOutcome.disconnected);
    }
  }

  /// Server-confirmed Connected (polled state). Timer starts on real connection.
  void onServerState(CallDto call) {
    final isCallee = call.callee == _extension;
    if (!isCallee && call.caller != _extension) return;
    _remoteExtension = isCallee ? call.caller : call.callee;
    _callId = call.callId;
    _deadline = call.expiresAt;
    _deviceGeneration = call.deviceGeneration;
    switch (call.state) {
      case CallDtoState.pending:
        if (_state != AppCallState.incomingPending &&
            _state != AppCallState.outgoingPending) {
          _state = AppCallState.incomingPending;
        }
        if (isCallee) _sendReadyIfNeeded(call); // step 9: ready after SIP REGISTER gates the dial
        break;
      case CallDtoState.connecting:
        _state = isCallee && !_answerIntents.contains(call.callId)
            ? AppCallState.incomingPending : AppCallState.connecting;
        break;
      case CallDtoState.connected:
        if (_state != AppCallState.connected) {
          _state = AppCallState.connected;
          _nativeCallUuid ??= call.callId;
        }
        break;
      case CallDtoState.ended:
        _teardown(outcome: _mapEndReason(call.endReason));
        break;
    }
    notifyListeners();
  }

  /// POST /ready exactly once per call — after REGISTER, with our device
  /// generation. Repeated ready never creates a second call (spec 5.2, T27).
  Future<void> _sendReadyIfNeeded(CallDto call) async {
    if (call.isTerminal || !_sip.registered || !_readySent.add(call.callId)) return;
    if (!_sip.registered) return; // ready will be sent on the next poll tick
    try {
      final fresh = await _api.callAction(
        'ready',
        call.callId,
        idempotencyKey: 'ready-${call.callId}',
        body: <String, dynamic>{
          'registered': true,
          'deviceGeneration': call.deviceGeneration,
        },
      );
      if (!fresh.isTerminal) return; // normal path
      onServerState(fresh);
    } on ApiProblem catch (e) {
      if (e.code == 'STALE_DEVICE' || e.code == 'CALL_EXPIRED' || e.code == 'CALL_ENDED') {
        _teardown(outcome: CallOutcome.disconnected);
      }
    }
  }

  CallOutcome _mapEndReason(String? reason) {
    switch (reason) {
      case 'Busy':
        return CallOutcome.busy;
      case 'NoAnswer':
        return CallOutcome.noAnswer;
      case 'Unavailable':
      case 'Expired':
        return CallOutcome.unavailable;
      case 'CallerCancelled':
        return CallOutcome.cancelled;
      case 'Declined':
        return CallOutcome.endedNormally;
      default:
        return CallOutcome.disconnected;
    }
  }

  // ── media controls (F04) ─────────────────────────────────────────────────

  Future<void> toggleMute() async {
    _muted = !_muted;
    final id = _nativeCallUuid ?? _callId;
    if (id != null) await _native.setMuted(id, _muted);
    _sip.setMuted(_muted);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    final id = _nativeCallUuid ?? _callId;
    if (id != null) await _native.setSpeaker(id, _speakerOn);
    await _sip.setSpeaker(_speakerOn);
    notifyListeners();
  }

  Future<void> hangUp() async {
    if (_callId == null) {
      await _sip.hangUp();
      _teardown(outcome: CallOutcome.endedNormally);
      return;
    }
    final id = _callId!;
    _state = AppCallState.ending;
    notifyListeners();
    await _sip.hangUp();
    try {
      await _api.callAction('end', id, idempotencyKey: 'end-$id');
    } on ApiProblem {
      // SIP BYE path is primary; API end is the backstop (spec 5.2 step 16)
    }
    _teardown(outcome: CallOutcome.endedNormally);
  }

  Future<void> logout() async {
    await _sip.stop();
    await _api.logout().catchError((Object _) {/* local wipe proceeds; server revoke unconfirmed is reported */});
    await _store.wipe();
    _teardown(outcome: CallOutcome.endedNormally, silent: true);
    _state = AppCallState.unconfigured;
    notifyListeners();
  }

  // ── polling + reconcile (T-window only, spec 4.2) ────────────────────────

  void _startPollingWhilePending() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      final inWindow = _state == AppCallState.incomingPending ||
          _state == AppCallState.outgoingPending ||
          _state == AppCallState.connecting;
      if (!inWindow) return;
      await _reconcileWithServer();
    });
  }

  Future<void> _reconcileWithServer() async {
    try {
      final call = await _api.currentCall(attemptId: _attemptId);
      if (call == null) {
        // AMI admission races the first poll after INVITE. Absence of the row
        // is not a terminal decision while this outgoing attempt is starting.
        if (_state == AppCallState.outgoingPending && _callId == null &&
            _deadline != null && _now().isBefore(_deadline!)) { return; }
        if (_state == AppCallState.incomingPending ||
            _state == AppCallState.outgoingPending ||
            _state == AppCallState.connecting) {
          _teardown(outcome: CallOutcome.disconnected);
        }
        return;
      }
      if (_attemptId != null && call.attemptId != _attemptId) {
        return; // not our attempt
      }
      if (_deadline != null && call.callId == _callId &&
          _now().isAfter(call.expiresAt) && !call.isTerminal) {
        // server deadline passed while UI still pending → clean failure (spec 5.3)
        _teardown(outcome: CallOutcome.unavailable);
        return;
      }
      onServerState(call);
    } on ApiProblem catch (e) {
      if (e.status == 401) {
        _state = AppCallState.error;
        _errorMessage = 'نشست منقضی شده؛ دوباره وارد شوید.';
        notifyListeners();
      }
    } catch (_) {
      // network hiccup — deadline + SIP teardown still protect us (spec 5.5)
    }
  }

  void _teardown({required CallOutcome outcome, bool silent = false}) {
    _readySent.clear();
    _answerIntents.clear();
    _answeredSipCalls.clear();
    _incomingSipCallId = null;
    _callId = null;
    _attemptId = null;
    _nativeCallUuid = null;
    _deadline = null;
    _remoteExtension = null;
    _muted = false;
    _speakerOn = false;
    _queue.clear();
    if (!silent) {
      _errorMessage = switch (outcome) {
        CallOutcome.busy => 'مقصد مشغول است.',
        CallOutcome.noAnswer => 'پاسخ داده نشد.',
        CallOutcome.unavailable => 'در دسترس نیست.',
        CallOutcome.cancelled => 'تماس لغو شد.',
        CallOutcome.disconnected => 'اتصال قطع شد.',
        CallOutcome.failedSetup => 'برقراری تماس ناموفق بود.',
        CallOutcome.endedNormally => null,
      };
    }
    if (_state != AppCallState.unconfigured && _state != AppCallState.error) {
      _state = AppCallState.idle;
    }
    notifyListeners();
  }

  String _newUuid() {
    final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _nativeSub?.cancel();
    _native.stopListening();
    unawaited(_sip.stop().catchError((Object _) {
      debugPrint('SMI_STARTUP SIP shutdown failed');
    }));
    super.dispose();
  }
}
