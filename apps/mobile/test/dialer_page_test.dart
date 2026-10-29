import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'package:smi_phone/ui/dialer_page.dart';
import 'call_handshake_test.dart' show MemoryNative, TestSip;
class DialerController extends CallController {
  DialerController():super(api:ControlApiClient(domain:'test.invalid'),sip:TestSip(),
      native:MemoryNative(),store:SecureCredentialStore(MemoryNative()));
  String? dialed;
  @override AppCallState get state=>AppCallState.idle;
  @override bool get micReady=>true;
  @override Future<bool> placeCall(String target) async { dialed=target; return true; }
}
void main(){
 testWidgets('call button actually requests a normalized call from the controller',(tester)async{
  final controller=DialerController();addTearDown(controller.dispose);
  var callbacks=0;
  await tester.pumpWidget(MaterialApp(home:DialerPage(controller:controller,onStartCall:(){callbacks++;})));
  await tester.enterText(find.byType(TextField),'۱۰۲');
  await tester.tap(find.text('تماس'));
  await tester.pump();
  expect(controller.dialed,'102');expect(callbacks,1);
 });
}
