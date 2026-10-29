import 'dart:async';

import 'package:flutter/material.dart';

import '../call/call_controller.dart';

/// Call screen (F03/F04): incoming (answer/decline), active (mute/speaker/hangup).
class CallPage extends StatefulWidget {
  final CallController controller;
  const CallPage({super.key, required this.controller});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.controller.state == AppCallState.connected) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _status() {
    switch (widget.controller.state) {
      case AppCallState.incomingPending:
        return 'تماس ورودی…';
      case AppCallState.connecting:
        return 'در حال اتصال…';
      case AppCallState.connected:
        final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
        final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        return '$m:$s';
      case AppCallState.outgoingPending:
        return 'در حال زنگ‌زدن…';
      case AppCallState.ending:
        return 'پایان تماس…';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final incoming = c.state == AppCallState.incomingPending;
    final active = c.state == AppCallState.connected;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF102027),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                c.remoteExtension == null ? '—' : 'داخلی ${c.remoteExtension}',
                style: const TextStyle(color: Colors.white, fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(_status(), style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const Spacer(flex: 3),
              if (incoming) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _roundButton(
                      icon: Icons.call_end,
                      label: 'رد تماس',
                      color: Colors.red,
                      onTap: c.declineIncoming,
                    ),
                    _roundButton(
                      icon: Icons.call,
                      label: 'پاسخ',
                      color: Colors.green,
                      onTap: c.answerIncoming,
                    ),
                  ],
                ),
              ] else if (active || c.state == AppCallState.connecting) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _roundButton(
                      icon: c.muted ? Icons.mic_off : Icons.mic,
                      color: c.muted ? Colors.orange : Colors.blueGrey,
                      onTap: active ? c.toggleMute : null,
                    ),
                    _roundButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onTap: c.hangUp,
                    ),
                    _roundButton(
                      icon: c.speakerOn ? Icons.volume_up : Icons.volume_down,
                      color: c.speakerOn ? Colors.blue : Colors.blueGrey,
                      onTap: active ? c.toggleSpeaker : null,
                    ),
                  ],
                ),
              ] else ...[
                const CircularProgressIndicator(color: Colors.white70),
                const SizedBox(height: 20),
                _roundButton(icon: Icons.call_end, color: Colors.red, onTap: c.hangUp),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required Color color,
    String? label,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      label: label ?? (icon == Icons.call_end ? 'قطع تماس' : icon == Icons.mic || icon == Icons.mic_off ? 'میوت' : 'بلندگو'),
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 34,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 32),
      ),
      ),
    );
  }
}
