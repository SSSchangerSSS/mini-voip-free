# AGENTS.md — قرارداد کار ایجنت در مخزن mini-voip-free

> مرجع واحد تصمیم‌های فنی این پروژه فایل `docs/PROJECT_SPEC.fa.md` است.
> این فایل فقط خلاصه عملیاتی برای هر ایجنتی است که روی این مخزن کار می‌کند.

## هویت پروژه

- **نام مخزن/محصول:** `mini-voip-free`
- **شناسه‌های سطح سیم (wire-level identifiers)** مطابق سند تغییر نکرده‌اند و نباید بدون تصمیم ثبت‌شده عوض شوند: متغیرهای `SMI_*` در Dialplan/AMI، کانال بومی `smi.phone/native/v1`، رویدادهای `SMICallRequested/SMICallDialing/SMICallFinished` و فرمان‌های `./smi ...` (بخش‌های ۸، ۱۰ و ۱۳ سند). جزئیات: `docs/decisions/0001-project-naming.md`.

## چرخه عمر (مراحل تحویل — بخش ۱۷ سند)

| مرحله | خروجی | دروازه |
|---|---|---|
| P0 | preflight + قفل نسخه + آزمایش کوچک native/SIP | اثبات cold start و صدای قفل با مدرک؛ نبود دستگاه = BLOCKED |
| P1 | monorepo + build scripts + SQLite/API + تست state/auth | build و unit/contract واقعی |
| P2 | Asterisk + AMI + TLS + تماس دوطرفه foreground | دو داخلی واقعی و سناریوهای cancel/timeout/slots |
| P3 | Push بومی کامل + قفل + raceها | Device E2E و T14–T33 |
| P4 | hardening + نصب/backup/restore + CI + release build | تست عملیات و باینری امضاشده |
| P5 | انتشار | مدارک انتشار واقعی یا ثبت شفاف موانع |

## قواعد غیرقابل‌نقض برای ایجنت

1. **صداقت وضعیت:** هر ادعا به خروجی واقعی (دستور، exit code، مسیر گزارش) متصل باشد. چهار برچسب مستقل `CodeReady` / `DeviceValidated` / `Deployed` / `Published` یکی نیستند.
2. **وضعیت هر آزمون** فقط یکی از: `PASS`، `FAIL`، `NOT_RUN`، `BLOCKED`، `NOT_APPLICABLE`. `qa/acceptance-tests.json` مرجع ردیابی است؛ حذف تست برای سبز شدن گزارش ممنوع.
3. **اسرار:** هیچ secret ای در چت، سورس، لاگ یا Git قرار نگیرد. فایل‌های واقعی در `deploy/secrets/` (gitignore شده). placeholder باقی‌مانده در production باید fail کند.
4. **قابلیت اضافه ممنوع:** چیزی خارج از فهرست ۱.۳ سند ساخته نشود. خطای واقعی را با تست اصلاح کن، نه با معماری جدید.
5. **قفل نسخه:** نسخه‌ها در `toolchain.lock.json` ثبت‌اند. ارتقا فقط با تصمیم ثبت‌شده در `docs/decisions/NNNN-*.md` و نتیجه آزمون. checksum ساختگی ممنوع.
6. **fail-closed:** نبود اعتبارنامه/دستگاه/سرویس = ثبت صریح `BLOCKED`، نه جایگزین پنهان.
7. **توابع فرمان استاندارد:** از `./smi ...` استفاده کن؛ اگر فرمانی هنوز پیاده‌سازی نشده، خروجی آن باید صریحاً NOT_IMPLEMENTED/BLOCKED باشد (exit 2/3)، نه موفقیت ساختگی.
8. **گزارش پایان هر مرحله:** فایل‌های تغییرکرده، دستورهای اجراشده، نتیجه، evidence path، ایراد باقی‌مانده و مرحله بعد.

## نقشه فعلی (به‌روزرسانی پس از هر مرحله)

- **انجام‌شده (این scaffold):** ساختار مخزن مطابق بخش ۱۲، قراردادهای ریشه، سرویس Control با API/ماشین حالت/slotهای اتمیک + تست unit، قالب‌های Asterisk/Caddy/Compose، قراردادهای OpenAPI/Push/Native-Events، هسته Flutter + آداپتورهای بومی (overlay)، CI پایه.
- **مسیر پیش‌رو:** P0 (دستگاه واقعی + build Release دو پلتفرم) → P1 تکمیل (AMI integration واقعی، contract test کامل) → P2 (تماس واقعی foreground) → P3 → P4 → P5.
- لیست کامل موانع بیرونی و ورودی‌های کارفرما: `docs/PREFLIGHT.md`.

## فرمان‌های پرکاربرد

```bash
./smi doctor              # بررسی پیش‌نیازها
./smi test unit           # تست‌های unit واقعی موجود
./smi server init --config deploy/site.env
./smi server up
./smi extension add 101 --credential-file <secure-path>
```

هر فرمانی که در این نسخه اجرا نشد، خودش دلیل و exit code مشخص می‌دهد؛ سکوت و موفقیت نمایشی وجود ندارد.
