# اصلاح دریافت پس از حذف از Recent و ادامه زنگ پس از پاسخ

تاریخ: 2026-11-01. **نسخه 0.2.2+21 برای آزمون دستی دو گوشی آماده است.** دریافت پس از حذف task و قطع زنگ در QA بررسی شدند؛ تأیید رفع روی گوشی‌های مالک هنوز به نصب و آزمون این نسخه وابسته است.

مالک مشخص کرد اپ را با کنارزدن کارت از برنامه‌های اخیر می‌بندد. آخرین APK تحویل‌شده16 بود؛ نسخه نصب‌شده روی گوشی‌ها مستقلاً خوانده نشد. گزارش خطای مالک در تاریخچه پذیرش حفظ شده است.

## تغییرات

- اعلان زنگ4101 با اعلان مکالمه بی‌صدای4102 جابه‌جا و اعلان قبلی صریحاً cancel می‌شود. قصد پاسخ از UI، پیش از HTTP/SIP، و پاسخ از اعلان، پیش از event به Dart، زنگ را ساکت می‌کند. latch بومی مانع برگشت زنگ با فرمان دیرهنگام است.
- همان سرویس foreground آماده‌باش، مالک اعلان تماس است؛ دریافت تماس به شروع سرویس foreground دوم از پس‌زمینه وابسته نیست. پایان تماس، اعلان آماده‌باش4201 را برمی‌گرداند. Core-Telecom و WebRTC همچنان مالک مسیر صوت هستند.
- چند کارت واقعی MiniVoIP در Recentها مشاهده شد. Activity به singleTask با affinity پیش‌فرض تغییر کرد. هنگام ایجاد Activity، فقط taskهای قدیمی همین اپ پاک می‌شوند؛ حساب و engine حفظ می‌شوند.
- نبود مجوز اعلان، کانال فعال، معافیت باتری یا سرویس زنده، وضعیت سبز آماده‌باش نمی‌دهد و دکمه تنظیمات دارد. پنج تست جدید، ترتیب خاموشی زنگ پیش از accept کند و چهار شرط آمادگی را بررسی می‌کنند.
- شناسه‌های wire، موتور SIP و SDK144 تغییر نکردند. حساب/رمز104 و105 تغییر یا reset نشد. تصمیم0016 مرجع جزئیات است.

## وضعیت مستقل

| وضعیت | نتیجه |
|---|---|
| CodeReady اصلاحات و نامزد تست دستی | PASS در دامنه آزمون‌های زیر؛ پذیرش کامل پروژه ادعا نیست |
| DeviceValidated روی دو گوشی مالک | BLOCKED تا نصب21 و آزمون واقعی |
| Deployed | APK21 روی QA8/15 نصب و آزموده شد؛ دریافت آزمایشی LAN آماده است |
| Published رسمی | BLOCKED؛ امضای محلی Debug است؛ commit/push این مرحله انجام نشد |

## همان باینری نهایی

فایل: `artifacts/android/mini-voip-free-0.2.2+21-lan.apk`

SHA256: `5a02949c8898f49a7d3e2026e109fb5d0a7e246342f78366b5720bc3bdda0393`

APK شامل armv7،arm64 وx86_64، با minSdk26 وtargetSdk36 است. اجرای Android16 ادعا نشده است. هش نصب‌شده هر دو API26/35 با فایل دانلود برابر و امضا با APK4 کاربر یکسان است؛ نصب به‌صورت Update حساب را حفظ می‌کند. هر سه کتابخانه native دقیقاً برابر AAR144 قفل‌شده‌اند.

## آزمون‌های واقعی

| آزمون/فرمان | نتیجه | مدرک در evidence/ |
|---|---|---|
| `./smi build android --release` باIP151 وCA همین نصب | PASS؛ exit0،40.1ثانیه | build21.log |
| `./smi test unit --json` | PASS؛ exit0،52Control+54Flutter+9wrapper+4قفل=119 | unit21-final.log |
| `./smi check` و `git diff --check` | PASS؛ exit0 | check21-final.log،diff-check.txt |
| swipe واقعی افقی کارت Recent درAndroid8 | PASS؛ کارت وActivity حذف؛ PID و سرویس باقی ماند | swipe8-dismiss.json،closed8-state.json |
| تماس پس از همین swipe8، پاسخ،RTP وقطع | PASS؛ زنگ/لرزش4101؛ پس ازپاسخ هردوnull و4102؛ پایان4201 و صفرکانال | closed8-state.json،closed8-rtp.txt |
| حذف rootTask ایزوله همین اپ درAndroid15 ازActivityManager | PASS؛ بدونActivity، با سرویس/PID ثابت؛ تماس، پاسخ،RTP وقطع | task15-state.json،task15-runner.json |
| Android8 با صفحه خاموش، پاسخ و قطع زنگ | PASS؛ soundKey/vibrateKey پیش ازپاسخ4101 و پس ازپاسخnull | lock8-state.json |
| ادامه همان مکالمه پس از مهلت setup | PASS؛ hold60ثانیه اضافه،RTP درuptime72/75ثانیه،lost0 | lock8-hold60.json،lock8-rtp-after60.txt |
| گیت لاگ پس از سه تماس نهایی | PASS؛ هر فرایند9marker، صفرICE/SDP/Authorization/FATAL | final-runtime-log-gate.json |
| هش نصب‌شده، امضا و سهABI | PASS | installed-and-upgrade21.json،signer21.txt،apk21-provenance.json |
| اسکن credentialهای شناخته‌شده درسورس/APK | PASS دردامنه اسکن؛ جایauditکامل نیست | secret-scan21.json |
| دریافت کامل از151:8765 توسطPC | PASS؛90,693,370بایت و هش یکسان | http-download21.json |

سه تماس نهایی، پانزده مرحله prepare/start/answer/media/end را با exit0 طی کردند. این عدد، آزمون گوشی فیزیکی نیست. در مکالمه بلند، Rx/Tx دوطرفه1325/3369 و3387/1325 باlost0 ثبت شد. پاسخ از طریق Intent همان اکشن اعلان به Activity تحویل شد؛ لمس دکمه روی گوشی واقعی ادعا نمی‌شود. تست واحد جدا ترتیب خاموشی زنگ از UI را پیش از انتظار شبکه ثابت می‌کند.

در QA15، محدودکردن باتری روی نمونه19، هشدار و دکمه تنظیمات را نشان داد؛ منطق همان بخش در21 تغییر نکرده و چهار حالت آن در unit21 نیز PASS است. مجوزهای QA با ابزار تست تنظیم شدند؛ روی گوشی مالک خودکار اعطا نمی‌شوند.

## شکست‌ها و حدود شواهد

- Baseline16 با Back اعلان صوتی داشت؛ runner به‌اشتباه دنبال تمام‌صفحه درحالت unlocked بود و FAIL شد. این، بازتولید کامل خطای swipe گوشی مالک نبود. نبود تمام‌صفحه در حالت unlocked لزوماً نبود زنگ نیست.
- نمونه18 هنگام ارسال CallStyle مکالمه بدون اتصال foreground با IllegalArgumentException بسته شد. metadata کرش حفظ و این نمونه منتشر نشد. مسیر اصلاح‌شده در19 و سپس21 تست شد. نمونه17 و20 فقط build شدند؛ DeviceValidated برای آن‌ها ادعا نمی‌شود.
- نصب19 پیش از آماده‌شدن PackageManager مهمان، با NullPointerException شکست خورد؛ بعد از boot تکرار شد. نصب21 پس از boot و با هش مستقل تأیید شد.
- Android8 در ابتدا device_provisioned=0 وuser_setup_complete=0 داشت و NMS صداهای اعلان را غیرفعال کرده بود؛ تستsoundKey آن وضعیت FAIL شد. فقط fixture QA تکمیل راه‌اندازی و reboot شد؛ سپس mDisableNotificationEffects=false و زنگ سیستم در21 تأیید شد. کد اپ برای دورزدن DND تغییر نکرد.
- SystemUI شبیه‌ساز8 یک بار ANR داد و runner فیلد شماره‌گیری را پیدا نکرد. FAIL و تصویر/metadata حفظ است؛ علت دقیق ANR ثابت نشد. پس از Wait، اجرای نهایی تکرار و PASS شد. رفع کامل هنگ شبیه‌ساز ادعا نمی‌شود.
- حرکت لمسی تزریق‌شده در Overview15 کارت را حذف نکرد و prepare آن FAIL شد. موفقیت gesture روی15 ادعا نمی‌شود. تست مثبت15 از حذف فقط rootTask ایزوله اپ استفاده کرد و callback حذف task و دریافت بدونActivity را بررسی کرد. روی8 خود swipe واقعی تأیید شد.
- چند prepare به‌علت shade باز یا شرط اشتباه resumedActivity در screen-off نیز FAIL شدند؛ state اولیه جدا حفظ است. اجرای مثبت، شکست‌ها را حذف نمی‌کند.

صدای شنیداری واقعی، Doze/قفل طولانی، رفتار همه سازندگان، Android9–14 و صدای بلندگو روی گوشی فیزیکی هنوز NOT_RUN/BLOCKED هستند. SoundKey فقط درخواست پخش سیستم و قطع آن را ثابت می‌کند، نه شنیدن صدا از اسپیکر واقعی. Force stop/Stop سیستم، خاموشی سرور، قطع شبکه و فاصله بازیابی فرایند پس ازkill تضمین دریافت ندارند؛ حذف کارت از Recent با این موارد یکی نیست.

## تحویل و مرحله بعد

دریافت: `http://192.168.1.151:8765/`؛ همان APK در Desktop «Mini VoIP Manual Test» هم هست. صفحه فقط APK و راهنمای عمومی دارد. سرویس دریافت APK موقت است؛ برگشت خودکار آن پس از خاموش‌شدن PC ادعا نمی‌شود. سرور App/CLI/Docker جداست.

راهنما: `docs/PHONE_RC_TEST.fa.md`. روی هر دو گوشی Update کنید، یک بار اپ را باز و آماده‌باش/مجوزها را بررسی کنید؛ سپس همان swipe و پاسخ را دوطرفه تست کنید. داده/رمز104 و105 تغییر نکرده است.

فایل‌های اصلی: MainActivity/Manifest وoverlay، SmiIncomingService،SmiTelecomCallService،SmiCalls،SmiNativeChannels،CallController،DialerPage،تست رگرسیون،قراردادNative،تصمیم0016،راهنماها/پذیرش و راه‌اندازQA15. `changed-files.txt` کل ورک‌تری را ثبت می‌کند و شامل تغییرات قدیمی commitنشده هم هست.

پس از ثبت شواهد، فقط شبیه‌ساز8 و کانتینرQA15 برای آزادکردن منابع تست گوشی‌ها متوقف شدند؛ داده/حساب آن‌ها حفظ است. سرور Control/PBX/Edge و دریافتAPK فعال مانده‌اند. وضعیت پس از پاک‌سازی: live/ready200 و صفر تماس؛ شواهد `qa-cleanup.json`، `server-status-after-cleanup.txt` و `channels-before-cleanup.txt`.
