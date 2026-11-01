import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/config/app_config.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'call_handshake_test.dart' show MemoryNative,TestSip;
import 'startup_restore_test.dart' show loginReply,savedNative;

class GateNative extends MemoryNative {
  @override Future<bool> verifyDeveloperPassword(String password)async=>password=='fixture-developer';
}
void main(){
  tearDown(()=>AppConfig.overrideDomain=null);
  test('invalid or denied server change preserves saved account; allowed change wipes and persists override',()async{
    final native=GateNative();native.values['smi.password']='fixture-private';var remoteRequests=0;
    final c=CallController(api:ControlApiClient(domain:'192.168.1.151',client:MockClient((_)async{remoteRequests++;return http.Response('',204);})),sip:TestSip(),native:native,store:SecureCredentialStore(native));addTearDown(c.dispose);
    await expectLater(c.changeServer('https://bad','fixture-developer'),throwsArgumentError);
    await expectLater(c.changeServer('192.168.1.152','incorrect'),throwsStateError);
    expect(native.values['smi.password'],'fixture-private');
    await c.changeServer('192.168.1.152:8443','fixture-developer');
    expect(native.values['smi.password'],isNull);expect(native.values['smi.serverOverride'],'192.168.1.152:8443');expect(c.serverAddress,'192.168.1.152:8443');expect(remoteRequests,0,reason:'An unauthenticated settings change must not contact a fictitious old server');
  });
  test('revoked stored token never triggers automatic password login on cold start',()async{
    final native=await savedNative();native.values['smi.accessToken']='fixture-revoked';var loginCount=0;
    final c=CallController(api:ControlApiClient(domain:'192.168.1.151',client:MockClient((r)async{
      if(r.method=='POST')loginCount++;
      return http.Response('{"code":"SESSION_EXPIRED"}',401);
    })),sip:TestSip(),native:native,store:SecureCredentialStore(native));addTearDown(c.dispose);
    await c.restoreSession();expect(loginCount,0);expect(native.values['smi.password'],isNull);expect(c.canRetrySavedAccount,isFalse);expect(c.state,AppCallState.error);
  });
  test('directory updates without opening contacts; revocation clears cached contacts and credentials',()async{
    final native=MemoryNative();final second=Completer<http.Response>();final revoke=Completer<http.Response>();var watches=0;
    final c=CallController(api:ControlApiClient(domain:'192.168.1.151',client:MockClient((r)async{
      if(r.url.path.endsWith('/sessions'))return loginReply();
      if(r.url.path.endsWith('/watch')){
        watches++;
        if(watches==1)return http.Response(jsonEncode({'version':'one','entries':[{'extension':'102','displayName':'First'}]}),200);
        if(watches==2)return second.future;
        return revoke.future;
      }
      return http.Response(r.method=='PUT'?'':'[]',r.method=='PUT'?204:200);
    })),sip:TestSip(),native:native,store:SecureCredentialStore(native));addTearDown(c.dispose);
    expect(await c.signIn(domain:'192.168.1.151',extension:'102',password:'fixture-password'),isTrue);
    await Future<void>.delayed(const Duration(milliseconds:30));expect(c.directory.single.displayName,'First');
    second.complete(http.Response(jsonEncode({'version':'two','entries':[{'extension':'103','displayName':'Changed'}]}),200));
    await Future<void>.delayed(const Duration(milliseconds:30));expect(c.directory.single.displayName,'Changed');
    revoke.complete(http.Response('{"code":"SESSION_EXPIRED"}',401));
    await Future<void>.delayed(const Duration(milliseconds:30));expect(c.directory,isEmpty);expect(native.values['smi.password'],isNull);expect(c.state,AppCallState.error);
  });
  test('server addresses reject schemes, paths, malformed IPs and ports',(){
    for(final v in ['https://a.b','1.2.3.999','a.b/path','a.b:0','a.b:65536','a b.c','a..b','1.2.3']){expect(AppConfig.validAddress(v),isFalse,reason:v);}
    for(final v in ['192.168.1.151','phone.company.com:8443']){expect(AppConfig.validAddress(v),isTrue);}
  });
}
