import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/native/native_call_bridge.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'package:smi_phone/sip/sip_adapter.dart';

class MemoryNative extends NativeCallBridge {
  final values = <String, String>{};
  @override Future<String?> secureRead(String key) async => values[key];
  @override Future<void> secureWrite(String key, String value) async { values[key] = value; }
  @override Future<void> secureDelete(String key) async { values.remove(key); }
  @override Future<void> configure({required String domain}) async {}
  @override void startListening() {}
  @override Future<void> stopListening() async {}
  @override Future<List<NativeEvent>> getPendingEvents() async => [];
  @override Future<String?> getPushToken() async => null;
  @override Future<void> reportOutgoing(String attemptId) async {}
}
class TestSip extends SipAdapter {
  String? password;
  String? attempt;
  int answered = 0;
  int rejected = 0;
  @override bool get registered => true;
  @override String get domain => '192.168.1.151';
  @override Future<void> configure({required String domain, required String username, required String password}) async { this.password = password; }
  @override Future<void> start() async {}
  @override Future<void> stop() async {}
  @override Future<void> call(String targetUri, {required String attemptId}) async { attempt = attemptId; }
  @override Future<void> answerPendingOnce() async { answered++; }
  @override Future<void> rejectPendingOnce() async { rejected++; }
}

Map<String,dynamic> callData() => {
  'callId':'11111111-1111-4111-8111-111111111111',
  'attemptId':'22222222-2222-4222-8222-222222222222',
  'caller':'101','callee':'102','deviceGeneration':1,'state':'Pending','revision':1,
  'createdAt':DateTime.now().toUtc().toIso8601String(),
  'expiresAt':DateTime.now().toUtc().add(const Duration(seconds:40)).toIso8601String(),
};
void main() {
  test('separate SIP credential is stored and configured; admission race preserves outgoing attempt', () async {
    final native=MemoryNative(); final sip=TestSip();
    final api=ControlApiClient(domain:'192.168.1.151',client:MockClient((r) async {
      if(r.url.path.endsWith('/sessions')) { return http.Response(jsonEncode({
        'accessToken':'fixture-token','idleExpiresAt':'2027-01-01T00:00:00Z',
        'extension':'101','deviceGeneration':2,'sipUri':'sip:101@192.168.1.151',
        'sipUsername':'101','sipPassword':'fixture-sip-credential-is-distinct',
        'wssUrl':'wss://192.168.1.151/ws','setupTimeoutSeconds':40}),200); }
      if(r.method=='PUT') { return http.Response('',204); }
      return http.Response('null',200);
    }));
    final c=CallController(api:api,sip:sip,native:native,store:SecureCredentialStore(native));
    addTearDown(c.dispose);
    expect(await c.signIn(domain:'192.168.1.151',extension:'101',password:'fixture-account-password'),isTrue);
    expect(sip.password,'fixture-sip-credential-is-distinct');
    expect(native.values['smi.password'],'fixture-account-password');
    expect(native.values['smi.sipPassword'],sip.password);
    expect(await c.placeCall('102'),isTrue);
    expect(sip.attempt,matches(RegExp(r'^[0-9a-f-]{36}$')));
    await c.onForegroundCallHint();
    expect(c.state,AppCallState.outgoingPending);
  });

  test('foreground hint gates ready; matching INVITE does not answer before user intent', () async {
    final native=MemoryNative(); final sip=TestSip(); Map<String,dynamic>? active;
    var ready=0;
    final api=ControlApiClient(domain:'192.168.1.151',client:MockClient((r) async {
      if(r.url.path.endsWith('/sessions')) { return http.Response(jsonEncode({
        'accessToken':'fixture-token','idleExpiresAt':'2027-01-01T00:00:00Z',
        'extension':'102','deviceGeneration':1,'sipUri':'sip:102@192.168.1.151',
        'sipUsername':'102','sipPassword':'fixture-sip-credential-is-distinct',
        'wssUrl':'wss://192.168.1.151/ws','setupTimeoutSeconds':40}),200); }
      if(r.method=='PUT') { return http.Response('',204); }
      if(r.url.path.endsWith('/ready')) ready++;
      return http.Response(jsonEncode(active),200);
    }));
    final c=CallController(api:api,sip:sip,native:native,store:SecureCredentialStore(native));
    addTearDown(c.dispose);
    await c.signIn(domain:'192.168.1.151',extension:'102',password:'fixture-account-password');
    active=callData();
    await c.onForegroundCallHint();
    expect(c.state,AppCallState.incomingPending);
    await c.onSipIncoming(active['callId'] as String);
    expect(ready,1);
    expect(sip.answered,0);
    await c.answerIncoming();
    await c.answerIncoming();
    expect(sip.answered,1);
  });
}
