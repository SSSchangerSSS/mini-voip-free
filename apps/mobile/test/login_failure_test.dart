import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/native/native_call_bridge.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'package:smi_phone/sip/sip_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('smi.phone/native/v1');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('failed network login returns to error rather than leaving spinner active', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final bridge = NativeCallBridge();
    final controller = CallController(
      api: ControlApiClient(domain: '192.168.1.151',
          client: MockClient((request) async => throw http.ClientException('fixture network failure'))),
      sip: SipAdapter(), native: bridge, store: SecureCredentialStore(bridge),
    );
    addTearDown(controller.dispose);
    expect(await controller.signIn(domain: '192.168.1.151',
        extension: '101', password: 'fixture-only'), isFalse);
    expect(controller.state, AppCallState.error);
    expect(controller.errorMessage, isNotEmpty);
    expect(controller.errorMessage, isNot(contains('fixture network failure')));
  });

  test('unavailable secure store is handled before any network request', () async {
    messenger.setMockMethodCallHandler(channel, (call) async =>
        throw PlatformException(code: 'STORE_UNAVAILABLE'));
    var requests = 0;
    final bridge = NativeCallBridge();
    final controller = CallController(
      api: ControlApiClient(domain: '192.168.1.151', client: MockClient((request) async {
        requests++;
        return http.Response('{}', 500);
      })),
      sip: SipAdapter(), native: bridge, store: SecureCredentialStore(bridge),
    );
    addTearDown(controller.dispose);
    expect(await controller.signIn(domain: '192.168.1.151',
        extension: '101', password: 'fixture-only'), isFalse);
    expect(controller.state, AppCallState.error);
    expect(requests, 0);
  });
}
