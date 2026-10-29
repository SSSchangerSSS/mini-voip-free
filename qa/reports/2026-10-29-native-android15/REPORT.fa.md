# رفع عملی هنگ Android15 روی همین PC — 2026-10-29

**نتیجه:** مسیر پیش‌فرض اندروید۱۵ به ReDroid بومی روی همین Ubuntu/VMware منتقل شد. پس از اصلاح تنظیم کانتینر، در پنج شروع سرد ثبت‌شده (چهار probe و یک میانبر دسکتاپ)، SystemUI/Quickstep هیچ ANR یا crash نداشتند؛ حساب بدون ورود مجدد رمز ثبت شد. تماس با اندروید۸ در هر دو جهت، RTP، میوت بیش از۷۲ثانیه و قطع/پاک‌شدن کانال‌ها بررسی شدند. SDK قبلی با TCG برای مقایسه حفظ شده و خطاهای آن رفع‌شده معرفی نمی‌شوند.

## محیط و تغییر نهایی

- PC همان Ubuntu/VMware، چهار vCPU، RAM حدود7.2GiB و swap4GiB؛ KVM در دسترس نیست. سرور همچنان `192.168.1.151` است.
- Android8: AVD قبلی API26 با نمایش مستقیم Qt، حساب101.
- Android15: ReDroid واقعی API35/amd64/64only؛ تصویر رسمی از میرور چین با Digest قفل‌شده `sha256:58e548d78c4854f032912757dc0782d7a86b9d602ffc10b2f09fb9e86731adf3`. منبع/تأیید Digest در گزارش [مرحله قبلی](../2026-10-29-emulator-stability/REPORT.fa.md) و `redroid-official-manifest.json` آن پوشه است. فقط Android15 دریافت شده؛ Android9–14/16 دانلود نشده‌اند.
- ماژول موجود و امضاشده Binder با اقدام محلی کاربر بارگذاری و وجود `/sys/module/binder_linux` تأیید شد. هیچ کرنل یا تنظیم دائمی boot نصب نشده است.
- کانتینر QA جدا از stack محصول است: سقف2CPU، RAM2560MiB، pids4096، گرافیک نرم‌افزاری،480x800/density160، memfd و ADB فقط `127.0.0.1:5565`. پیکربندی واقعی: `runtime-config.txt` و `adb-local-port.txt`. این runtime طبق روش رسمی ابزار privileged است و جای گوشی واقعی نیست.
- همان APK پیشین استفاده شد؛ SHA256 آن `565ecc09c5f9f02c91aa52277bc9df47900aa5a9d9c75fdb63fdf37d0df0d335` است. اعتماد CA داخلی/TLS پابرجاست؛ کد محصول و شناسه‌های wire تغییر نکردند.
- حساب103 جداگانه برای این محیط ساخته شد تا binding داخلی102 و اطلاعات AVD قبلی حفظ شوند. credential فقط در فایل ignored با mode600 است؛ مقدار آن در گزارش/سورس/لاگ نوشته نشده. provisioning با `./smi extension add 103 --credential-file ...` انجام شد؛ `provision-103.log`، `pbx-103.txt` و `login-result.json` شاهدند.

## شکست اولیه و اصلاح علت

اولین تنظیم کانتینر pids_limit=1024 داشت. کرنل58 بار برخورد با این حد را ثبت کرد (`initial-pids-limit.txt`)؛ ساخت نخ با `pthread_create ... Try again` شکست خورد و سرویس‌های اندروید ری‌استارت شدند (`initial-system-crashes.txt`). نصب اولیه APK نیز با NullPointerException هنگام ناپایداری PackageManager شکست خورد (`../2026-10-29-emulator-stability/redroid-launch1.log`). این اجرا **FAIL** است.

حد به4096 افزایش یافت؛ در وضعیت عادی بیش از1200 task وجود داشت، پس1024 کافی نبود. سقف RAM عوض نشد. بعد از اصلاح، pids.events در آزمون‌ها و پایان `max 0` بود و حافظه/CPU به‌طور نمونه حدود0.9–1.1GiB و11–17٪ مشاهده شد؛ این نمونه اندازه‌گیری است، نه تضمین همه بارهای کاری.

راه‌انداز اکنون علاوه بر sys.boot_completed، بازبودن کاربر، پاسخ PackageManager و ثبات PID سرویس system_server را در سه نمونه بررسی می‌کند. یک خروج زودهنگام helper هنگام اتصال اولیه ADB نیز اصلاح شد؛ لاگ `boot2-launch-transport-failure.log` و exit1 آن حفظ شده است. نصب موفق در `boot2-launch-rerun.log` ثبت است.

## آزمون‌های انجام‌شده

| آزمون | نتیجه | مدرک |
|---|---|---|
| تشخیص Android15/API35 و نصب همان APK | PASS | `fingerprint.txt`، `boot2-launch-rerun.log`، `login-ready.png` |
| ورود حساب103 و ثبت SIP واقعی | PASS؛ بدون ثبت مقدار رمز | `login-result.json`، `login-contacts.txt`، `login-registered.png` |
| سه چرخه Home→برنامه و باز/بسته‌شدن اعلان‌ها | PASS؛ هر چرخه حدود5.8–5.9s، بدون ANR/crash | `ui-cycles-result.json`، `ui-after-cycles.png`، `ui-cycle-anr-crash.txt` |
| تماس103/Android15→101/Android8 | PASS در دامنه سیگنالینگ/انتقال رسانه | `call-to8-stages.json`، `call-to8-media-initial.txt`، تصاویر connected |
| میوت/بازگشت و کلید بلندگو | PASS در دامنه UI و پایداری؛ میوت72.59s | `call-to8-stages.json`، `call-to8-after-mute.txt`، تصاویر muted/speaker |
| قطع از اپ و صفرشدن کانال‌ها | PASS | `call-to8-after-hangup.txt`، `call-to8-end.log` |
| تماس101/Android8→103/Android15 و قطع | PASS در دامنه سیگنالینگ/RTP/قطع | `call-to15-stages.json`، `call-to15-after-hangup.txt` |
| تماس بعد از بوت‌های سرد | PASS؛ Bridge مشترک و RTP دوطرفه | `post-cold-to8-stages.json`، `post-cold-to8-media-initial.txt` |
| بازکردن دوباره میانبر حین تماس | PASS؛ همان Bridge حفظ شد، APK مجدد نصب نشد | `launcher-idempotent-result.json`، `launcher-call-before.txt`، `launcher-call-after.txt`، `launcher-during-call.log` |

در تماس پس از بوت، نمونه بعدی RTP به2054/4679 و4716/2054 بسته دریافت/ارسال رسیده بود و Bridge یکسان ماند. صدای شنیداری و اثر فیزیکی میکروفون/بلندگو از شمارش بسته اثبات نمی‌شوند و **NOT_RUN/BLOCKED** باقی‌اند.

### راه‌اندازی سرد و بازیابی امن حساب

هر بار فرایند اندروید متوقف و دوباره شروع شد؛ snapshot استفاده نشد، داده پاک نشد، هیچ رمز وارد نشد و contact تازه SIP با nonce متفاوت بررسی شد. cold3 علاوه بر این، خود کانتینر را با همان mount داده از نو ساخت و Keystore/حساب حفظ شد.

| نمونه | آمادگی پایدار Android از شروع | ثبت تازه SIP از شروع | ANR/crash | عملکرد |
|---|---:|---:|---:|---|
| cold1 |11.81s|12.94s|0|PASS|
| cold2 |11.87s|13.01s|0|PASS با محدودیت runner در پایین|
| cold3؛ ساخت دوباره کانتینر |11.70s|12.84s|0|PASS|
| cold4؛ تکرار تکمیلی |11.79s|12.92s|0|PASS|

علاوه بر این چهار نمونه، شروع از خود فایل میانبر دسکتاپ با `gio launch` روی کانتینر متوقف آزموده شد: حساب تازه در13.83s ثبت شد؛ ANR/crash صفر و صفحه آماده بدون رمز مشاهده شد (`desktop-cold-result.json`، `desktop-cold-launch.log`، `desktop-cold-app.png`؛ runner exit0). این پنجمین شروع سرد مشاهده‌شده است.

مدارک هر ردیف: `coldN-result.json`، `coldN-contacts.txt`، `coldN-app.png`، `coldN-anr-events.txt` و `coldN-crash.txt`. تصاویر هر چهار مورد بازبینی شدند؛ اپ آماده بود و دیالوگ مسدودکننده وجود نداشت. این اعداد مربوط به روش probe از شروع کانتینرند؛ زمان ورود کاربر/خاموش‌روشن‌شدن کل PC را شامل نمی‌شوند.

## محدودیت‌ها و شکست‌های اتوماسیون

- اولین probe تماس به‌دلیل بازماندن پنل اعلان‌ها فیلد شماره‌گیری را پیدا نکرد؛ exit1 و `call-to8-first-probe-failure.log` حفظ شده‌اند. تصویر `call-first-ui.png` پنل باز را نشان می‌دهد. روند اتوماسیون با collapse صریح پنل و بررسی بازگشت به اپ اصلاح شد؛ هیچ دیالوگ ANR برای سبزشدن آزمون بسته نشد. نتیجه اولیه Home-only در `ui-cycles-result-initial.json` حفظ شده و مدرک جامع نهایی نیست.
- ابزار اجرای cold2 در پایان exit143 داد، با اینکه قبل از آن JSON، تصویر، contact تازه و لاگ‌های بدون خطا ثبت شده بودند. علت قطعی این exit مشخص نیست؛ **اجرای خودکار تمیز همان مورد FAIL است**. سلامت عملکردی از شواهد مستقل ثبت‌شده بررسی شد. cold3 وcold4 با exit0 و بدون خطا دوباره اجرا شدند. این exit از تاریخچه حذف نشده است.
- CLI افزودن داخلی، reload را PENDING اعلام کرد. فرمان اولیه `pjsip reload` در این PBX پشتیبانی نمی‌شد؛ آن خروجی موفق محسوب نشد. reload صحیح `module reload res_pjsip.so` و وجود endpoint103 جداگانه تأیید شدند (`pbx-provision-reload-corrected.txt`، `pbx-103.txt`).
- خاموش‌روشن‌شدن کامل میزبان در این مرحله **NOT_RUN** است. Binder فعلاً در این boot بارگذاری شده؛ تنظیم دائمی modules-load نوشته نشده. در launch گرافیکی بعدی، اگر Binder غایب باشد، راه‌انداز برای همان اسکریپت محدود از احراز هویت محلی PolicyKit استفاده می‌کند؛ رمز را نمی‌خواند/ثبت نمی‌کند. خود مسیر نمایش آن dialog در این مرحله NOT_RUN بود چون ماژول از قبل فعال بود. در نبود مجوز/agent، خروج صریح BLOCKED و دستور محلی داده می‌شود.
- این تصویر فاقد GMS/Push تنظیم‌شده و سخت‌افزار واقعی است. Push، صفحه قفل گوشی واقعی، iOS، صوت شنیداری و امضای انتشار همچنان BLOCKED هستند. سازگاری همه گوشی‌ها یا Android9–14 از این آزمون نتیجه نمی‌شود.

## راه‌انداز و تحویل

میانبر **Mini VoIP Android 15** دسکتاپ اکنون `/home/changer/.local/bin/mini-voip-android15` را اجرا می‌کند؛ سورس آن `scripts/qa/start-android15-container.sh` است. APK نصب‌شده با hash مقایسه می‌شود و اگر یکسان باشد، نصب مجدد/قطع برنامه انجام نمی‌شود. اگر نسخه متفاوت باشد، به‌جای تعویض خودکار وسط تماس، update صریح در حالت idle لازم است. نسخه قبلی میانبر در `desktop15-before.desktop` نگه داشته شده است. میانبر Android8 همان AVD قبلی را باز می‌کند. AVD و binding102 قدیمی برای fallback حفظ شده‌اند.

فایل‌های تغییرکرده این ادامه: `qa/redroid-compose.yaml` (حد task)، `scripts/qa/start-android15-container.sh` (readiness، همسانی APK، auth محلی)، قفل/تصمیم QA، مستندات وضعیت و گزارش‌ها؛ کپی نصب‌شده helper و میانبر دسکتاپ نیز به‌روز شده‌اند. تغییرات قبلی مخزن حفظ شدند. برای rollback می‌توان کانتینر QA را متوقف و میانبر قبلی را بازگرداند؛ حذف داده کانتینر یا AVD لازم نیست.

وضعیت‌ها مستقل‌اند: **CodeReady این تنظیم QA: PASS؛ Deployed محلی: PASS؛ DeviceValidated: BLOCKED؛ Published: BLOCKED.** کل محصول یا پذیرش P0/P3/P4 از این نتیجه آماده انتشار محسوب نمی‌شود. همه60 ردیف پذیرش حفظ شده‌اند. تست‌های88گانه محصول مربوط به گزارش قبلی startup-fix هستند و به‌عنوان اجرای تازه این مرحله شمرده نمی‌شوند؛ کد محصول تغییر نکرده است.

مرجع runtime: [مستندات رسمی ReDroid](https://github.com/remote-android/redroid-doc). جزئیات چرایی تغییر محیط، Digest و شکست‌های SDK در تصمیم‌های0008/0009 و گزارش مرحله قبلی حفظ شده‌اند.

## بررسی پایان اجرا

`./smi check` و `docker compose -f qa/redroid-compose.yaml config --quiet` اجرا شدند؛ خروجی بررسی در `check.log` و پیکربندی واقعی در `runtime-config.txt` است. اسکن محدود secretهای محلی شناخته‌شده و گونه base64 آن‌ها، worktree و محتوای بازشده APK در `known-secret-scan.json` ثبت شده؛ این جای audit جامع نیست. سلامت سرور، contactهای101/103، صفر کانال فعال و event/crash buffer نهایی در `server-ready.json`، `final-contacts.txt`، `final-channels.txt`، `final-anr-events.txt` و `final-crash.txt` ثبت‌اند.
