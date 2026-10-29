import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'call_handshake_test.dart' show MemoryNative;
import 'package:flutter_test/flutter_test.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:smi_phone/sip/sip_adapter.dart';

class CapturingHelper extends SIPUAHelper {
  UaSettings? settings;
  List<String>? headers;
  bool? voiceOnly;
  @override Future<void> start(UaSettings settings) async {
    this.settings = settings;
    throw StateError('fixture startup failure');
  }
  @override Future<bool> call(String target, {bool voiceOnly = false,
      dynamic mediaStream, List<String>? headers, Map<String,dynamic>? customOptions}) async {
    this.headers = headers; this.voiceOnly = voiceOnly; return true;
  }
}
class HintRequest { HintRequest(this.body); final String body; }
void main() {
  test('remote fixed SIP MESSAGE triggers authenticated reconcile; unrelated bodies do not', () async {
    var requests=0; final native=MemoryNative(); final adapter=SipAdapter();
    final controller=CallController(
      api:ControlApiClient(domain:'192.168.1.151',client:MockClient((r) async { requests++; return http.Response('null',200); })),
      sip:adapter,native:native,store:SecureCredentialStore(native));
    addTearDown(controller.dispose); adapter.bind(controller);
    adapter.onNewMessage(SIPMessageRequest(null,Originator.remote,HintRequest('other')));
    adapter.onNewMessage(SIPMessageRequest(null,Originator.local,HintRequest('smi-call')));
    await Future<void>.delayed(Duration.zero); expect(requests,0);
    adapter.onNewMessage(SIPMessageRequest(null,Originator.remote,HintRequest('smi-call')));
    await Future<void>.delayed(Duration.zero); expect(requests,1);
  });
  test('WS transport is explicit, TLS remains verified, startup errors propagate', () async {
    final helper=CapturingHelper(); final adapter=SipAdapter(helper:helper);
    await adapter.configure(domain:'192.168.1.151',username:'101',password:'fixture-sip-only');
    await expectLater(adapter.start(),throwsStateError);
    expect(helper.settings!.transportType,TransportType.WS);
    expect(helper.settings!.webSocketUrl,'wss://192.168.1.151/ws');
    expect(helper.settings!.webSocketSettings.allowBadCertificate,isFalse);
    expect(helper.settings!.password,'fixture-sip-only');
  });
  test('outgoing INVITE carries attempt UUID and stays audio-only', () async {
    final helper=CapturingHelper(); final adapter=SipAdapter(helper:helper);
    await adapter.call('sip:102@192.168.1.151',attemptId:'11111111-1111-4111-8111-111111111111');
    expect(helper.headers,['X-SMI-Attempt-ID: 11111111-1111-4111-8111-111111111111']);
    expect(helper.voiceOnly,isTrue);
  });
}
