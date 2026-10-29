import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smi_phone/native/native_call_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('smi.phone/native/v1');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('replays the Android JSON backlog without a type cast crash', () async {
    messenger.setMockMethodCallHandler(channel, (call) async =>
        '[{"eventId":"ans-1","type":"answerRequested",'
        '"payload":{"callId":"call-1"}}]');
    final events = await NativeCallBridge().getPendingEvents();
    expect(events.single.eventId, 'ans-1');
    expect(events.single.callId, 'call-1');
    expect(events.single.type, NativeEventType.answerRequested);
  });

  test('accepts the contract list and safely handles malformed legacy JSON', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => [
      {'eventId': 'end-1', 'type': 'endRequested', 'callId': 'call-1'}
    ]);
    expect((await NativeCallBridge().getPendingEvents()).single.callId, 'call-1');
    messenger.setMockMethodCallHandler(channel, (call) async => 'broken');
    expect(await NativeCallBridge().getPendingEvents(), isEmpty);
  });

  test('legacy incoming expiry uses UTC and preserves contract fields', () {
    final event = NativeEvent.tryParse({
      'eventId': 'inc-1', 'type': 'incomingReported', 'callId': 'current',
      'payload': {'callId': 'legacy', 'callerExtension': '101', 'expiresAtEpoch': 1000}
    })!;
    expect(event.callId, 'current');
    expect(event.callerExtension, '101');
    expect(event.expiresAt, DateTime.fromMillisecondsSinceEpoch(1000000, isUtc: true));
  });
}
