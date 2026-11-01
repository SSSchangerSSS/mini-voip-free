import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/api_models.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';

import 'call_handshake_test.dart' show MemoryNative, TestSip, callData;

class FailingCallSip extends TestSip {
  bool failHangup = false;
  int hangups = 0;
  @override
  Future<void> hangUp() async {
    hangups++;
    if (failHangup) throw StateError('fixture SIP failure');
  }
}

class CallNative extends MemoryNative {
  @override
  Future<void> endCall(String id, String reason) async {}
}

void main() {
  for (final failSip in [false, true]) {
    test('hangup releases UI and attempts API when SIP failure=$failSip', () async {
      final sip = FailingCallSip()..failHangup = failSip;
      final native = MemoryNative();
      var endRequests = 0;
      final api = ControlApiClient(domain: '192.168.1.151', client: MockClient((r) async {
        if (r.url.path.endsWith('/sessions')) {
          return http.Response(jsonEncode({
            'accessToken': 'fixture-token', 'idleExpiresAt': '2027-01-01T00:00:00Z',
            'extension': '102', 'deviceGeneration': 1, 'sipUri': 'sip:102@192.168.1.151',
            'sipUsername': '102', 'sipPassword': 'fixture-sip-password',
            'wssUrl': 'wss://192.168.1.151/ws', 'setupTimeoutSeconds': 40,
          }), 200);
        }
        if (r.method == 'PUT') return http.Response('', 204);
        if (r.url.path.endsWith('/end')) {
          endRequests++;
          throw TimeoutException('fixture network timeout');
        }
        return http.Response('null', 200);
      }));
      final c = CallController(api: api, sip: sip, native: native,
          store: SecureCredentialStore(native));
      addTearDown(c.dispose);
      await c.signIn(domain: '192.168.1.151', extension: '102', password: 'fixture-password');
      c.onServerState(CallDto.fromJson({...callData(), 'state': 'Connected'}));
      expect(c.state, AppCallState.connected);
      await c.hangUp();
      expect(sip.hangups, 1);
      expect(endRequests, 1);
      expect(c.state, AppCallState.idle);
      expect(c.callId, isNull);
      expect(c.errorMessage, contains('پایان تماس'));
    });
  }
  for (final action in ['accept', 'decline', 'ready']) {
    test('$action handles a lost control connection without an uncaught error', () async {
      final native = CallNative();
      final sip = FailingCallSip();
      var actionRequests = 0;
      Map<String, dynamic>? active;
      final api = ControlApiClient(domain: '192.168.1.151', client: MockClient((r) async {
        if (r.url.path.endsWith('/sessions')) {
          return http.Response(jsonEncode({
            'accessToken': 'fixture-token', 'idleExpiresAt': '2027-01-01T00:00:00Z',
            'extension': '102', 'deviceGeneration': 1, 'sipUri': 'sip:102@192.168.1.151',
            'sipUsername': '102', 'sipPassword': 'fixture-sip-password',
            'wssUrl': 'wss://192.168.1.151/ws', 'setupTimeoutSeconds': 40,
          }), 200);
        }
        if (r.method == 'PUT') return http.Response('', 204);
        if (r.url.path.endsWith('/$action')) {
          actionRequests++;
          if (actionRequests == 1) throw http.ClientException('fixture offline');
        }
        return http.Response(jsonEncode(active), 200);
      }));
      final c = CallController(api: api, sip: sip, native: native,
          store: SecureCredentialStore(native));
      addTearDown(c.dispose);
      await c.signIn(domain: '192.168.1.151', extension: '102', password: 'fixture-password');
      active = callData();
      await c.onForegroundCallHint();
      await Future<void>.delayed(Duration.zero);
      if (action == 'ready') {
        await c.onForegroundCallHint();
        await Future<void>.delayed(Duration.zero);
        expect(actionRequests, 2, reason: 'A failed ready must be retryable with the same key');
      } else if (action == 'accept') {
        await c.answerIncoming();
        expect(c.state, AppCallState.incomingPending);
        expect(c.errorMessage, isNotNull);
        await c.onSipIncoming(active['callId'] as String);
        expect(sip.answered, 0, reason: 'An unconfirmed accept must not auto-answer a late INVITE');
        await c.answerIncoming();
        expect(sip.answered, 1);
        expect(c.errorMessage, isNull, reason: 'A successful retry clears the old accept error');
      } else {
        await c.declineIncoming();
        expect(c.state, AppCallState.idle);
        expect(c.callId, isNull);
        expect(sip.rejected, 1, reason: 'The independent SIP rejection must still run');
      }
    });
  }

}
