# Decision 0002 — قفل نسخه‌های اولیه toolchain (P0)

- **تاریخ:** 2026-10-27
- **وضعیت:** پذیرفته‌شده (کاندید آزمایش‌نشده — برچسب صریح در `toolchain.lock.json`)
- **مسئله:** سند بخش ۳.۲ کاندیدهای `sip_ua 1.1.0`، `flutter_webrtc 1.6.3` و خانواده Flutter 3.47 را معرفی کرده و می‌خواهد نسخه‌ها فقط از منابع رسمی با ثبت تاریخ قفل شوند.
- **بررسی انجام‌شده (منابع رسمی، 2026-10-27):**
  - pub.dev: `sip_ua 1.1.0`، `flutter_webrtc 1.6.3`، `http 1.6.0`، `flutter_lints 6.0.0`
  - Flutter releases: stable `3.47.8` / Dart `3.13.7`
  - Microsoft release metadata: .NET SDK `10.0.403` (2026-10-25)
  - NuGet: `Microsoft.Data.Sqlite 10.0.14`، `Microsoft.AspNetCore.Mvc.Testing 10.0.14`، `Microsoft.NET.Test.Sdk 18.11.0`، `xunit 2.9.3`، `xunit.runner.visualstudio 4.0.1`
  - Asterisk: پایدارترین 22 LTS = `22.11.0` (22.12.0 هنوز rc3 است)؛ SHA-256 واقعی tarball محاسبه و ثبت شد
  - Caddy `2.11.7` (digest image در نخستین deploy واقعی ثبت می‌شود)
- **انتخاب:** همان مقادیر بالا در `toolchain.lock.json`، `global.json` (10.0.403، rollForward=latestFeature) و `pubspec.yaml`.
- **دلیل:** تطابق کامل کاندیدهای سند با آخرین نسخه‌های رسمی در تاریخ تدوین؛ اجتناب از floating/latest.
- **اثر و آزمون:** این ترکیب تا build Release دو پلتفرم و تست دستگاه، «آزموده» محسوب نمی‌شود. هر ارتقا نیازمند تصمیم جدید + نتیجه آزمون است (قواعد بخش ۳.۲).
- **ممنوع:** checksum/digest ساختگی، `latest`، شاخه شناور، `dependency_overrides` برای دورزدن conflict بدون ثبت.
