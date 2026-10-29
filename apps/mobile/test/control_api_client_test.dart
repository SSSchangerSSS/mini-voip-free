import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';

void main() {
  test('unresponsive server has a bounded request deadline', () async {
    final api = ControlApiClient(domain: '192.168.1.151',
        requestTimeout: const Duration(milliseconds: 10),
        client: MockClient((request) => Completer<http.Response>().future));
    await expectLater(api.currentCall(), throwsA(isA<TimeoutException>()));
  });

  test('JSON requests declare JSON rather than form/text content', () async {
    final requests = <http.Request>[];
    final api = ControlApiClient(domain: '192.168.1.244', client: MockClient((request) async {
      requests.add(request);
      return http.Response('{"code":"INVALID_CREDENTIALS"}', 401);
    }));
    await expectLater(api.login(extension: '101', password: 'test-only',
        installationId: 'test-installation', platform: 'android'), throwsA(isA<Exception>()));
    await expectLater(api.registerPush(provider: 'fcm', token: '', environment: 'production'),
        throwsA(isA<Exception>()));
    await expectLater(api.callAction('end', 'test-call'), throwsA(isA<Exception>()));
    expect(requests, hasLength(3));
    for (final request in requests) {
      expect(request.headers['content-type'], startsWith('application/json'));
      expect(request.url.scheme, 'https');
      expect(request.url.host, '192.168.1.244');
    }
  });
}
