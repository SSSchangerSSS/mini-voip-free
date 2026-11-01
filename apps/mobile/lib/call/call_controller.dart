import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;

import '../api/api_models.dart';
import '../config/app_config.dart';
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
  bool _platformAudioRoute = false;
  bool _directReception = false;
  bool _backgroundReady = false;
  String? _receptionWarning;
  bool get backgroundReceptionReady => !_directReception || _backgroundReady;
  String? get receptionWarning => _receptionWarning;
  bool _directCheckBusy = false;
  bool _controlReachable = false;
  DateTime? _lastDirectReconnect;
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
  List<ExtensionEntry> _directory = const [];
  List<ExtensionEntry> get directory => List.unmodifiable(_directory);
  String? get extension => _extension;
  bool _directoryLoading = false;
  bool get directoryLoading => _directoryLoading;
  String? _directoryError;
  String? get directoryError => _directoryError;
  String get remoteName {
    for (final entry in _directory) { if (entry.extension == _remoteExtension) return entry.displayName; }
    return '';
  }
  String get remoteLabel {
    for (final entry in _directory) { if (entry.extension == _remoteExtension) return entry.label; }
    return _remoteExtension == null ? '—' : 'داخلی $_remoteExtension';
  }
  Future<Map<Object?, Object?>> receptionCapabilities() => _native.getCapabilities();
  Future<String> openReceptionSetting(String target) => _native.openReceptionSetting(target);
  Future<void> openIncomingSettings() => _native.openIncomingSettings();
  Timer? _directoryRetry;
  int _directoryEpoch = 0;
  bool _invalidating = false;
  void _stopDirectoryWatch() { _directoryEpoch++; _directoryRetry?.cancel(); }
  void _startDirectoryWatch() { _stopDirectoryWatch(); _watchDirectory(_directoryEpoch, ''); }
  Future<void> _watchDirectory(int epoch, String version) async {
    if (_disposed || epoch != _directoryEpoch) return;
    try {
      final snapshot = await _api.watchDirectory(version);
      if (_disposed || epoch != _directoryEpoch) return;
      _directory = snapshot.entries; _directoryError = null; notifyListeners();
      // Yield to the event loop even when the first snapshot is immediate.
      _directoryRetry = Timer(Duration.zero, ()=>_watchDirectory(epoch,snapshot.version));
    } on ApiProblem catch(e) {
      if (_disposed || epoch != _directoryEpoch) return;
      if(e.status==401) { await _sessionRevoked(); return; }
      _directoryRetry=Timer(const Duration(seconds:3),()=>_watchDirectory(epoch,version));
    } catch(_) {
      if (!_disposed && epoch==_directoryEpoch) _directoryRetry=Timer(const Duration(seconds:3),()=>_watchDirectory(epoch,version));
    }
  }
  Future<void> _sessionRevoked() async {
    if (_invalidating || _disposed) return;
    _invalidating=true; _stopDirectoryWatch(); _api.setToken(null);
    _state=AppCallState.error;
    _savedAccountAvailable=false; _lastFailureRetryable=false;
    _extension=null; _directory=const []; _controlReachable=false;
    try { await _sip.stop(); } catch(_) { /* local credentials still wiped */ }
    await _store.wipe();
    _teardown(outcome:CallOutcome.endedNormally,silent:true);
    _state=AppCallState.error; _errorMessage='نشست باطل شده؛ دوباره با شماره و رمز وارد شوید.';
    _invalidating=false;
    if(!_disposed)notifyListeners();
  }
  String get serverAddress => AppConfig.domain.isNotEmpty ? AppConfig.domain : _api.domain;
  Future<void> changeServer(String address, String developerPassword) async {
    if (![AppCallState.idle,AppCallState.unconfigured,AppCallState.error].contains(_state)) throw StateError('ACTIVE_CALL');
    if(!AppConfig.validAddress(address)) throw ArgumentError('INVALID_ADDRESS');
    if(!await _native.verifyDeveloperPassword(developerPassword)) throw StateError('DEVELOPER_DENIED');
    await logout();
    await _native.secureWrite('smi.serverOverride',address.toLowerCase());
    AppConfig.overrideDomain=address.toLowerCase();
    _api.setDomain(address.toLowerCase()); notifyListeners();
  }
  Future<void> refreshDirectory() async {
    if (_directoryLoading || _disposed) return;
    final epoch=_directoryEpoch;
    _directoryLoading = true; _directoryError = null; notifyListeners();
    try { final entries=await _api.extensions(); if(epoch==_directoryEpoch)_directory = entries; }
    catch (_) { _directoryError = 'فهرست داخلی‌ها دریافت نشد؛ دوباره تلاش کنید.'; }
    finally { _directoryLoading = false; if (!_disposed) notifyListeners(); }
  }

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
      if(saved.token != null) {
        _api.setDomain(saved.domain); _api.setToken(saved.token);
        try { await _api.me(); }
        on ApiProblem catch(e) { if(e.status==401) {await _sessionRevoked(); return;} rethrow; }
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
    if(_invalidating)return false;
    _stopDirectoryWatch();
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
      await _native.secureWrite('smi.deviceGeneration', _deviceGeneration.toString());
      _startupStage = 'push-bind';
      await _registerPushToken();
      await _startEngine(
        domain: domain,
        extension: result.extension,
        password: result.sipPassword,
        installationId: installationId,
        relogin: true,
      );
      _startDirectoryWatch();
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

  Future<bool> _registerPushToken() async {
    try {
      Map<Object?,Object?> capabilities = {};
      try { capabilities = await _native.getCapabilities(); } catch (_) { /* legacy adapter */ }
      if (capabilities['directIncoming'] == true) {
        _directReception = true;
        _updateReceptionRequirements(capabilities);
        return true;
      }
      final token = await _native.getPushToken();
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      if (token == null || token.isEmpty) {
        _errorMessage = 'اعلان پس‌زمینه فعال نیست؛ دریافت تماس فعلاً فقط هنگام باز بودن اپ ممکن است.';
        return false;
      }
      await _api.registerPush(
        provider: isIos ? 'apns' : 'fcm',
        token: token,
        environment: 'production',
      );
    } on ApiProblem {
      // push registration failure must not hide behind a green ready state (spec 10.1)
      _errorMessage = 'ثبت توکن اعلان ناموفق بود؛ دریافت تماس در پس‌زمینه ممکن نیست.';
      return false;
    } catch (_) {
      _errorMessage = 'ثبت اعلان تماس انجام نشد؛ اتصال را بررسی و برنامه را دوباره باز کنید.';
      return false;
    }
    return true;
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
      if (e.type == NativeEventType.pushTokenChanged) {
        if (await _registerPushToken()) await _native.ackEvent(e.eventId);
      } else {
        _onNativeEvent(e);
        await _native.ackEvent(e.eventId);
      }
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
    // A new process cannot recover the previous process's WebRTC media session.
    // End that orphaned server leg rather than showing a connected silent call.
    if (_state == AppCallState.connected && !_sip.hasActiveCall) {
      await hangUp();
      _errorMessage = 'تماس قبلی پس از بسته‌شدن فرایند پایان یافت؛ دوباره تماس بگیرید.';
    }
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
      _teardown(outcome: CallOutcome.failedSetup);
      return false;
    }
    return true;
  }

  // ── incoming + intents ───────────────────────────────────────────────────

  void _onNativeEvent(NativeEvent e) {
    final expired = e.expiresAt != null && e.expiresAt!.isBefore(_now());
    switch (e.type) {
      case NativeEventType.receptionCheckRequested:
        _directReception = true; // Native standby also resumes a failed cold login.
        unawaited(checkDirectReception());
        break;
      case NativeEventType.incomingReported:
        if (expired) return; // never attach a dead call (spec 5.4)
        _errorMessage = null;
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
        if (_state != AppCallState.idle && _state != AppCallState.unconfigured &&
            (e.callId == _callId || e.callId == _nativeCallUuid)) { unawaited(hangUp()); }
        break;
      case NativeEventType.nativeCallReset:
        if (e.callId == _callId || e.callId == _nativeCallUuid) {
          unawaited(_sip.hangUp()); _teardown(outcome: CallOutcome.disconnected);
        }
        break;
      case NativeEventType.capabilityChanged:
        if ((e.callId == _callId || e.callId == _nativeCallUuid) && e.callId != null) {
          if (e.speakerOn != null) { _platformAudioRoute = true; _speakerOn = e.speakerOn!; }
          if (e.muted != null) { _muted = e.muted!; _sip.setMuted(_muted); }
          notifyListeners();
        }
        break;
      case NativeEventType.audioActivated:
      case NativeEventType.audioDeactivated:
        break;
      case NativeEventType.pushTokenChanged:
        unawaited(_registerPushToken().then((ok) async {
          if (ok) await _native.ackEvent(e.eventId);
          if (!_disposed) notifyListeners();
        }));
        break;
    }
  }

  void _updateReceptionRequirements(Map<Object?, Object?> capabilities) {
    _backgroundReady = capabilities['microphone'] == true && capabilities['notifications'] == true &&
        capabilities['incomingChannelEnabled'] != false &&
        capabilities['batteryUnrestricted'] == true && capabilities['standbyRunning'] == true;
    _receptionWarning = capabilities['notifications'] != true || capabilities['incomingChannelEnabled'] == false
        ? 'اعلان تماس غیرفعال است؛ برای زنگ در پس‌زمینه آن را فعال کنید.'
        : capabilities['microphone'] != true
            ? 'اجازه میکروفن فعال نیست؛ راه‌اندازی دریافت تماس را کامل کنید.'
        : capabilities['batteryUnrestricted'] != true
            ? 'دریافت در قفل و پس‌زمینه آماده نیست؛ محدودیت باتری برنامه را بردارید.'
            : capabilities['standbyRunning'] != true ? 'سرویس دریافت تماس هنوز آماده نشده است.'
            : capabilities['fullScreenIntent'] == false ? 'نمایش تمام‌صفحه روی قفل اجازه ندارد؛ راه‌اندازی دریافت تماس را بررسی کنید.'
            : capabilities['vendorBackgroundSetup'] == true ? 'اتصال Android آماده است؛ راه‌اندازی خودکار و تنظیمات HyperOS هنوز قابل تأیید خودکار نیستند.' : null;
  }

  /// Native standby heartbeat also catches a missed SIP MESSAGE; it carries no credentials.
  Future<void> checkDirectReception() async {
    if (!_directReception || _directCheckBusy || _disposed || _restoringAccount) return;
    _directCheckBusy = true;
    try {
      final retryDue = _lastDirectReconnect == null || _now().difference(_lastDirectReconnect!) >= const Duration(seconds:30);
      if (_state == AppCallState.error && _lastFailureRetryable && _savedAccountAvailable && retryDue) {
        _lastDirectReconnect = _now();
        await restoreSession();
      } else if (_extension != null && _state != AppCallState.unconfigured && _state != AppCallState.signingIn) {
        if (!_sip.registered && _state == AppCallState.idle && retryDue) {
          _lastDirectReconnect = _now();
          try { await _sip.start(); } catch (_) { /* next bounded native heartbeat */ }
        }
        if (_state != AppCallState.error) await _reconcileWithServer();
      }
      _updateReceptionRequirements(await _native.getCapabilities());
      await _native.updateReception(_backgroundReady && _sip.registered && _controlReachable && _state != AppCallState.error);
      if (!_disposed) notifyListeners();
    } catch (_) { /* no uncaught background errors; next native heartbeat retries */ }
    finally { _directCheckBusy = false; }
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
      _errorMessage = null;
      _state = AppCallState.connecting;
      notifyListeners();
    }
    try {
      // Stop native ringing at the user's answer intent, before network/SIP waits.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _native.updateCallState(_nativeCallUuid ?? _callId!, 'answering');
      }
      final response = await _api.callAction('accept', _callId!,
          idempotencyKey: 'accept-$_callId'); // POST /accept registers intent only
      if (response.isTerminal) { onServerState(response); return; }
      if (_incomingSipCallId == _callId) await _answerSipOnce(_callId!);
    } on ApiProblem catch (e) {
      if (e.code == 'CALL_ENDED' || e.code == 'CALL_EXPIRED') {
        _teardown(outcome: CallOutcome.cancelled);
      } else {
        _acceptFailed();
      }
    } catch (_) {
      _acceptFailed();
    }
  }

  void _acceptFailed() {
    // A lost response is not confirmation of acceptance. Require another tap
    // before answering a late INVITE; keep the original server deadline.
    if (_state != AppCallState.connecting) return;
    if (_callId != null) _answerIntents.remove(_callId);
    _state = AppCallState.incomingPending;
    _errorMessage = 'پاسخ تماس تأیید نشد؛ دوباره پاسخ دهید یا تماس را رد کنید.';
    notifyListeners();
  }

  Future<void> declineIncoming() async {
    if (_callId == null || _state == AppCallState.ending) return;
    final id = _callId!;
    final nativeId = _nativeCallUuid ?? id;
    _state = AppCallState.ending;
    notifyListeners();
    var confirmed = false;
    try {
      await _api.callAction('decline', id, idempotencyKey: 'decline-$id');
      confirmed = true;
    } on ApiProblem catch (e) {
      confirmed = e.code == 'CALL_ENDED' || e.code == 'CALL_EXPIRED';
    } catch (_) {
      // Reject the SIP leg even when the independent API path is unavailable.
    }
    try { await _sip.rejectPendingOnce(); } catch (_) { confirmed = false; }
    try { await _native.endCall(nativeId, 'declined'); } catch (_) { confirmed = false; }
    _teardown(outcome: CallOutcome.endedNormally);
    if (!confirmed) {
      _errorMessage = 'تأیید رد تماس کامل دریافت نشد؛ اتصال سرور را بررسی کنید.';
      notifyListeners();
    }
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
    try {
      await _native.updateCallState(_nativeCallUuid ?? id, 'answered');
      await _sip.answerPendingOnce();
    }
    catch (_) { _answeredSipCalls.remove(id); rethrow; }
  }

  Future<void> onForegroundCallHint() async {
    unawaited(refreshDirectory());
    await _reconcileWithServer();
  }

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
  void onSipRemoteEnded({bool failed = false}) {
    if (_state == AppCallState.connected ||
        _state == AppCallState.connecting ||
        _state == AppCallState.incomingPending ||
        _state == AppCallState.outgoingPending) {
      _teardown(outcome: failed ? CallOutcome.disconnected
          : _state == AppCallState.connected ? CallOutcome.endedNormally
          : CallOutcome.cancelled);
    }
  }

  /// Server-confirmed Connected (polled state). Timer starts on real connection.
  void onServerState(CallDto call) {
    final isCallee = call.callee == _extension;
    if (!isCallee && call.caller != _extension) return;
    if (_callId != call.callId && !call.isTerminal) _errorMessage = null;
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
          _errorMessage = null;
          _state = AppCallState.connected;
          _nativeCallUuid ??= call.callId;
          unawaited(_native.updateCallState(_nativeCallUuid!, 'connected').catchError((Object _) {
            if (_state == AppCallState.connected) unawaited(hangUp());
          }));
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
      await _native.reportIncoming(call.callId, call.caller, remoteName, call.expiresAt);
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
      } else if ([502, 503, 504].contains(e.status)) {
        _readySent.remove(call.callId);
      }
    } catch (_) {
      // Retry only within the existing pending window, using the same
      // idempotency key. Never let an unawaited transport error escape.
      _readySent.remove(call.callId);
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
      case 'Completed':
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
    final target = !_speakerOn;
    final id = _nativeCallUuid ?? _callId;
    try {
      if (id != null) await _native.setSpeaker(id, target);
      await _sip.setSpeaker(target);
      if (!_platformAudioRoute) _speakerOn = target;
    } catch (_) {
      _errorMessage = 'تغییر مسیر صدا انجام نشد؛ دستگاه صوتی را بررسی کنید.';
    }
    notifyListeners();
  }

  Future<void> hangUp() async {
    if (_state == AppCallState.ending) return;
    final id = _callId;
    _state = AppCallState.ending;
    notifyListeners();
    var sipEnded = false;
    var serverEnded = false;
    try {
      await _sip.hangUp();
      sipEnded = true;
    } catch (_) {
      // Still attempt the independent server backstop if the SIP engine fails.
    }
    if (id != null) {
      try {
        await _api.callAction('end', id, idempotencyKey: 'end-$id');
        serverEnded = true;
      } on ApiProblem catch (e) {
        serverEnded = e.code == 'CALL_ENDED' || e.code == 'CALL_EXPIRED';
      } catch (_) {
        // A timeout or transport failure must not strand the UI in Ending.
      }
    }
    _teardown(outcome: CallOutcome.endedNormally);
    if (!sipEnded || (id != null && !serverEnded)) {
      _errorMessage = 'تأیید پایان تماس کامل دریافت نشد؛ اتصال سرور را بررسی کنید.';
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _stopDirectoryWatch();
    await _sip.stop();
    await _api.logout().catchError((Object _) {/* local wipe proceeds; server revoke unconfirmed is reported */});
    await _store.wipe();
    _api.setToken(null); _extension=null; _directory=const []; _savedAccountAvailable=false;
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
    final epoch=_directoryEpoch;
    try {
      final call = await _api.currentCall(attemptId: _attemptId);
      if(_disposed || epoch!=_directoryEpoch)return;
      _controlReachable = true;
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
          _now().isAfter(call.expiresAt) && !call.isTerminal &&
          call.state != CallDtoState.connected) {
        // server deadline passed while UI still pending → clean failure (spec 5.3)
        _teardown(outcome: CallOutcome.unavailable);
        return;
      }
      onServerState(call);
    } on ApiProblem catch (e) {
      if(_disposed || epoch!=_directoryEpoch)return;
      _controlReachable = false;
      if (e.status == 401) {
        await _sessionRevoked();
      }
    } catch (_) {
      if(_disposed || epoch!=_directoryEpoch)return;
      _controlReachable = false;
      // network hiccup — deadline + SIP teardown still protect us (spec 5.5)
    }
  }

  void _teardown({required CallOutcome outcome, bool silent = false}) {
    final nativeId = _nativeCallUuid ?? _callId;
    if (nativeId != null) {
      unawaited(_native.endCall(nativeId, outcome.name).catchError((Object _) {
        debugPrint('SMI_NATIVE call cleanup not confirmed');
      }));
    }
    _platformAudioRoute = false;
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
    _stopDirectoryWatch();
    _pollTimer?.cancel();
    _nativeSub?.cancel();
    _native.stopListening();
    unawaited(_sip.stop().catchError((Object _) {
      debugPrint('SMI_STARTUP SIP shutdown failed');
    }));
    super.dispose();
  }
}
