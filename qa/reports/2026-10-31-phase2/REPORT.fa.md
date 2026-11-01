# نتیجه مرحله — قابلیت‌های درخواستی پیاده شده‌اند؛ تحویل امن APK هنوز مسدود است

> این گزارش وضعیت تاریخی APK15 است. رفع بعدی با ترکیب سازگارSDK144 در APK16 و PASS گیت لاگ، جدا در [گزارش جدید](../2026-10-31-sdk-privacy/REPORT.fa.md) ثبت شده؛ FAILهای این مرحله حفظ‌اند.

تاریخ:2026-10-31. هدف عمومی Android8 تا15 است؛ مدل گوشی شرط پیاده‌سازی نیست. فقط8 و15 طبق خواسته مالک اجرا شدند؛9 تا14 و همه مدل‌های فیزیکی NOT_RUN هستند. مالک کارکرد کامل foreground نسخه قبلی را روی دو گوشی گزارش کرد؛ این گزارش به‌تنهایی تأیید تغییرات جدید نیست.

## چهار وضعیت مستقل

| وضعیت | نتیجه فعلی |
|---|---|
| CodeReady کامل | BLOCKED؛ گیت لاگ بومی SDK با شناسهT66، FAIL است. قابلیت‌های کاربردی build و آزمون شده‌اند؛ وضعیت کامل پروژه سبز نیست. |
| DeviceValidated تغییرات جدید | BLOCKED؛ گوشی واقعی/صدای شنیداری/محدودیت‌هایOEM بررسی مستقیم نشده‌اند. |
| Deployed | Control، پنل و CLI روی همین151 فعال‌اند؛ APK15 روی دو محیط QA نصب و تماس گرفته شد. نصب روی گوشی‌های واقعی انجام نشده است. |
| Published | BLOCKED؛ APK جدید برای دریافت عمومی/عملیاتی منتشر نشده، commit/push یا انتشار رسمی این مرحله انجام نشده و امضا محلی آزمایشی است. |

## تغییرات تحویلی

1. **بدون حساب Google:** تصمیم0013 مسیر Android را از Firebase جدا کرد. SmiIncomingService با اعلان دائمی،Wake/Wi-Fi lock،START_STICKY،boot/package-replaced و FlutterEngine مشترک، اتصال مستقیمWSS/HTTPS به PBX شرکت را نگه می‌دارد. SIP MESSAGE سرنخ سریع است و reconcile احرازشده هر5ثانیه، سرنخ ازدست‌رفته را پوشش می‌دهد. heartbeat هم‌زمان guard دارد و تلاش دوباره اتصال حداقل30ثانیه فاصله دارد. SDK Firebase ازAPK حذف و پیش‌فرض STUN عمومیGoogle صریحاً برای LAN خالی شد. اینترنت عمومی/Google Play services پیش‌نیاز مسیر جدید نیست؛ دسترسی به سرورLAN لازم است.
2. **قفل/صدا:** Core-Telecom1.0.0 مالک مسیر صداست و AudioSwitch موازی غیرفعال می‌شود. اولویتwired/Bluetooth/earpiece/speaker و نمایش endpoint واقعی سیستم جای پیش‌فرضSpeaker با دکمه خاموش را گرفت. شروع هر رسانه ترجیح مسیر را بازنشانی می‌کند. API26–28 برای تماس ورودیِ قفل، fallback بیدارکردن محدود10ثانیه دارند؛ با اعلان/کانال مسدود یاDND این مسیر اجرا نمی‌شود. API29+ ازFSI سیستم استفاده می‌کند. بعد از پایان، اجازه نمایش روی قفل پاک می‌شود. صوت فیزیکی هنوزBLOCKED است.
3. **CLI:** فایل اجراییserver و فرمان نصب‌شدهmini-voip-server، start/status/logs را به./smi موجود متصل می‌کنند؛ مسیرsymlink و اجرای بیرون مخزن بررسی شد. logs پیش‌فرضControl است. env/LAN override و مخفی‌نشدن خطایDocker هنگام فیلترcall-id اصلاح و واقعی بررسی شدند.
4. **مدیریت و دفترچه:** پنل/admin با secret جدا، نشستHttpOnly/SameSiteStrict،CSRF،محدودسازی ورود وHTTPS درLAN؛ فقطloopback صریحHTTP مجاز است. مهاجرت2،DisplayName را بدون حذف داده اضافه کرد. ساخت/ویرایش/فعال‌سازی/رمز/آزادکردن دستگاه با محافظ تماس فعال؛ API فهرست فقطBearer و فقط نام/شماره فعال. موبایل جستجو/تازه‌سازی/نام+داخلی/جلوگیری تماس با خود دارد. ورود تماس، فهرست باز را کنار می‌زند. داخلی‌های گوشی104/105 تغییر رمز،reset یاunbind نشدند؛ نام‌هایfixture101/103 پس از آزمون برگردانده شدند.

اصلاحات همراه: parsingUTC واقعی برایdeadline/session، پایان leg بدونmedia هنگام بازیابی فرایند جدید، جلوگیری انقضای تماسConnected با مهلتsetup، و وضعیت آماده‌باش وابسته به سلامتControl به‌علاوهREGISTER. کد اختیاری قدیمیFCM سرور با تست‌هایRSA/HTTP اصلاح شده ولی در مسیرAndroid مستقیم فعال نیست؛ پروژه/کلیدFirebase دریافت یا ساخته نشد.

فایل‌های اصلی: Management/ وUtcTime.cs درControl، مدل/Client/Controller/UIهایFlutter، NativeCallBridge/SipAdapter، آداپتورهایAndroid وoverlay یکسان، manifest/Gradle،server/server-logs، قراردادها، تصمیم‌های0012–0014 و راهنماها. changed-files.txt کل وضعیت ورک‌تری را ثبت می‌کند و شامل تغییرات مرحله قبلی هم هست.

## آزمون‌های خودکار و عملیات

| آزمون/فرمان | نتیجه | evidence |
|---|---|---|
| dotnet test Control Release | PASS،52،exit0 | backend-verified.log / final-unit.log |
| flutter analyze | PASS،بدونissue،exit0 | release15-verified-tests.log |
| flutter test | PASS،49،exit0 | release15-verified-tests.log |
| wrapper regression | PASS،9،exit0 | final-unit.log |
| QA startup-lock regression | PASS،4،exit0 | final-unit.log |
| قراردادها وsyntax/config | PASS،exit0 | final-contracts.txt / final-check.log |
| ./server start واقعی | PASS،exit0 | server-verified.log |
| CLIstatus از/tmp باsymlink | PASS،live/ready200 | cli-installed-status.log |
| logs دنبال‌شونده | PASS،stream واقعی؛ exit124 توقف عمدیtimeout | cli-logs-result.json |
| Dockerعمداً unavailable درlogs | PASS،exit1؛ خطا به موفقیت تبدیل نشد | cli-logs-failclosed.json |
| login/list/name update مدیریت واقعی | PASS؛ بدون چاپcredentials | admin-live-set.log / admin-final-restore.log |

جمع114 آزمون واحد/رگرسیون است، نه114 آزمون گوشی. evidence/ مرجع فایل‌های جدول است. تغییر نام بدون رمز نشست گوشی را حفظ می‌کند؛ تغییر رمز/آزادکردن/غیرفعال‌سازی نشست قبلی را باطل می‌کند. برای منع ورود دوباره گوشی قبلی، رمز ورود نیز باید عوض شود.

## اجرای Android و محدودیت‌ها

- نمونه7: تماس101→103 بعد ازHome وscreen-off اندروید15؛ نام+داخلی، پاسخ،Bridge وRTP دوطرفه بدونSTUN عمومی. Bridge تا01:24 مشاهده شد؛ uptimeرسانه01:39 و شمارنده‌های هر دو جهت غیرصفر بودند. evidence/release7-bridge-80s.txt وrelease7-rtp-80s.txt.
- نمونه8: شروع سردcontainer15 بدون بازکردنActivity؛ سرویسFGS بالا آمد، حساب وSIP103 بازیابی شد وLauncher جلو بود. تماس ورودی به همین حالت، پاسخ،Bridge/RTP و پایان ازUI/صفرکانال PASS. شواهدrelease8-boot-* وrelease8-bridge/rtp/end-count؛ تصویرrelease8-cold-incoming15.png.
- SIGKILL آزمایشی15: بازیابی در12ثانیه FAIL؛ سیستم restart را حدود50ثانیه پس ازkill اجرا کرد، سپس فرایند تازه وSIP تازه بدونActivity مشاهده شد. FAIL اولیه درrelease8-process-restart.json حفظ و مشاهده بعدی جدا درrelease8-process-restart-extended.json ثبت است. دریافت در فاصله بازیابی تضمین‌شده نیست.
- نمونه9: اعلان ورودی8 ساخته شد ولیscreen-off بیدار نشد؛ FAIL و تصویر آن نگه داشته شدند. نمونه10 با مسیرlegacy اصلاح‌شده صفحه را بیدار کرد؛ نام/داخلی، پاسخ وRTP دوطرفه مشاهده شدند.
- **همان APK15 نهایی QA:** روی8 و15 نصب شد؛ با8 درHome/screen-off، تماس103→101 صفحه ورودی با نام/داخلی را نشان داد، پاسخ گرفت وBridge/RTP دوطرفه ثبت شد. درuptime63/65ثانیه Rx/Txهای1077/2633 و2633/1077،lost0 ثبت شدند. پایان ازUI و صفرکانال بررسی شد. evidence/release15-final-rtp-later.txt وfinal-channels.txt؛ تصویرrelease15-incoming8.png. این PASS در دامنه شبیه‌ساز است، نه صدای شنیداری.
- آزمون‌ها روی شبیه‌ساز با battery exemption از ابزارQA انجام شدند؛ این مجوز روی گوشی واقعی خودکار اعطا نمی‌شود. Force stop نیازمند بازکردن دوباره اپ است؛ اولین نصب/قبل از اولینunlock هم آماده دریافت معرفی نمی‌شود. قفل30دقیقه/idle2ساعت،Doze واقعی گوشی،OEM،قطع/وصل شبکه وصدای واقعی هنوزBLOCKED/NOT_RUN هستند.
- در یک اجرای سنگین اولیه،15 توسطLMK بسته و8 دچارSystemUI ANR شد؛ evidence/android8-systemui-anr.png نگه داشته شد. نصب وسط تماس نیز فرایند قبلی را قطع و یک نمونهRTP ناقص کرد؛ آن اجرا PASS نشد. شواهد اجرای موفق جای این شکست‌ها را حذف نمی‌کنند. ANR/شرایطGPU شبیه‌ساز، نتیجه همه گوشی‌ها نیست.

## مانع قطعی تحویل امن

**T66 = FAIL:** WebRTC SDK150.7871.04 هنوز مقدار احراز موقتICE را درINFO بومی می‌نویسد. هیچ raw credential در این گزارش/evidence صادر نشده؛ فقط شمارنده وtimeline غیرحساس ثبت شدند. تنظیمnone، پاک‌کردنLogSink،خاموش‌کردنtracer وguard پیش ازSDP این معیار را پاس نکردند. timeline نمونه15، سه اجرای تنظیم و سپس وقوع لاگSDK را نشان می‌دهد؛ صرف اجرایAPI تنظیم، مدرک رفع نیست.

SDK144.7559.15 درtrial به‌دلیل API enableSctpSnap باFlutter فعلی build نشد؛ exit1 وrollback ثبت شدند. pin150 حفظ شد وresolve واقعی آن درfinal-sdk-resolution.log است. تغییر نسخه بدون آزمون پذیرفته نشد. patches/webrtc/0001-redact-local-ice-log.patch فقط پیشنهاد سورس است؛ تطبیق/اعمال/ساختAAR اصلاح‌شده NOT_RUN است و ادعای رفع ندارد. مرحله بعد، ساختSDK اصلاح‌شده برای سهABI، ثبتchecksum واقعی و آزمون دوباره لاگ/تماس است؛ native binary یا حافظهSDK patch نشده است.

## باینری فقط برای بازبینی QA

- artifacts/android/mini-voip-free-0.2.1+15-lan.apk
- SHA256:`011a169db15a8c25d8c433d0c59e544911049a03d4839a62f21e8fccd8fb3799`
- امضای محلیAndroid Debug؛ امضای سازمانی/انتشار رسمیBLOCKED. APK universal باarmv7/arm64/x86_64؛ minSdk26،targetSdk36 به‌معنی ادعای آزمونAndroid16 نیست.
- اسکن شناخته‌شده سورس/APK فقط معیارstatic است؛ جای لاگruntime/IPA/image audit را نمی‌گیرد. نبودFirebaseSDK جدا بررسی شده است. RuntimeلاگFAIL، حتی باstatic scanPASS، مانع پذیرش باقی است.
- APKهای بینابین از صفحه دریافت و پوشه تحویلDesktop کنار گذاشته شدند؛ فایل‌هایQA درartifacts برای بازبینی مانده‌اند. صفحه8765 نسخه جدید را منتشرشده/امن معرفی نمی‌کند.

راهنمای پنل/CLI: docs/ADMIN_SERVER.fa.md؛ راه‌اندازی عمومی دریافت مستقیم: docs/DIRECT_RECEPTION.fa.md. پنل روی همینPC: http://127.0.0.1:5080/admin . رمز مدیر فقط در فایل خصوصیdeploy/secrets/admin-password است، نه این گزارش. backup پیش ازmigration به‌صورت رمز‌شده در.tool-results/phase2/pre-admin-db.tar.gz.enc و کلید فقط درsecrets نگه داشته شد؛ restore این مرحله آزمون نشده است.

## بررسی پایان اجرا

بررسی نهایی `./smi check`، syntax فایل `server` و آزمون دوباره wrapper9 و قفل راه‌انداز4 با exit0/PASS انجام شد؛ شواهد final-static-check.log، final-wrapper-check.log و final-launcher-check.log هستند. هش APK نصب‌شده روی هر دو محیط QA با باینری15 برابر بود (final-installed-hashes.json). وضعیت نهایی سرور live/ready200 و صفر تماس/کانال است (final-server-status.txt و final-channels.txt).

پس از حفظ مدارک FAIL، فقط اپ‌های دو محیط QA متوقف و بافر logcat آن‌ها پاک شدند؛ سرور و گوشی‌های واقعی دست‌نخورده‌اند. این پاک‌سازی هیچ تغییری در نتیجه T66=FAIL نمی‌دهد (qa-cleanup.json). اپ‌های QA اکنون در وضعیت force-stop هستند و برای آزمایش بعدی باید دوباره باز شوند.
