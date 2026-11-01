import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:smi_phone/sip/sip_adapter.dart';

class AudioOrderHelper extends SIPUAHelper {
  final List<String> trace;
  AudioOrderHelper(this.trace);
  @override
  Future<bool> call(String target, {bool voiceOnly = false, MediaStream? mediaStream,
      List<String>? headers, Map<String,dynamic>? customOptions}) async {
    trace.add('media'); return true;
  }
}
void main() {
  test('earpiece preference is set before outgoing media and restored for next call', () async {
    final trace=<String>[];
    final sip=SipAdapter(helper:AudioOrderHelper(trace),audioOutput:(speaker) async {trace.add('speaker=$speaker');});
    await sip.call('sip:105@test.local',attemptId:'fixture-attempt');
    await sip.setSpeaker(true);
    await sip.call('sip:105@test.local',attemptId:'next-attempt');
    expect(trace,['speaker=false','media','speaker=true','speaker=false','media']);
  });
  test('failed route selection does not start media with a misleading default', () async {
    final trace=<String>[];
    final sip=SipAdapter(helper:AudioOrderHelper(trace),audioOutput:(_) async {throw StateError('fixture route failure');});
    await expectLater(sip.call('sip:105@test.local',attemptId:'fixture'),throwsStateError);
    expect(trace,isEmpty);
  });
}
