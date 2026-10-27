import 'dart:async';

import 'package:flutter/services.dart';

import 'native_event_queue.dart';

/// Typed Flutter↔native bridge for the FIXED channel `smi.phone/native/v1`
/// (spec 10.2). Exactly one owner dispatcher exists in the app (this class);
/// no second singleton may claim the EventChannel.
class NativeCallBridge {
  static const MethodChannel _methods = MethodChannel('smi.phone/native/v1');
  static const EventChannel _events = EventChannel('smi.phone/native/v1/events');

  StreamSubscription<Object?>? _sub;
  final StreamController<NativeEvent> _stream =
      StreamController<NativeEvent>.broadcast();

  Stream<NativeEvent> get events => _stream.stream;

  void startListening() {
    _sub ??= _events.receiveBroadcastStream().listen((payload) {
      final e = NativeEvent.tryParse(payload);
      if (e != null) _stream.add(e);
    }, onError: (Object err) {
      // malformed platform payloads must not crash the app (spec 9.1)
      _stream.add(NativeEvent(type: NativeEventType.capabilityChanged,
          eventId: 'bridge-error-${DateTime.now().millisecondsSinceEpoch}'));
    });
  }

  Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> configure({required String domain}) =>
      _methods.invokeMethod('configure', {'domain': domain});

  Future<Map<Object?, Object?>> getCapabilities() async {
    final res = await _methods.invokeMethod('getCapabilities');
    return (res as Map<Object?, Object?>?) ?? <Object?, Object?>{};
  }

  Future<String?> getPushToken() => _methods.invokeMethod<String>('getPushToken');

  /// Outgoing native call UUID = attemptId for the entire call lifetime (spec 9.3).
  Future<void> reportOutgoing(String attemptId) =>
      _methods.invokeMethod('reportOutgoing', {'attemptId': attemptId});

  Future<void> updateCallState(String nativeCallUuid, String state) =>
      _methods.invokeMethod('updateCallState',
          {'nativeCallUuid': nativeCallUuid, 'state': state});

  Future<void> endCall(String nativeCallUuid, String reason) =>
      _methods.invokeMethod('endCall',
          {'nativeCallUuid': nativeCallUuid, 'reason': reason});

  Future<void> setMuted(String nativeCallUuid, bool muted) =>
      _methods.invokeMethod('setMuted',
          {'nativeCallUuid': nativeCallUuid, 'muted': muted});

  Future<void> setSpeaker(String nativeCallUuid, bool speakerOn) =>
      _methods.invokeMethod('setSpeaker',
          {'nativeCallUuid': nativeCallUuid, 'speakerOn': speakerOn});

  Future<List<NativeEvent>> getPendingEvents() async {
    final res = await _methods.invokeMethod<List<Object?>>('getPendingEvents');
    return (res ?? const [])
        .map(NativeEvent.tryParse)
        .whereType<NativeEvent>()
        .toList();
  }

  Future<void> ackEvent(String eventId) =>
      _methods.invokeMethod('ackEvent', {'eventId': eventId});

  // secure store ops flow through the same bridge (Android Keystore / iOS Keychain)
  Future<String?> secureRead(String key) =>
      _methods.invokeMethod<String>('secureStore', {'op': 'read', 'key': key});

  Future<void> secureWrite(String key, String value) =>
      _methods.invokeMethod('secureStore', {'op': 'write', 'key': key, 'value': value});

  Future<void> secureDelete(String key) =>
      _methods.invokeMethod('secureStore', {'op': 'delete', 'key': key});
}

enum NativeEventType {
  incomingReported,
  answerRequested,
  declineRequested,
  endRequested,
  audioActivated,
  audioDeactivated,
  pushTokenChanged,
  nativeCallReset,
  capabilityChanged,
}

class NativeEvent {
  final String eventId;
  final NativeEventType type;
  final String? callId;
  final String? callerExtension;
  final int? deviceGeneration;
  final DateTime? expiresAt;
  final String? pushToken;

  const NativeEvent({
    required this.eventId,
    required this.type,
    this.callId,
    this.callerExtension,
    this.deviceGeneration,
    this.expiresAt,
    this.pushToken,
  });

  static NativeEvent? tryParse(Object? payload) {
    if (payload is! Map) return null;
    final typeName = payload['type'];
    if (typeName is! String) return null;
    final NativeEventType type;
    try {
      type = NativeEventType.values
          .firstWhere((t) => t.name == typeName, orElse: () => throw StateError('x'));
    } on StateError {
      return null; // unknown type — ignored defensively (spec 10.2)
    }
    final id = payload['eventId'];
    return NativeEvent(
      eventId: id is String ? id : 'evt-${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      callId: payload['callId'] is String ? payload['callId'] as String : null,
      callerExtension: payload['callerExtension'] is String
          ? payload['callerExtension'] as String
          : null,
      deviceGeneration: payload['deviceGeneration'] is int
          ? payload['deviceGeneration'] as int
          : null,
      expiresAt: payload['expiresAt'] is String
          ? DateTime.tryParse(payload['expiresAt'] as String)
          : null,
      pushToken: payload['pushToken'] is String ? payload['pushToken'] as String : null,
    );
  }
}
