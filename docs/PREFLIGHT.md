# PREFLIGHT — وضعیت پیش‌نیازها (به‌روزرسانی: 2026-10-27، P0)

> طبق بخش ۳ سند پروژه: موارد ناموجود صریحاً `BLOCKED` ثبت می‌شوند و کار مستقل از آن‌ها ادامه می‌یابد.
> هیچ کلید یا رمزی در این فایل، چت یا Git قرار نمی‌گیرد؛ فقط نام متغیر و مسیر امن موردانتظار اعلام می‌شود.

## ۱) موارد تأییدشده (با منبع و تاریخ)

| مورد | نتیجه | منبع |
|---|---|---|
| sip_ua کاندید | `1.1.0` — موجود و مطابق کاندید سند | pub.dev API — 2026-10-27 |
| flutter_webrtc کاندید | `1.6.3` — موجود و مطابق کاندید سند | pub.dev API — 2026-10-27 |
| Flutter stable | `3.47.8` (Dart `3.13.7`) — خانواده 3.47 سند تأیید شد | releases_linux.json رسمی — 2026-10-27 |
| .NET 10 LTS | SDK `10.0.403` (انتشار 2026-10-25) | release-metadata رسمی مایکروسافت — 2026-10-27 |
| Asterisk 22 LTS | پایدارترین `22.11.0`؛ `22.12.0` فقط RC است و استفاده نشد | downloads.asterisk.org — 2026-10-27 |
| checksum منبع Asterisk | `3bd5ee040509a3d3cd9b1ba9520c18e6ec0a7e7981ca68c457dcd36ba3c54d94` (دانلود و محاسبه واقعی) | همین‌جا ثبت شده — ساختگی نیست |
| Caddy | `2.11.7` | GitHub Releases — 2026-10-27 |

همه موارد بالا در `toolchain.lock.json` ثبت‌اند. این «موجودیت» را ثابت می‌کند، نه سازگاری آزموده‌شده.

## ۲) آزمون‌های انجام‌شده واقعی تا امروز

- نصب .NET SDK 10.0.403 و build/test سرویس Control در محیط توسعه (نتیجه: سبز — جزئیات در گزارش commit و CI).
- تست unit ماشین حالت، نرمال‌سازی ارقام، رمزنگاری، رزرو slot و endpointهای نشست: اجرا شده.
- ❗ هیچ build اپ روی دستگاه واقعی، هیچ تماس واقعی SIP، هیچ Push واقعی انجام نشده است.

## ۳) دروازه‌های P0 — BLOCKED (نیازمند ورودی کارفرما؛ بخش ۱۹ سند)

| # | مورد | چه چیزی لازم است | متغیر/مسیر امن | آزمون رفع بلاک |
|---|---|---|---|---|
| B1 | سرور آزمایشی با IP و دامنه واقعی | دسترسی SSH امن + دامنه با DNS صحیح | `deploy/site.env` (غیرمحرمانه) | `./smi doctor` دامنه/پورت‌ها سبز شود |
| B2 | Apple Developer + قابلیت VoIP Push | Team ID، Bundle ID نهایی، کلید APNs | `deploy/secrets/apns.p8` + Team/Key ID در `site.env` | ارسال VoIP موفق به یک دستگاه واقعی |
| B3 | Firebase project (فقط برای Push) | service account + تنظیمات کلاینت متناسب package نهایی | `deploy/secrets/fcm-service-account.json` | ارسال high-priority data message موفق |
| B4 | Mac/Xcode برای build iOS | ماشین macOS با Xcode پشتیبانی‌شده Flutter 3.47.8 | — | `./smi build ios --release` exit 0 |
| B5 | دستگاه‌های واقعی | حداقل ۱ آیفون + ۲ اندروید (برای T08 دو آیفون لازم است) | — | اجرای ماتریس `qa/device-test-matrix.json` |
| B6 | keystore Android | keystore متعلق به کارفرما + backup امن | `deploy/secrets/` (خارج Git) | APK امضاشده و نصب/آپدیت موفق |
| B7 | Bundle ID / package نهایی | تأیید کارفرما (پیش‌فرض کاندید: `app.minivoipfree`) | `apps/mobile` build config | ثبت در تصمیم رسمی |

## ۴) ریسک‌های فنی که فقط P0 اثباتشان می‌کند

- cold start واقعی FlutterEngine + PushKit/CallKit روی قفل (بخش ۱۰.۳ سند) — ترکیب نسخه‌ها فقط پس از build Release روی دستگاه معتبر است.
- رفتار واقعی `WaitForCondition` با متغیر در Asterisk 22 (ارزیابی مجدد) — باید روی PBX واقعی سنجیده شود [S07].
- عبور subprotocol `sip` از Caddy به Asterisk WebSocket — تست واقعی لازم.
- مسیر رسانه در Wi-Fi و اینترنت موبایل واقعی کارکنان — اگر شکست خورد، پروفایل TURN طبق بخش ۲.۴ سند اضافه می‌شود.

## ۵) قانون اجرا در وضعیت BLOCKED

- کار P1 (سرویس Control، تست‌ها، قراردادها) و آماده‌سازی P2 بدون B1–B7 ادامه دارد.
- هیچ آزمون BLOCKED به PASS تبدیل نمی‌شود؛ ردیف‌های `qa/acceptance-tests.json` سر جای خود می‌مانند.
- با رفع هر بلاک، آزمون تعریف‌شده در جدول بالا اجرا و evidence ثبت می‌شود.
