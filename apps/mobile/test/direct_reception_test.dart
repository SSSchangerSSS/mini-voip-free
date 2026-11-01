import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'call_handshake_test.dart' show DirectNativeFixture,TestSip,callData;
class LostMediaSip extends TestSip {
 @override bool get hasActiveCall=>false;
 @override Future<void> hangUp()async{}
}
void main(){
 test('direct standby binds no Google token and discovers incoming call without SIP hint',()async{
  final native=DirectNativeFixture();final sip=TestSip();Map<String,dynamic>? active;var ready=0;var pushRequests=0;
  final api=ControlApiClient(domain:'fixture.invalid',client:MockClient((r)async{
   if(r.url.path.endsWith('/sessions'))return http.Response(jsonEncode({'accessToken':'fixture-token','idleExpiresAt':'2027-01-01T00:00:00Z','extension':'102','deviceGeneration':1,'sipUri':'sip:102@fixture.invalid','sipUsername':'102','sipPassword':'fixture-sip-password','wssUrl':'wss://fixture.invalid/ws','setupTimeoutSeconds':40}),200);
   if(r.url.path.endsWith('/push')){pushRequests++;return http.Response('',204);}
   if(r.url.path.endsWith('/extensions'))return http.Response('[]',200);
   if(r.url.path.endsWith('/ready'))ready++;
   return http.Response(jsonEncode(active),200);
  }));
  final c=CallController(api:api,sip:sip,native:native,store:SecureCredentialStore(native));addTearDown(c.dispose);
  expect(await c.signIn(domain:'fixture.invalid',extension:'102',password:'fixture-password'),true);
  expect(c.state,AppCallState.idle);expect(c.errorMessage,isNull);expect(native.tokenReads,0);expect(pushRequests,0);
  active=callData();await c.checkDirectReception();await Future<void>.delayed(Duration.zero);
  expect(c.state,AppCallState.incomingPending);expect(ready,1);expect(native.statuses.last,true);expect(sip.answered,0);
 });
 test('direct heartbeat does not expire an established call at its setup deadline',()async{
  final native=DirectNativeFixture();final sip=TestSip();var now=DateTime.now().toUtc();
  final active={...callData(),'state':'Connected'};
  final api=ControlApiClient(domain:'fixture.invalid',client:MockClient((r)async{
   if(r.url.path.endsWith('/sessions'))return http.Response(jsonEncode({'accessToken':'fixture-token','idleExpiresAt':'2027-01-01T00:00:00Z','extension':'102','deviceGeneration':1,'sipUri':'sip:102@fixture.invalid','sipUsername':'102','sipPassword':'fixture-sip-password','wssUrl':'wss://fixture.invalid/ws','setupTimeoutSeconds':40}),200);
   if(r.url.path.endsWith('/extensions'))return http.Response('[]',200);
   return http.Response(jsonEncode(active),200);
  }));
  final c=CallController(api:api,sip:sip,native:native,store:SecureCredentialStore(native),clock:()=>now);addTearDown(c.dispose);
  expect(await c.signIn(domain:'fixture.invalid',extension:'102',password:'fixture-password'),true);
  expect(c.state,AppCallState.connected);
  now=now.add(const Duration(minutes:2));await c.checkDirectReception();
  expect(c.state,AppCallState.connected);expect(c.errorMessage,isNull);
 });

 test('cold restoration ends an orphaned connected server call instead of showing silent media',()async{
  final native=DirectNativeFixture();var ended=0;
  final api=ControlApiClient(domain:'fixture.invalid',client:MockClient((r)async{
   if(r.url.path.endsWith('/sessions'))return http.Response(jsonEncode({'accessToken':'fixture-token','idleExpiresAt':'2027-01-01T00:00:00Z','extension':'102','deviceGeneration':1,'sipUri':'sip:102@fixture.invalid','sipUsername':'102','sipPassword':'fixture-sip-password','wssUrl':'wss://fixture.invalid/ws','setupTimeoutSeconds':40}),200);
   if(r.url.path.endsWith('/extensions'))return http.Response('[]',200);
   if(r.url.path.endsWith('/end')){ended++;return http.Response(jsonEncode({...callData(),'state':'Ended','endReason':'EndedByCallee'}),200);}
   return http.Response(jsonEncode({...callData(),'state':'Connected'}),200);
  }));
  final c=CallController(api:api,sip:LostMediaSip(),native:native,store:SecureCredentialStore(native));addTearDown(c.dispose);
  expect(await c.signIn(domain:'fixture.invalid',extension:'102',password:'fixture-password'),true);
  expect(ended,1);expect(c.state,AppCallState.idle);expect(c.errorMessage,contains('تماس قبلی'));
 });

 test('standby stops claiming ready when Control fails even if SIP stays registered',()async{
  final native=DirectNativeFixture();var available=true;
  final api=ControlApiClient(domain:'fixture.invalid',client:MockClient((r)async{
   if(r.url.path.endsWith('/sessions'))return http.Response(jsonEncode({'accessToken':'fixture-token','idleExpiresAt':'2027-01-01T00:00:00Z','extension':'102','deviceGeneration':1,'sipUri':'sip:102@fixture.invalid','sipUsername':'102','sipPassword':'fixture-sip-password','wssUrl':'wss://fixture.invalid/ws','setupTimeoutSeconds':40}),200);
   if(r.url.path.endsWith('/extensions'))return http.Response('[]',200);
   return available?http.Response('null',200):http.Response('{"code":"PBX_NOT_READY"}',503);
  }));
  final c=CallController(api:api,sip:TestSip(),native:native,store:SecureCredentialStore(native));addTearDown(c.dispose);
  expect(await c.signIn(domain:'fixture.invalid',extension:'102',password:'fixture-password'),true);
  await c.checkDirectReception();expect(native.statuses.last,true);
  available=false;await c.checkDirectReception();expect(native.statuses.last,false);expect(c.state,AppCallState.idle);
 });

}
