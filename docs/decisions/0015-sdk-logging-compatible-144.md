# 0015 — رفع لاگ با رابط سازگار SDK144

درخواست مالک: رفع واقعی لاگ و آماده‌کردن APK برای تست دو گوشی. وضعیت اولیه trial: NOT_RUN؛ پذیرش فقط با build/تماس/گیت runtime.

علت سورس در شاخه m150_release: destructor در rtc_base/logging.cc از LoggingConfig.debug_severity استفاده می‌کند، اما JNI قدیمی LogToDebug فقط g_dbg_sev را تغییر می‌دهد. تنظیم LS_NONE در API جاوا خروجی INFO جدید را قطع نمی‌کند. مرجع: https://github.com/webrtc-sdk/webrtc/blob/m150_release/rtc_base/logging.cc .

نسخه144.7559.15 منتشرشده ناشر با کنترل لاگ قدیمی trial می‌شود. Flutter plugin1.6.3 سورس اصلی با LICENSE در third_party/flutter_webrtc نگه داشته شد؛ pub-cache عمومی تغییر نمی‌کند. دو دسترسی به فیلد جدید enableSctpSnap با رد صریح فعال‌سازی WARP/SNAP جایگزین شدند؛ این قابلیت SCTP/data-channel در تماس صوتی محصول استفاده نمی‌شود. مقدار false نیاز به فیلد ندارد. tracer داخلی plugin نیز خاموش است. هیچ patch باینری/حافظه و هیچ تغییر پروتکل محصول انجام نشده است.

مرجع SDK: https://github.com/webrtc-sdk/android/releases/tag/v144.7559.15 . Maven از mirror چین Aliyun دریافت می‌شود. پیش از پذیرش باید checksum واقعی AAR، منبع plugin، diff محدود، build، API8/15 و خروجی لاگ بدون credential ثبت شوند. trial قبلی144 بدون این patch همچنان FAIL باقی است.

نتیجه نامزد16: build Release universal وanalyze و49 تست Flutter PASS؛ هر سه .so داخل APK با AAR144 برابرند. گیت runtime پس از تماس هر دو جهت رویAPI26/35 PASS: هر دستگاه6 marker تنظیم لاگ، صفر ICE/SDP/Authorization و صفرFATAL. تماس درscreen-off هر دو مقصد باBridge/RTP وقطع/صفرکانال PASS. T66 جدید PASS و FAIL نمونه15 درhistory/گزارش phase2 باقی است. صدای فیزیکی/همهOEMها تأیید نمی‌شوند؛ آزمون گوشی‌های مالک مرحله بعد است.

SHA256 AAR144: `fc7c8d027eb33860ccbb7847988f7f942d44a92d1f575348bba6c0250cde4071`؛ SHA256 آرشیو pub اصلی1.6.3: `b98ef03376401e54ff87fc78907b38e562b15ca8424aba589c263eddc3c1ecf9`. source branch tree بررسی‌شده150: `a802fa9849e0dae7f54c7d3deb05820a674b2f46`. مرجع مدارک: qa/reports/2026-10-31-sdk-privacy/REPORT.fa.md .
