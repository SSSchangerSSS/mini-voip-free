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

گزارش‌های فعلی: هنوز آزمونی اجرا نشده — همه ردیف‌های `../acceptance-tests.json`
`NOT_RUN` هستند و ادعایی از DeviceValidated/Deployed/Published وجود ندارد.
