import 'package:flutter/material.dart';

/// Permission state is re-read from Android; opening a settings screen never
/// marks a permission as granted. OEM autostart remains explicitly unverified.
class ReceptionSetupPage extends StatefulWidget {
  final Future<Map<Object?, Object?>> Function() load;
  final Future<String> Function(String target) open;
  final Listenable? callChanges;
  final bool Function()? callActive;
  const ReceptionSetupPage({super.key, required this.load, required this.open,
    this.callChanges, this.callActive});
  @override
  State<ReceptionSetupPage> createState() => _ReceptionSetupPageState();
}

class _ReceptionSetupPageState extends State<ReceptionSetupPage> with WidgetsBindingObserver {
  Map<Object?, Object?> _caps = {};
  bool _loading = true;
  bool _busy = false;
  bool _closing = false;
  String? _message;
  bool get _vendor => _caps['vendorBackgroundSetup'] == true;
  final _standard = const ['microphone', 'notifications', 'battery', 'fullscreen'];
  bool _done(String key) => _caps[{
    'microphone':'microphone', 'notifications':'notifications',
    'battery':'batteryUnrestricted', 'fullscreen':'fullScreenIntent',
  }[key]] == true && (key != 'notifications' || _caps['incomingChannelEnabled'] != false);

  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    widget.callChanges?.addListener(_callChanged); _refresh();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.callChanges?.removeListener(_callChanged); super.dispose();
  }
  void _callChanged() {
    if (_closing || widget.callActive?.call() != true) return;
    setState(() { _closing = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.of(context).pop();
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }
  Future<void> _refresh() async {
    try {
      final caps = await widget.load();
      if (mounted) setState(() { _caps = caps; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _message = 'بررسی مجوزها انجام نشد؛ دوباره بررسی کنید.'; });
    }
  }
  Future<void> _open(String target) async {
    setState(() { _busy = true; _message = null; });
    try {
      final route = await widget.open(target);
      if (!mounted) return;
      if (route == 'appInfoFallback') {
        setState(() { _message = target == 'autostart'
            ? 'صفحه اختصاصی راه‌اندازی خودکار در این نسخه سیستم باز نشد؛ اطلاعات برنامه باز شد. وضعیت autostart هنوز تأیید نشده است.'
            : 'برای این مجوز، اطلاعات برنامه باز شد؛ اجازه را آنجا فعال کنید و به برنامه برگردید.'; });
      } else if (route == 'denied') {
        setState(() { _message = 'اجازه داده نشد؛ این مرحله هنوز کامل نشده است.'; });
      }
      await _refresh();
    } catch (_) {
      if (mounted) setState(() { _message = 'صفحه مجوز باز نشد؛ دوباره تلاش کنید.'; });
    } finally { if (mounted) setState(() { _busy = false; }); }
  }
  Widget _step(String key, String title, String description) {
    final done = _done(key);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Row(children: [Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : null), const SizedBox(width: 8), Expanded(child: Text(title))]),
        const SizedBox(height: 8), Text(description),
        Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(
          key: ValueKey('setup-$key'), onPressed: _busy || done ? null : () => _open(key),
          child: Text(done ? 'فعال است' : 'اجازه بده'))),
      ],
    )));
  }
  @override
  Widget build(BuildContext context) {
    final pending = _standard.where((key) => !_done(key)).toList();
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('راه‌اندازی دریافت تماس')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16), children: [
          const Text('هر مرحله را از همین صفحه باز کنید، اجازه را در پنجره سیستم بدهید و برگردید. وضعیت پس از بازگشت دوباره بررسی می‌شود.'),
          if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!, key: const ValueKey('setup-message'))),
          _step('microphone', '۱. میکروفن', 'برای صحبت‌کردن پس از پاسخ تماس.'),
          _step('notifications', '۲. اعلان تماس', 'برای زنگ و نمایش تماس ورودی؛ کانال تماس هم باید فعال باشد.'),
          _step('battery', '۳. دریافت در پس‌زمینه', 'در درخواست سیستم، اجازه فعالیت بدون بهینه‌سازی باتری را بدهید.'),
          _step('fullscreen', '۴. تماس روی صفحه قفل', 'در صورت درخواست سیستم، نمایش تمام‌صفحه تماس را فعال کنید.'),
          if (_vendor) Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('تنظیمات POCO / Xiaomi / Redmi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('HyperOS تنظیمات جداگانه دارد. راه‌اندازی خودکار و باتری بدون محدودیت را برای Mini VoIP Free فعال کنید. وضعیت این مجوزهای اختصاصی از این صفحه قابل تأیید خودکار نیست.'),
              TextButton(key: const ValueKey('setup-autostart'), onPressed: _busy ? null : () => _open('autostart'), child: const Text('بازکردن راه‌اندازی خودکار')),
              TextButton(key: const ValueKey('setup-appInfo'), onPressed: _busy ? null : () => _open('appInfo'), child: const Text('باتری و مجوزهای HyperOS')),
              const Text('اگر گزینه نمایش پنجره در پس‌زمینه یا روی قفل وجود دارد، برای تماس اجازه بدهید. بعد از تنظیم، دریافت تماس پس از کنارزدن کارت را روی همین گوشی تست کنید.'),
            ]))),
          FilledButton(key: const ValueKey('setup-next'), onPressed: _busy ? null
              : pending.isNotEmpty ? () => _open(pending.first)
              : _vendor ? () => _open('autostart') : () => Navigator.of(context).pop(),
            child: Text(_busy ? 'در انتظار…' : pending.isNotEmpty ? 'ادامه: مرحله بعد' : _vendor ? 'بررسی تنظیمات HyperOS' : 'برگشت به شماره‌گیر')),
          TextButton(onPressed: _busy ? null : _refresh, child: const Text('بررسی دوباره وضعیت')),
          if (_vendor) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('برگشت به شماره‌گیر')),
        ],
      ),
    ));
  }
}
