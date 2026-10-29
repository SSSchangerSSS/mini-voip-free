import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/main.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'call_handshake_test.dart' show MemoryNative, TestSip;

const installation = '11111111-2222-4333-8444-555555555555';
const accountPassword = 'fixture-account-private';
http.Response loginReply() => http.Response(jsonEncode({
  'accessToken':'fixture-token-private','idleExpiresAt':'2027-01-01T00:00:00Z',
  'extension':'102','deviceGeneration':1,'sipUri':'sip:102@192.168.1.151',
  'sipUsername':'102','sipPassword':'fixture-sip-private',
  'wssUrl':'wss://192.168.1.151/ws','setupTimeoutSeconds':40,
}),200);
Future<MemoryNative> savedNative() async {
  final native=MemoryNative();
  await SecureCredentialStore(native).saveAccount(domain:'192.168.1.151',
      extension:'102',password:accountPassword,sipPassword:'fixture-old-sip',
      installationId:installation);
  return native;
}
CallController controllerFor(MemoryNative native,
    Future<http.Response> Function(http.Request) login, {
    TestSip? sip, Future<void> Function(Duration)? delay,
}) => CallController(
  api:ControlApiClient(domain:'192.168.1.151',client:MockClient((r) async {
    if(r.url.path.endsWith('/sessions')) { return login(r); }
    return http.Response(r.method=='PUT' ? '' : 'null',r.method=='PUT' ? 204 : 200);
  })),sip:sip??TestSip(),native:native,store:SecureCredentialStore(native),
  restoreDelay:delay??(_) async {},
);
class FlakySip extends TestSip {
  int starts=0,stops=0;
  @override Future<void> start() async {
    starts++;
    if(starts==1) { throw TimeoutException('fixture SIP startup timeout'); }
  }
  @override Future<void> stop() async {stops++;}
}
class FailedCleanupSip extends TestSip {
  int starts=0,stops=0;
  @override Future<void> start() async {
    starts++;
    throw TimeoutException('fixture startup failure');
  }
  @override Future<void> stop() async {
    stops++;
    throw StateError('fixture cleanup failure');
  }
}
class BrokenStore extends MemoryNative {
  @override Future<String?> secureRead(String key) async =>
      throw PlatformException(code:'STORE_UNAVAILABLE',message:'fixture-sensitive-native');
}
void main() {
  test('transient startup retries keep installation/password and redact diagnostics', () async {
    final native=await savedNative();var requests=0;final ids=<String>[];final delays=<Duration>[];
    final logs=<String>[];final originalPrint=debugPrint;
    debugPrint=(message,{wrapWidth}) {logs.add(message??'');};
    addTearDown(()=>debugPrint=originalPrint);
    final c=controllerFor(native,(r) async {
      ids.add(jsonDecode(r.body)['installationId'] as String);
      requests++;
      if(requests<3) {throw const SocketException('fixture-sensitive-network');}
      return loginReply();
    },delay:(d) async {delays.add(d);});addTearDown(c.dispose);
    await c.restoreSession();
    expect(requests,3);expect(ids.every((id)=>id==installation),isTrue);
    expect(delays,[const Duration(seconds:2),const Duration(seconds:5)]);
    expect(c.state,AppCallState.idle);expect(c.restoringAccount,isFalse);
    expect(native.values['smi.password'],accountPassword);
    expect(native.values['smi.sipPassword'],'fixture-sip-private');
    final text=logs.join('\n');expect(text,contains('stage=api-login kind=network'));
    for(final value in [accountPassword,'fixture-token-private','fixture-sip-private','fixture-sensitive-network']) {
      expect(text,isNot(contains(value)));
    }
  });
  for(final item in {401:'INVALID_CREDENTIALS',409:'DEVICE_ALREADY_BOUND',429:'RATE_LIMITED'}.entries) {
    test('HTTP ${item.key} never retries stored credentials', () async {
      final native=await savedNative();var requests=0,delays=0;
      final c=controllerFor(native,(r) async {requests++;return http.Response(jsonEncode({'code':item.value}),item.key);},
          delay:(_) async {delays++;});addTearDown(c.dispose);
      await c.restoreSession();expect(requests,1);expect(delays,0);
      expect(c.state,AppCallState.error);expect(c.canRetrySavedAccount,isFalse);
      expect(native.values['smi.installationId'],installation);
    });
  }
  test('invalid TLS never retries or exposes exception text', () async {
    final native=await savedNative();var requests=0,delays=0;
    final c=controllerFor(native,(r) async {requests++;throw const HandshakeException('fixture-sensitive-cert');},
        delay:(_) async {delays++;});addTearDown(c.dispose);
    await c.restoreSession();expect(requests,1);expect(delays,0);
    expect(c.startupFailureKind,'tls');expect(c.canRetrySavedAccount,isFalse);
    expect(c.errorMessage,isNot(contains('fixture-sensitive-cert')));
  });
  test('persistent outage stops after three attempts; explicit retry reuses account', () async {
    final native=await savedNative();var requests=0;var online=false;
    final c=controllerFor(native,(r) async {requests++;if(!online) {throw const SocketException('offline');}return loginReply();});
    addTearDown(c.dispose);await c.restoreSession();
    expect(requests,3);expect(c.state,AppCallState.error);expect(c.canRetrySavedAccount,isTrue);
    expect(native.values['smi.password'],accountPassword);
    online=true;await c.restoreSession();expect(requests,4);expect(c.state,AppCallState.idle);
    expect(native.values['smi.installationId'],installation);
  });
  test('temporary HTTP 503 recovers with the same stored identity', () async {
    final native=await savedNative();var requests=0;
    final c=controllerFor(native,(r) async {requests++;
      return requests==1 ? http.Response('{"code":"INTERNAL"}',503) : loginReply();});
    addTearDown(c.dispose);await c.restoreSession();expect(requests,2);
    expect(c.state,AppCallState.idle);expect(native.values['smi.installationId'],installation);
  });
  test('registration timeout closes failed engine before retry', () async {
    final native=await savedNative();final sip=FlakySip();
    final c=controllerFor(native,(r) async=>loginReply(),sip:sip);addTearDown(c.dispose);
    await c.restoreSession();expect(sip.starts,2);expect(sip.stops,1);
    expect(c.state,AppCallState.idle);
  });
  test('failed SIP cleanup prevents another startup engine', () async {
    final native=await savedNative();final sip=FailedCleanupSip();var requests=0;
    final c=controllerFor(native,(r) async {requests++;return loginReply();},sip:sip);
    addTearDown(c.dispose);await c.restoreSession();
    expect(requests,1);expect(sip.starts,1);expect(sip.stops,1);
    expect(c.state,AppCallState.error);expect(c.canRetrySavedAccount,isFalse);
    expect(native.values['smi.installationId'],installation);
  });
  test('fresh install and inaccessible store never invent or replace credentials', () async {
    for(final native in [MemoryNative(),BrokenStore()]) {
      var requests=0;final c=controllerFor(native,(r) async {requests++;return loginReply();});
      await c.restoreSession();expect(requests,0);
      expect(c.state,native is BrokenStore ? AppCallState.error : AppCallState.unconfigured);
      expect(c.restoringAccount,isFalse);expect(native.values,isEmpty);c.dispose();
    }
  });
  test('concurrent restores coalesce and dispose cancels backoff', () async {
    final native=await savedNative();final waiting=Completer<void>();var requests=0;
    final c=controllerFor(native,(r) async {requests++;throw const SocketException('offline');},delay:(_)=>waiting.future);
    final pending=c.restoreSession();
    while(requests==0) {await Future<void>.delayed(Duration.zero);}
    await Future<void>.delayed(Duration.zero);await c.restoreSession();expect(requests,1);
    c.dispose();waiting.complete();await pending;expect(requests,1);
  });
  testWidgets('retry backoff shows restoring UI rather than a failed login form', (tester) async {
    final native=await savedNative();final waiting=Completer<void>();var requests=0;
    final c=controllerFor(native,(r) async {requests++;if(requests==1) {throw const SocketException('offline');}return loginReply();},
        delay:(_)=>waiting.future);
    final pending=c.restoreSession();await tester.pumpWidget(MiniVoipApp(controller:c));
    await tester.pump();await tester.pump();
    expect(find.text('در حال بازیابی حساب…'),findsOneWidget);
    expect(find.text('ورود'),findsNothing);
    waiting.complete();await pending;await tester.pump();expect(find.text('تماس'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());c.dispose();await tester.pump();
  });
  testWidgets('saved-account retry button recovers without typing password', (tester) async {
    final native=await savedNative();var online=false;var requests=0;
    final c=controllerFor(native,(r) async {requests++;if(!online) {throw const SocketException('offline');}return loginReply();});
    await c.restoreSession();await tester.pumpWidget(MiniVoipApp(controller:c));
    expect(find.text('تلاش مجدد با حساب ذخیره‌شده'),findsOneWidget);
    online=true;await tester.tap(find.text('تلاش مجدد با حساب ذخیره‌شده'));
    await tester.pump();await tester.pump();await tester.pump();
    expect(requests,4);expect(c.state,AppCallState.idle);
    await tester.pumpWidget(const SizedBox.shrink());c.dispose();await tester.pump();
  });
}
