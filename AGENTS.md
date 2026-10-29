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
- **اجرای محلی 2026-10-28:** ابزارهای قفل‌شده نصب شدند؛ IP میزبان `192.168.1.151` است و stack محلی با TLS داخلی و readiness واقعی 200 اجرا می‌شود. 43 تست Control، 16 تست Flutter و 8 تست wrapper پاس شدند. APK نهایی روی شبیه‌ساز Android 8 و 15 نصب و فرم ورود بررسی شد (محدودیت‌های ANR شبیه‌ساز 15 در گزارش ثبت‌اند)؛ پذیرش تماس و دستگاه واقعی همچنان باز است. ناسازگاری رمز API/SIP روی PBX واقعی تأیید شده؛ گزارش و محدودیت‌ها: `qa/reports/2026-10-28-local/REPORT.md`.

## فرمان‌های پرکاربرد

```bash
./smi doctor              # بررسی پیش‌نیازها
./smi test unit           # تست‌های unit واقعی موجود
./smi server init --config deploy/site.env
./smi server up
./smi extension add 101 --credential-file <secure-path>
```

هر فرمانی که در این نسخه اجرا نشد، خودش دلیل و exit code مشخص می‌دهد؛ سکوت و موفقیت نمایشی وجود ندارد.

- **تماس محلی 2026-10-28:** تماس ۱۰۱↔۱۰۲ روی شبیه‌سازهای Android 8/15 با Bridge واقعی و RTP دوطرفه، قطع، رد، لغو و timeout با ready دیرهنگام پاس شد؛ صوت شنیداری و گوشی واقعی BLOCKED هستند. 45 تست Control، 22 Flutter و 8 wrapper پاس شدند. ناسازگاری رمز SIP، قرارداد پاسخ تماس، AMI user events، خواندن متغیرهای ارث‌بری و Hangup پس از انتقال terminal اصلاح شدند. گزارش و محدودیت‌ها: `qa/reports/2026-10-28-call/REPORT.fa.md`.

- **ادامه پس از خاموشی 2026-10-29:** IP/سرور خودکار حفظ شدند؛ Android 8 حساب را خودکار بازیابی کرد. اولین restore اندروید 15 FAIL با System UI ANR بود؛ بازکردن دوباره اپ بدون ورود رمز موفق شد. تماس، RTP، پایداری میوت 74.72 ثانیه، کلید بلندگو و قطع/صفر کانال در دامنه شبیه‌ساز بررسی شدند؛ اتوماسیون تمیز FAIL (UIA timeout و exit 143 انتهای اجرا). کد محصول و APK عوض نشدند. گزارش: `qa/reports/2026-10-29-resume/REPORT.fa.md`.

- **اصلاح بازیابی حساب 2026-10-29:** تلاش محدود برای خطاهای موقت، progress و دکمه حساب ذخیره‌شده اضافه شد؛ خطاهای auth/TLS تکرار خودکار ندارند. قطع واقعی سرویس و اجرای سرد API35 بررسی شدند. نبود مسیر IPv4 پس از reboot مهمان تشخیص داده شد و راه‌انداز دسکتاپ QA با کنترل مسیر و یک reconnect Wi-Fi مجازی اصلاح شد. SystemUI ANR و پذیرش گوشی واقعی باز هستند. مرجع شواهد و باینری: `qa/reports/2026-10-29-startup-fix/REPORT.fa.md`؛ تصمیم `0007-bounded-account-restore.md`.

- **نتیجه نهایی همان اصلاح:** 45 Control + 35 Flutter + 8 wrapper = 88 تست PASS؛ APK نهایی پس از ساخت پاک روی هر دو شبیه‌ساز نصب شد. بازیابی پس از قطعی کوتاه/طولانی، تماس102→101، Bridge/RTP دوطرفه و قطع/صفرکانال تأیید شد. آماده‌بودن رابط Android15 بدون دخالت FAIL به‌علت Quickstep/SystemUI ANR؛ این نقص رفع‌شده معرفی نمی‌شود. شواهد و checksum نهایی در گزارش startup-fix ثبت‌اند.

- **بررسی پایداری شبیه‌ساز 2026-10-29:** نمایش مستقیم جای scrcpy/کدک مهمان را گرفت؛ نمونه CPU API35 از107.91٪ به34.08٪ با حذف mirror کاهش یافت. ART دو بسته UI با speed تأیید شد، ولی سه trial SDK هنوز SystemUI ANR داشتند؛ GPU میزبان رد شد و fallback SwiftShader نگه داشته شد. Android15 بومی ReDroid از میرور چین با Digest رسمی pin و کانتینر Created شد؛ اجرای آن BLOCKED منتظر بارگذاری Binder محلی با sudo است. هیچ ادعای رفع کامل/تماس محیط جدید وجود ندارد. گزارش: `qa/reports/2026-10-29-emulator-stability/REPORT.fa.md`؛ تصمیم‌های0008/0009.

- **Android15 بومی پس از Binder — 2026-10-29:** تصویر pin‌شده ReDroid از میرور چین اجرا شد. حد pids1024 علت crash اولیه بود و به4096 اصلاح شد. پنج شروع سرد مشاهده‌شده (چهار probe و یک میانبر واقعی؛ یکی از runnerها پس از ثبت شواهد exit143 داشت)، بدون ANR/crash و با restore حساب؛ تماس101↔103، RTP دوطرفه، میوت72.59s، کلید بلندگو و قطع/صفرکانال بررسی شدند. میانبر15 به runtime جدید منتقل و AVD102 حفظ شد. APK تغییر نکرد. گوشی/صوت فیزیکی/Push BLOCKED؛ گزارش دقیق: `qa/reports/2026-10-29-native-android15/REPORT.fa.md`.
