# qa/reports — شواهد آزمون

هر گزارش آزمون با این قالب ثبت می‌شود (الزام پیوست الف سند و بخش ۱۵):

```
Test ID:
Status: PASS | FAIL | NOT_RUN | BLOCKED | NOT_APPLICABLE
Environment/device:
Command/procedure:
Commit/build:
Evidence path (log/video/redacted):
Notes:
```

قواعد:
- evidence نباید فقط اسکرین‌شاتِ اعلام موفقیت خود ایجنت باشد.
- هر شکست ثبت و نگه داشته می‌شود؛ اجرای مجدد موفق، شکست اولیه را از تاریخچه پاک نمی‌کند.
- `NOT_APPLICABLE` فقط با دلیل scope و تأیید کارفرما.

گزارش فعلی: [نصب محلی و بررسی Android — 2026-10-28](2026-10-28-local/REPORT.md). نتایج واقعی و محدودیت‌ها در همان گزارش و `../acceptance-tests.json` ثبت‌اند؛ اجرای شبیه‌ساز جای DeviceValidated یا پذیرش تماس واقعی نیست.

گزارش اصلاح و بازآزمایی: [بازیابی حساب و شبکه شبیه‌ساز — 2026-10-29](2026-10-29-startup-fix/REPORT.fa.md).

گزارش پایداری و پیش‌نیاز ادامه: [SystemUI/Quickstep و مسیر Android15 بومی — 2026-10-29](2026-10-29-emulator-stability/REPORT.fa.md).

گزارش ادامه و runtime فعلی: [Android15 بومی، بوت و تماس — 2026-10-29](2026-10-29-native-android15/REPORT.fa.md).
