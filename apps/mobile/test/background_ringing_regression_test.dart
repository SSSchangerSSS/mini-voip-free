import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';

import 'call_handshake_test.dart' show DirectNativeFixture, TestSip, callData;

class ReceptionNative extends DirectNativeFixture {
  final changes = <String>[];
  final capabilities = <Object?, Object?>{
    'directIncoming': true,
    'microphone': true,
    'fullScreenIntent': true,
    'notifications': true,
    'batteryUnrestricted': true,
    'standbyRunning': true,
    'incomingChannelEnabled': true,
  };
  @override
  Future<Map<Object?, Object?>> getCapabilities() async => capabilities;
  @override
  Future<void> updateCallState(String id, String state) async {
    changes.add('native:$state');
  }
}

ControlApiClient fixtureApi(Future<http.Response> Function(http.Request) rest) =>
    ControlApiClient(domain: 'fixture.invalid', client: MockClient((request) async {
      if (request.url.path.endsWith('/sessions')) {
        return http.Response(jsonEncode({
          'accessToken': 'fixture-token',
          'idleExpiresAt': '2027-01-01T00:00:00Z',
          'extension': '102', 'deviceGeneration': 1,
          'sipUri': 'sip:102@fixture.invalid', 'sipUsername': '102',
          'sipPassword': 'fixture-sip-password',
          'wssUrl': 'wss://fixture.invalid/ws', 'setupTimeoutSeconds': 40,
        }), 200);
      }
      if (request.url.path.endsWith('/extensions')) return http.Response('[]', 200);
      return rest(request);
    }));

void main() {
  test('answer silences native ringing before a slow accept response and SIP media', () async {
    final native = ReceptionNative();
    final sip = TestSip();
    final accept = Completer<http.Response>();
    final api = fixtureApi((request) async {
      if (request.url.path.endsWith('/accept')) {
        native.changes.add('http:accept');
        return accept.future;
      }
      return http.Response(jsonEncode(callData()), 200);
    });
    final controller = CallController(api: api, sip: sip, native: native,
        store: SecureCredentialStore(native));
    addTearDown(controller.dispose);
    await controller.signIn(domain: 'fixture.invalid', extension: '102', password: 'fixture-password');
    await controller.onSipIncoming(callData()['callId'] as String);
    final answering = controller.answerIncoming();
    await Future<void>.delayed(Duration.zero);
    expect(native.changes, ['native:answering', 'http:accept']);
    expect(sip.answered, 0);
    accept.complete(http.Response(jsonEncode(callData()), 200));
    await answering;
    expect(native.changes, ['native:answering', 'http:accept', 'native:answered']);
    expect(sip.answered, 1);
  });

  test('vendor settings remain unverified and fullscreen denial stays visible', () async {
    final native = ReceptionNative();
    native.capabilities['vendorBackgroundSetup'] = true;
    final controller = CallController(api: fixtureApi((_) async => http.Response('null', 200)),
      sip: TestSip(), native: native, store: SecureCredentialStore(native));
    addTearDown(controller.dispose);
    await controller.signIn(domain: 'fixture.invalid', extension: '102', password: 'fixture-password');
    await controller.checkDirectReception();
    expect(controller.receptionWarning, contains('HyperOS'));
    expect(controller.backgroundReceptionReady, isTrue); // connection readiness, not OEM approval
    native.capabilities['fullScreenIntent'] = false;
    await controller.checkDirectReception();
    expect(controller.receptionWarning, contains('تمام‌صفحه'));
  });

  for (final missing in ['microphone', 'notifications', 'batteryUnrestricted', 'standbyRunning', 'incomingChannelEnabled']) {
    test('standby does not advertise ready with missing $missing and recovers after settings change', () async {
      final native = ReceptionNative();
      native.capabilities[missing] = false;
      final controller = CallController(
        api: fixtureApi((_) async => http.Response('null', 200)),
        sip: TestSip(), native: native, store: SecureCredentialStore(native),
      );
      addTearDown(controller.dispose);
      await controller.signIn(domain: 'fixture.invalid', extension: '102', password: 'fixture-password');
      await controller.checkDirectReception();
      expect(controller.backgroundReceptionReady, isFalse);
      expect(controller.receptionWarning, isNotNull);
      expect(native.statuses.last, isFalse);
      native.capabilities[missing] = true;
      await controller.checkDirectReception();
      expect(controller.backgroundReceptionReady, isTrue);
      expect(controller.receptionWarning, isNull);
      expect(native.statuses.last, isTrue);
    });
  }
}
