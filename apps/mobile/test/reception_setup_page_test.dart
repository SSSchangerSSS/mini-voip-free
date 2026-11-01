import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smi_phone/ui/reception_setup_page.dart';

Map<Object?, Object?> caps({bool vendor = false}) => {
  'microphone': true, 'notifications': true, 'batteryUnrestricted': true,
  'fullScreenIntent': true, 'incomingChannelEnabled': true,
  'vendorBackgroundSetup': vendor,
};

void main() {
  testWidgets('continue requests next missing permission and never trusts an opened screen', (tester) async {
    final state = caps()..['microphone'] = false;
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(home: ReceptionSetupPage(load: () async => state,
      open: (target) async { opened.add(target); return 'granted'; })));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('setup-next')), 250); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next'))); await tester.pumpAndSettle();
    expect(opened, ['microphone']);
    // Native capability still says false: even a successful launch/result is not proof.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('setup-microphone')), -250); await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(find.byKey(const ValueKey('setup-microphone')));
    expect(button.onPressed, isNotNull);
    state['microphone'] = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('setup-microphone'))).onPressed, isNull);
  });

  testWidgets('OEM fallback remains explicitly unverified and recoverable', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ReceptionSetupPage(load: () async => caps(vendor: true),
      open: (_) async => 'appInfoFallback')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('setup-autostart')), 220); await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-autostart'))); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('setup-message')), -250); await tester.pumpAndSettle();
    expect(find.textContaining('وضعیت autostart هنوز تأیید نشده'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('setup-autostart')), 220); await tester.pumpAndSettle();
    expect(find.textContaining('قابل تأیید خودکار نیست'), findsOneWidget);
  });

  testWidgets('denial and launch failure do not complete a permission', (tester) async {
    final state = caps()..['microphone'] = false;
    var fail = false;
    await tester.pumpWidget(MaterialApp(home: ReceptionSetupPage(load: () async => state,
      open: (_) async { if (fail) throw Exception('fixture'); return 'denied'; })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-microphone'))); await tester.pumpAndSettle();
    expect(find.textContaining('اجازه داده نشد'), findsOneWidget);
    fail = true;
    await tester.tap(find.byKey(const ValueKey('setup-microphone'))); await tester.pumpAndSettle();
    expect(find.textContaining('صفحه مجوز باز نشد'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('setup-microphone'))).onPressed, isNotNull);
  });

  testWidgets('incoming call dismisses setup so call controls are reachable', (tester) async {
    final changes = ChangeNotifier(); var active = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReceptionSetupPage(
        load: () async => caps(), open: (_) async => 'alreadyGranted',
        callChanges: changes, callActive: () => active))), child: const Text('setup')))));
    await tester.tap(find.text('setup')); await tester.pumpAndSettle();
    expect(find.text('راه‌اندازی دریافت تماس'), findsOneWidget);
    active = true; changes.notifyListeners(); await tester.pump(); await tester.pumpAndSettle();
    expect(find.text('راه‌اندازی دریافت تماس'), findsNothing);
    changes.dispose();
  });

  testWidgets('setup scrolls on small screens without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 480); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ReceptionSetupPage(load: () async => caps(vendor: true), open: (_) async => 'appInfo')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('setup-autostart')), 220); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
