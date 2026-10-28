import 'package:flutter_test/flutter_test.dart';
import 'package:smi_phone/api/api_models.dart';
import 'package:smi_phone/native/native_call_bridge.dart';
import 'package:smi_phone/native/native_event_queue.dart';

void main() {
  group('NativeEventQueue (spec 10.1)', () {
    test('dedupes by eventId and acks exactly once', () {
      final q = NativeEventQueue();
      final e = const NativeEvent(eventId: 'e1', type: NativeEventType.incomingReported);
      expect(q.enqueue(e), isTrue);
      expect(q.enqueue(e), isFalse); // duplicate ignored
      expect(q.length, 1);
      expect(q.ack('e1'), isTrue);
      expect(q.length, 0);
      expect(q.enqueue(e), isFalse); // already acked — replay cannot revive it
    });

    test('caps at 64 and drops the oldest (spec 10.1)', () {
      final q = NativeEventQueue();
      for (var i = 0; i < 70; i++) {
        q.enqueue(NativeEvent(eventId: 'e$i', type: NativeEventType.capabilityChanged));
      }
      expect(q.length, NativeEventQueue.capacity);
      expect(q.snapshot.first.eventId, 'e6'); // e0..e5 dropped
    });

    test('parses known events and ignores unknown types defensively', () {
      final good = NativeEvent.tryParse({
        'eventId': 'a',
        'type': 'incomingReported',
        'callId': 'x',
        'callerExtension': '101',
        'deviceGeneration': 1,
        'expiresAt': '2026-10-27T06:00:40Z',
      });
      expect(good, isNotNull);
      expect(good!.type, NativeEventType.incomingReported);
      expect(NativeEvent.tryParse({'eventId': 'b', 'type': 'someFutureEvent'}), isNull);
      expect(NativeEvent.tryParse(null), isNull);
      expect(NativeEvent.tryParse('garbage'), isNull);
    });
  });

  group('CallDto parsing (wire contract, camelCase)', () {
    test('parses the spec example', () {
      final c = CallDto.fromJson({
        'callId': '1450d21c-c471-492d-89cd-2e58c6638b64',
        'attemptId': 'c675277e-f71b-4d69-91a9-25e6a9ef1230',
        'caller': '101',
        'callee': '102',
        'state': 'Pending',
        'deviceGeneration': 1,
        'revision': 3,
        'createdAt': '2026-10-27T06:00:00Z',
        'expiresAt': '2026-10-27T06:00:40Z',
        'acceptedAt': null,
        'connectedAt': null,
        'endedAt': null,
        'endReason': null,
        'serverTime': '2026-10-27T06:00:03Z',
      });
      expect(c.state, CallDtoState.pending);
      expect(c.isTerminal, isFalse);
      expect(c.deviceGeneration, 1);
    });

    test('maps Ended/Declined to terminal', () {
      final c = CallDto.fromJson({
        'callId': 'x', 'attemptId': 'y', 'caller': '101', 'callee': '102',
        'state': 'Ended', 'deviceGeneration': 1, 'revision': 9,
        'createdAt': '2026-10-27T06:00:00Z', 'expiresAt': '2026-10-27T06:00:40Z',
        'acceptedAt': null, 'connectedAt': null, 'endedAt': '2026-10-27T06:00:20Z',
        'endReason': 'Declined',
      });
      expect(c.isTerminal, isTrue);
      expect(c.endReason, 'Declined');
    });
  });
}
