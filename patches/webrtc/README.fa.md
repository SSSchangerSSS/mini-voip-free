# مسیر رفع پذیرفته‌شده برای نامزد16

SDK144.7559.15 همراه رابط محلی سازگار flutter_webrtc1.6.3 درthird_party استفاده می‌شود؛ patch منبع رابط در flutter-webrtc-1.6.3-sdk144.patch و هش فایل‌های upstream در JSON کنار آن است. هیچ SDK binary یا حافظه‌ای patch نشده است. build و تماس/RTP و گیت لاگ درAPI26/35 PASS؛ مرجع docs/decisions/0015-sdk-logging-compatible-144.md و qa/reports/2026-10-31-sdk-privacy/REPORT.fa.md است.

## پیشنهاد قبلی اصلاح C++ برای SDK150 — استفاده نشد

وضعیت این patch: NOT_RUN. این فایل، مدرک رفع مشکل یا SDK ساخته‌شده نیست.

هدف حذف اطلاعات احراز موقت ICE از پیام INFO بومی است؛ داده پروتکل تغییر نمی‌کند. باید روی سورس دقیق متناظر با SDK150.7871.04 بررسی و اعمال شود، سپس AAR هر سه ABI به‌صورت واقعی ساخته، checksum آن ثبت و تماس/لاگ دوباره آزمون شود. پیش از پذیرش، dry-run/build و آزمون باینری الزامی است. از patch باینری یا تغییر حافظه SDK استفاده نشده است.

کنترل‌های runtime فعلی در نمونه13/15 لاگ را حذف نکردند (FAIL). نسخه144.7559.15 با Flutter فعلی build نشد و rollback شد؛ تصمیم0014. این مشکل نباید با حذف آزمون یا ثبت PASS پنهان شود.

مرجع محل لاگ: https://chromium.googlesource.com/external/webrtc/+/refs/heads/main/p2p/base/p2p_transport_channel.cc . تطبیق این patch با commit ناشر هنوز NOT_RUN است.
