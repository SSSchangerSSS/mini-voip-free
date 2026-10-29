# اصلاح بازیابی حساب در شروع برنامه — ۲۰۲۶/۱۰/۲۹

اصلاح بازیابی حساب و راه‌انداز شبکه انجام و نسخه جدید نصب شده است. محدودیت ANR سیستم اندروید۱۵ همچنان باز است؛ گزارش‌های قبلی و شکست‌های اولیه حفظ شده‌اند.

## مشکل و اصلاح

نسخه قبلی بازیابی حساب را بعد از اولین شکست رها می‌کرد و صفحه خطای عمومی ورود نشان می‌داد. بازکردن دوباره برنامه با همان اطلاعات امن موفق می‌شد. لاگ نسخه قدیمی نوع خطای اولیه را ثبت نمی‌کرد؛ علت تاریخی را قطعی فرض نکردیم.

در نسخه جدید:

- همان حساب و همان installationId از مخزن امن خوانده می‌شوند؛ خطاهای موقت شبکه، timeout و HTTP 502/503/504 حداکثر سه تلاش با فاصله‌های ۲ و ۵ ثانیه دارند.
- خطای رمز/دستگاه دیگر/محدودیت درخواست، TLS نامعتبر، خرابی دسترسی بومی و خطاهای ناشناخته خودکار تکرار نمی‌شوند. اطلاعات امن پاک یا جایگزین نمی‌شوند و اعتبارسنجی گواهی خاموش نشده است.
- موتور SIP ناموفق پیش از تلاش بعدی بسته می‌شود؛ شکست cleanup تکرار خودکار را متوقف می‌کند.
- صفحه بازیابی فوراً نمایش داده می‌شود. اگر خطای موقت ادامه داشته باشد، کاربر با «تلاش مجدد با حساب ذخیره‌شده» بدون واردکردن مجدد رمز اتصال را بازیابی می‌کند.
- فقط مرحله و دسته خطا در لاگ می‌آیند؛ متن exception، شماره حساب، رمز، token و پیام‌های SIP ثبت نمی‌شوند. مهلت ۴۰ ثانیه‌ای تماس و شناسه‌های wire تغییر نکرده‌اند.

فایل‌های کد: `apps/mobile/lib/call/call_controller.dart`، `apps/mobile/lib/main.dart`، `apps/mobile/lib/ui/login_page.dart`. تست جدید: `apps/mobile/test/startup_restore_test.dart`. راه‌انداز قابل‌بازسازی: `scripts/qa/launch-emulator.sh`؛ همین فایل در `/home/changer/.local/bin/mini-voip-emulator` نصب شده است. تصمیم: `docs/decisions/0007-bounded-account-restore.md`. نسخه وابستگی‌ها عوض نشده است.

## نتایج تکمیل‌شده

| آزمون | نتیجه | شاهد |
|---|---|---|
| تست‌های رگرسیون بازیابی | PASS؛ ۱۳ مورد در اجرای نهایی | `unit-rerun.log` |
| مجموعه تست‌ها | PASS؛ ۴۵ Control + ۳۵ Flutter + ۸ wrapper = ۸۸ مورد، قراردادها معتبر | `unit-rerun.log`، exit 0 |
| تحلیل Flutter | PASS؛ بدون issue | `analyze-clean-final.log`، exit 0 |
| ساخت APK Release محلی | PASS | `android-build-clean.log`، exit 0 |
| قطع کوتاه واقعی سرویس edge | PASS؛ خطای api-login/network و بازیابی خودکار در تلاش دوم، بدون لمس صفحه/رمز | `short-result.json`، `short-recovered.png` |
| قطع طولانی‌تر واقعی سرویس edge | PASS؛ دقیقاً سه شکست، توقف خودکار، سپس بازیابی با دکمه حساب ذخیره‌شده بدون رمز | `persistent-result.json`، `persistent-retry-ui.png`، `persistent-recovered.png` |
| اولین اجرای سرد کامل Android 15 | PASS در دامنه بازیابی حساب؛ دو خطای api-login/network، سپس بازیابی خودکار در تلاش سوم | `cold1-result.json`، `cold1-screen.png`، `cold1-contacts.txt` |
| بررسی امضای APK | PASS برای امضای آزمایش محلی | `apk-signature-final.txt`، exit 0 |
| اسکن رمزهای واقعی شناخته‌شده در worktree و APK بازشده | PASS محدود؛ بدون تطابق | `known-secret-scan.json` |

در اجرای سرد، بوت/آماده‌شدن مهمان حدود ۲۱۸ ثانیه و ثبت SIP پس از فرمان بازکردن برنامه حدود ۶۷ ثانیه طول کشید. **هیچ رمز، پاک‌کردن داده یا restart دستی برنامه لازم نشد.** تصویر نهایی آماده بودن برنامه را تأیید می‌کند. در همین بوت، لاگ ANR مربوط به `com.android.systemui` هم وجود داشت؛ این هشدار سیستم را رفع‌شده یا به‌طور قطعی ناشی از برنامه معرفی نمی‌کنیم. در تصویر نهایی این آزمون، دیالوگ مسدودکننده‌ای روی اپ نبود.

سرور پس از هر آزمون قطع دوباره روشن و readiness آن بررسی شد؛ سرویس به‌صورت قطع‌شده رها نشد. در آزمون‌های شبکه از رمز دستی استفاده نشده است.

## باینری

`/home/changer/Desktop/flash/mini-voip-free/artifacts/android/mini-voip-free-192.168.1.151-startup-fix.apk`

SHA256: `565ecc09c5f9f02c91aa52277bc9df47900aa5a9d9c75fdb63fdf37d0df0d335`.

پروفایل LAN با اعتماد صریح به CA موجود و IP `192.168.1.151` است. APK قبلی با checksum قدیمی حفظ شده است. امضای انتشار کارفرما، گوشی واقعی، صدای فیزیکی، Push و صفحه قفل همچنان BLOCKED هستند. هیچ ادعای سازگاری قطعی تمام دستگاه‌ها یا رفع همه مشکلات Android System UI از این آزمون‌ها نتیجه نمی‌شود.

## مشکل دوم: مسیر IPv4 شبیه‌ساز

در reboot بعدی مهمان، راه‌انداز قبلی برنامه را بدون آماده‌بودن شبکه باز کرد. `cold2-desktop-result.json` همچنان **FAIL** است: حساب تا پایان مشاهده ثبت نشد و دکمه تلاش مجدد دیده شد. فیلتر اولیه logcat نیز خروجی ناقصی داشت؛ خالی بودن آرایه diagnostics شاهد نبودن خطا نیست.

در بررسی مستقل، مهمان آدرس DHCP `10.0.2.16/24` داشت و ConnectivityService مسیر default را در LinkProperties اعلام می‌کرد، ولی `ip -4 route show table all` مسیر IPv4 پیش‌فرض را نداشت. ping سرور `Network is unreachable` داد؛ همان زمان HTTPS روی میزبان سالم بود. با `svc wifi disable` / `svc wifi enable` فقط در مهمان، مسیر `default via 10.0.2.2` برگشت و ping موفق شد. IP میزبان همچنان `192.168.1.151` است؛ IP مهمان نباید برابر IP سرور شود.

پس از رفع مسیر، دکمه حساب ذخیره‌شده حساب را بدون ورود رمز بازیابی کرد (`network-saved-retry.png`). هنگام بررسی، SystemUI ANR هم ظاهر شد؛ بستن صریح آن و نمایش دوباره همان Activity بخشی از این تشخیص دستی بوده و این مرحله «خودکار و بدون دخالت» نامیده نمی‌شود.

راه‌انداز جدید پیش از بازکردن اپ منتظر مسیر IPv4 نصب‌شده می‌ماند؛ اگر نیامد، یک بار Wi-Fi مجازی را بازسازی می‌کند و در صورت تداوم مشکل، با exit3 و BLOCKED متوقف می‌شود. مسیر دستی یا bypass گواهی اضافه نمی‌کند. در آزمون بازتولید، اپ بسته و Wi-Fi عمداً قطع شد: راه‌انداز نقص را تشخیص داد، اتصال را برگرداند، برنامه را باز کرد و حساب102 با contact تازه و صفحه آماده ثبت شد؛ exit0. شواهد: `network-repair-result.json`، `network-launcher-regression.log`، `network-launcher-final.png`.

## شکست‌های آزمون و حدود نتیجه

- `unit-final.log` با exit1 یک نقص واقعی را آشکار کرد: Future ناموفق stop در dispose مدیریت نمی‌شد. این مورد اصلاح شد؛ `unit-rerun.log` exit0 و هر۸۸ تست PASS دارد. متن خطای خام در لاگ محصول چاپ نمی‌شود.
- اولین بررسی marker باینری، رشته شاخه dispose را جست‌وجو می‌کرد و FAIL شد (`apk-marker-check-initial.json`). این روش برای اثبات حضور همه شاخه‌های منبع در AOT معتبر نیست؛ متد dispose از کد محصول فراخوانی نمی‌شود. ساخت پاک و بررسی رشته‌های مسیر قابل‌دسترسی بازیابی/دکمه/progress در هر سه ABI در `apk-final-source-check.json` PASS است. این چک جای اجرای واقعی APK را نمی‌گیرد.
- آزمون قطع سرویس و اولین cold boot روی باینری r1 با SHA `c5208243b51f57c595e1bc83f97e72f52decfe39bf2ef948f26fdc10a276c158` انجام شدند؛ آن فایل جداگانه با پسوند `-r1.apk` حفظ شده است. باینری نهایی با ساخت پاک تهیه شده؛ نصب و آزمون نهایی جداگانه در ادامه ثبت شده‌اند.
- منابع میزبان: RAM حدود7.2GiB، swap4GiB، فاقد `/dev/kvm` و vmx/svm. SystemUI ANR رفع‌شده تلقی نمی‌شود؛ تضمین صفرشدن خطا روی همه گوشی‌ها ممکن نیست.

## فرمان‌ها و تحویل

`./smi test unit` (اجرای نهایی exit0)، `flutter analyze` در `apps/mobile` (exit0)، `flutter clean` و سپس `./smi build android --release --server-host 192.168.1.151 --trusted-ca-file qa/reports/2026-10-28-local/lan-root-ca.crt` (exit0)، `apksigner verify --verbose` (exit0)، `./smi check` (exit0) اجرا شدند. قطع/وصل edge، reboot و Wi-Fi فقط روی محیط QA انجام شده‌اند. فایل‌های شواهد دستورهای موردی و نتایج در همین پوشه‌اند.

علاوه بر فایل‌های کد/تست/راه‌انداز و تصمیم0007، `AGENTS.md`، `docs/PREFLIGHT.md`، `qa/acceptance-tests.json` و نمایه گزارش به‌روز شده‌اند. تغییرات قبلی مخزن حفظ شده‌اند. تعداد ردیف‌های پذیرش60 است و T55 همچنان BLOCKED؛ آزمون emulator جای reboot گوشی و Push نیست. مرحله بعد پس از تحویل این اصلاح، تست گوشی واقعی/Push/قفل و صوت شنیداری است، وقتی پیش‌نیازهای آن موجود شوند.

## بازآزمایی APK نهایی روی هر دو شبیه‌ساز

نسخه با SHA نهایی بالا روی API26 و API35 با `adb install -r -g` نصب شد؛ داده حساب حفظ شد و هیچ رمز وارد نشد. زمان boot+آماده‌شدن+نصب در probe حدود70.65 و261.93 ثانیه بود. هر دو حساب خودکار ثبت شدند و contactهای تازه در PBX دیده شدند. شواهد در `final-startup-result.json`، `final-install-probe.log`، فایل‌های `final-api*-install.txt` و `final-contacts.txt` هستند.

| آزمون نهایی | نتیجه | شاهد |
|---|---|---|
| نصب و بازیابی حساب Android8 | PASS | `final-api26-ready.png` |
| نصب و بازیابی حساب Android15 | PASS در دامنه حساب؛ بدون رمز | `final-api35-startup.png`، `final-api35-visible.png` |
| آماده‌بودن رابط Android15 بدون دخالت | FAIL؛ Quickstep و SystemUI ANR | `final-android-anr-events.txt`، تصاویر `final-api35-after-*` |
| تماس foreground از102/API35 به101/API26، Bridge مشترک و RTP دوطرفه | PASS در دامنه انتقال رسانه | `final-call-connected-result.json`، `final-call-media-later.txt`، `final-call-manual-connected.png` |
| قطع از اپ، بازگشت دو UI و صفرشدن کانال PBX | PASS؛ exit0 | `final-call-ended-result.json`، `final-call-after-hangup.txt`، `final-call-*-idle.png` |
| قطع کوتاه سرور با APK نهایی | PASS؛ بازیابی خودکار تلاش دوم، exit0 | `final-outage/short-result.json`، `final-outage/short-recovered.png` |
| قطع طولانی سرور با APK نهایی | PASS؛ دقیقاً سه شکست و سپس بازیابی با دکمه حساب ذخیره‌شده، بدون رمز، exit0 | `final-outage/persistent-result.json`، `final-outage/persistent-recovered.png` |

در تماس نهایی، دریافت/ارسال RTP دو leg به‌ترتیب231/77 و77/172 بسته بود. این مدرک انتقال بسته است؛ صدای شنیداری و مسیر واقعی میکروفون/بلندگو بررسی نشده‌اند.

**محدودیت اتوماسیون:** دو probe تماس با exit1 به‌علت دیالوگ‌های ANR به فیلد شماره‌گیری نرسیدند. probe بعدی نیز با exit1 زودتر از رندر رابط ورودی دنبال پاسخ گشت؛ در تصاویر واقعی، تماس ورودی وجود داشت. پاسخ با لمس مبتنی بر همان تصویر انجام شد و تماس به وضعیت connected رسید. این مراحل به‌عنوان اتوماسیون کامل PASS معرفی نمی‌شوند؛ لاگ‌های `final-call-start-initial.log`، `final-call-start-rerun.log` و `final-call-start-confirmed.log` حفظ شده‌اند. بستن Quickstep، انتخاب Wait سپس بستن SystemUI و نمایش همان Activity از دخالت‌های انجام‌شده بودند. `am start` تأیید کرد instance قبلی در حال اجراست؛ برای بازیابی اولیه حساب force-stop/ورود رمز لازم نبود.

وضعیت‌ها مستقل‌اند: **CodeReady برای همین اصلاح PASS**؛ **DeviceValidated = BLOCKED**؛ **Deployed محلی روی این PC/دو شبیه‌ساز PASS**؛ **Published = BLOCKED**. CodeReady کل محصول و پذیرش P0/P3/P4 از این گزارش نتیجه نمی‌شود. نسخه نهایی اعتماد صریح CA داخلی و سرور `192.168.1.151` را استفاده می‌کند و امضای debug آزمایش را دارد.

هر دو سناریوی قطعی روی APK نهایی نیز exit0 دارند. سرور edge در finally بازگردانده شد؛ `server-ready-final.json` سلامت db/ami را تأیید می‌کند. دو شبیه‌ساز و پنجره‌های scrcpy در پایان اجرا باز گذاشته شده‌اند.
