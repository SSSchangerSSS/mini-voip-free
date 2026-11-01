import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smi_phone/api/api_models.dart';
import 'package:smi_phone/api/control_api_client.dart';
import 'package:smi_phone/call/call_controller.dart';
import 'package:smi_phone/secure/secure_credential_store.dart';
import 'package:smi_phone/ui/directory_page.dart';
import 'call_handshake_test.dart' show MemoryNative,TestSip;
class DirectoryFixture extends CallController {
  DirectoryFixture():super(api:ControlApiClient(domain:'fixture.invalid'),sip:TestSip(),native:MemoryNative(),store:SecureCredentialStore(MemoryNative()));
  AppCallState current=AppCallState.idle;
  @override AppCallState get state=>current;
  @override String get extension=>'101';
  @override List<ExtensionEntry> get directory=>const [ExtensionEntry('101','خودم'),ExtensionEntry('102','پشتیبانی')];
  @override Future<void> refreshDirectory()async{}
  void incoming(){current=AppCallState.incomingPending;notifyListeners();}
}
void main(){
  testWidgets('incoming call dismisses directory so call controls are visible',(tester)async{
    final c=DirectoryFixture();addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(ctx)=>Scaffold(body:TextButton(onPressed:()=>Navigator.of(ctx).push(MaterialPageRoute<void>(builder:(_)=>DirectoryPage(controller:c))),child:const Text('open'))))));
    await tester.tap(find.text('open'));await tester.pumpAndSettle();expect(find.text('داخلی‌های شرکت'),findsOneWidget);
    c.incoming();await tester.pumpAndSettle();expect(find.text('داخلی‌های شرکت'),findsNothing);expect(find.text('open'),findsOneWidget);
  });
  testWidgets('revoked session dismisses contacts to reveal login',(tester)async{
    final c=DirectoryFixture();addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home:Builder(builder:(ctx)=>Scaffold(body:TextButton(onPressed:()=>Navigator.of(ctx).push(MaterialPageRoute<void>(builder:(_)=>DirectoryPage(controller:c))),child:const Text('login root'))))));
    await tester.tap(find.text('login root'));await tester.pumpAndSettle();
    c.current=AppCallState.error;c.notifyListeners();await tester.pumpAndSettle();
    expect(find.text('داخلی‌های شرکت'),findsNothing);expect(find.text('login root'),findsOneWidget);
  });
  testWidgets('directory searches names and numbers and disables own extension',(tester)async{
    final c=DirectoryFixture();addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home:DirectoryPage(controller:c)));await tester.pumpAndSettle();
    final own=tester.widget<IconButton>(find.byWidgetPredicate((w)=>w is IconButton && w.tooltip=='تماس با 101'));expect(own.onPressed,isNull);
    await tester.enterText(find.byType(TextField),'پشتیبانی');await tester.pump();expect(find.descendant(of:find.byType(ListTile),matching:find.text('پشتیبانی')),findsOneWidget);expect(find.text('خودم'),findsNothing);
    await tester.enterText(find.byType(TextField),'101');await tester.pump();expect(find.text('خودم'),findsOneWidget);expect(find.text('پشتیبانی'),findsNothing);
  });
}
