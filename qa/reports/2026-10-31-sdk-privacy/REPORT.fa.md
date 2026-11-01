# رفع لاگ SDK و نامزد تست دو گوشی

تاریخ: 2026-10-31. نسخه: **0.2.1+16**. هدف، آماده‌کردن APK برای آزمون قفل، پس‌زمینه و بلندگو روی دو گوشی مالک، بدون حساب Google یا Firebase است. شکست‌های نسخه‌های قبلی در گزارش phase2 و تاریخچه آزمون T66 حفظ شده‌اند.

## علت و اصلاح

در شاخه `m150_release`، destructor لاگ از `LoggingConfig.debug_severity` استفاده می‌کند، اما JNI اندروید در `LogToDebug` فقط `g_dbg_sev` را تغییر می‌دهد. بنابراین تنظیم `LS_NONE` از API قدیمی، مسیر جدید خروجی INFO را خاموش نمی‌کرد. مرجع سورس: https://github.com/webrtc-sdk/webrtc/blob/a802fa9849e0dae7f54c7d3deb05820a674b2f46/rtc_base/logging.cc .

SDK به **144.7559.15** با رابط سازگار Flutter تغییر کرد؛ تصمیم `0015-sdk-logging-compatible-144.md`، checksum واقعی و نتیجه آزمون ثبت‌اند. در نسخه محلی plugin1.6.3 فقط دو فایل upstream تغییر کرده‌اند: pin وابستگی Android، خاموش‌کردن tracer و رد صریح فعال‌سازی SNAP/WARP که فیلد آن در SDK144 نیست و محصول استفاده‌اش نمی‌کند. گزینه false و تماس صوتی عادی حفظ شده‌اند.

سورس plugin همراه LICENSE و NOTICE در `third_party/flutter_webrtc` است و با path override صریح مصرف می‌شود. pub-cache عمومی تغییر نکرد. patch و هش فایل‌های upstream در `patches/webrtc/` قرار دارند. هر سه کتابخانه native داخل APK دقیقاً با AAR144 اصلی برابرند؛ patch باینری یا حافظه انجام نشده است. patch پیشنهادی قبلی C++ برای SDK150 همچنان NOT_RUN و استفاده‌نشده است.

## نتایج واقعی

| آزمون | نتیجه | مدرک در evidence/ |
|---|---|---|
| ساخت Release از `./smi build android` با IP151 و CA عمومی همین نصب | PASS؛ exit0، زمان ساخت70.8ثانیه | build16-verified.log |
| `flutter analyze` و `flutter test` با وابستگی جدید | PASS؛ exit0، بدون issue و49تست | analyze16.log، flutter-tests16.log |
| `./smi check` | PASS؛ exit0 | static-check16.log |
| تطبیق کتابخانه‌های armv7/arm64/x86_64 با AAR144 | PASS | apk-native-provenance.json، provenance.json |
| تطبیق امضا با APK4 نصب‌شده روی گوشی‌های مالک | PASS؛ امکان Update بدون حذف اپ | upgrade-signer.json، signer16.txt |
| تماس101→103 و103→101، با Home و صفحه خاموش مقصد | PASS؛ صفحه پاسخ، Bridge مشترک و RTP دوطرفه | to15-start.json، to8-start.json، to8-rtp-final.txt |
| لاگ پس از تماس هر دو جهت | PASS؛ هر دستگاه6marker، صفر ICE/SDP/Authorization/FATAL | after-both-directions-log-gate.json |
| شروع سرد container15 بدون فرمان بازکردن Activity | PASS؛ سرویس آماده‌باش و SIP در11.48ثانیه مشاهده شدند | cold15-restore.json |
| تماس پس از شروع سرد15، با صفحه خاموش | PASS؛ پاسخ و RTP دوطرفه، lost0 در uptime01:43 | cold-to15-start.json، cold-to15-media-run.json، cold-to15-rtp-later.txt |
| لاگ پس از تماس شروع سرد | PASS؛8با9marker و15با3marker، صفر موارد حساس/FATAL | after-cold-call-log-gate.json |
| روشن/خاموش‌کردن بلندگو در UI هر دو محیط | PASS در دامنه UI؛ صدای شنیداری NOT_RUN | to8-controls.json، to15-controls-retry.json |
| اسکن secretهای شناخته‌شده در سورس/APK | PASS؛22variant بدون match؛ جای audit کامل نیست | secret-scan16.json |
| دریافت کامل APK از HTTP151:8765 توسط PC | PASS؛ هش برابر با باینری آزموده‌شده | http-download16.json |

فرمان ساخت موفق:

```bash
source /home/changer/.config/mini-voip-free/env.sh
./smi build android --release --server-host 192.168.1.151 \
  --trusted-ca-file .tool-results/sdk-privacy/lan-ca.crt
```

در تماس معکوس، قبل از قطع، uptime دو leg برابر55/57ثانیه و Rx/Tx برابر860/2272 و2379/860 با lost0 بود. پس از restart اندروید15، contact تازه SIP با socket تازه ثبت شد؛ هیچ `am start` برای بازیابی صادر نشد. سپس تماس تازه از101 دریافت و پاسخ داده شد. اثبات صوت در این مرحله به Bridge و شمارنده بسته‌ها محدود است.

گیت لاگ، خروجی فرایند هر اپ را فقط در حافظه بررسی و metadata/count ذخیره کرده است؛ raw log حاوی credential صادر یا چاپ نشده. marker ثابت اجرای تنظیم لاگ و RTP واقعی، نشان می‌دهند آزمون صرفاً روی اپ بی‌فعالیت انجام نشده است.

## شکست‌های حفظ‌شده

- فرمان اولیه ساخت به‌علت مسیر CA ناموجود exit2/FAIL داشت؛ با مسیر واقعی گواهی عمومی Caddy تکرار شد و PASS گرفت.
- اولین runner بلندگوی8 با runner پایان تماس هم‌پوشانی داشت و کنترل را پیدا نکرد: exit1/FAIL. این اجرا مدرک موفقیت محصول نیست. اجرای ترتیبی بعدی روی همان APK پاس شد؛ نتیجه شکست اولیه در `to15-controls-result.json` محفوظ است.
- پاک‌کردن buffer اصلی logcat اندروید8 error داد. گیت از PID فرایند تازه APK16 استفاده کرد و به موفقیت پاک‌سازی وابسته نبود.
- FAILهای SDK150 و build144 بدون patch در گزارش phase2 باقی‌اند. T66 نتیجه جدید PASS و سابقه FAIL قبلی را جدا نگه می‌دارد.

## باینری تحویل تست دستی

- فایل: `artifacts/android/mini-voip-free-0.2.1+16-lan.apk`
- SHA256: `bd41c1b0f995a529a1b355960679a56a779da382a211a13a95c7fa082966427d`
- SHA256 AAR144: `fc7c8d027eb33860ccbb7847988f7f942d44a92d1f575348bba6c0250cde4071`
- universal شامل armv7،arm64 وx86_64؛ minSdk26 وtargetSdk36. اجرای Android16 ادعا نشده است.
- امضای محلی Android Debug مانند نسخه قبلی؛ امضای سازمانی و انتشار رسمی BLOCKED است.
- صفحه دریافت آزمایشی: `http://192.168.1.151:8765/`؛ همان فایل در پوشه Desktop «Mini VoIP Manual Test» قرار دارد.
- فایل فقط با Update نصب شود؛ حذف اپ لازم نیست. حساب‌ها و رمزهای104/105 تغییر یا reset نشده‌اند.
- راهنما: `docs/PHONE_RC_TEST.fa.md`. دریافت APK جدید از خود گوشی‌ها هنوز NOT_RUN است؛ بررسی HTTP بالا از PC انجام شد.

## وضعیت و مرحله بعد

**CodeReady رفع لاگ و نامزد تست دستی:** PASS در دامنه آزموده‌شده. **DeviceValidated تغییرات جدید:** BLOCKED تا آزمون گوشی واقعی. **Deployed:** سرور محلی و دو محیط QA. **Published رسمی:** BLOCKED؛ فقط دریافت آزمایشی LAN آماده است. هیچ commit یا push در این مرحله انجام نشده است.

صدای شنیداری و مسیر اولیه گوشی، قفل30دقیقه/idle2ساعت، Doze واقعی، رفتار همه سازندگان و Android9–14 در این مرحله NOT_RUN/BLOCKED هستند. اجرای8 و15 تضمین همه گوشی‌ها نیست. Force stop دریافت را متوقف می‌کند و پس از آن باید اپ دوباره باز شود؛ نصب اولیه پیش از اولین اجرا و boot پیش از اولین unlock آماده دریافت معرفی نمی‌شوند. آماده‌باش مستقیم به سرویس دائمی و اتصال PBX وابسته است و باتری مصرف می‌کند.

مرحله بعد، آزمون هر دو جهت تماس روی گوشی‌های مالک طبق راهنما و ثبت نتیجه قفل، پس‌زمینه و مسیر صدا است.

## بررسی نهایی تحویل

هش APK نصب‌شده روی هر دو محیط با فایل دانلود برابر است (`final-installed-hashes.json`). پس از پایان تماس سوم، سرور live/ready200 و صفر تماس/کانال دارد (`final-server-status.txt`، `final-channels.txt`). آزمون دوباره wrapper9 و قفل راه‌انداز4، بررسی static و `git diff --check` با exit0/PASS انجام شدند؛ شواهد `wrapper16.log`، `launcher16.log`، `final-static-check16.log` و `diff-check16.log` هستند. اپ‌های QA به حالت بیکار برگشته‌اند؛ Force stop نشده‌اند.

فهرست فایل‌های تغییرکرده در `changed-files.txt` کل ورک‌تری را ثبت می‌کند و شامل تغییرات مراحل قبلی هم هست. فایل‌های اصلی این اصلاح: pin/override در pubspec وGradle وlock، منبع plugin درthird_party، patch و هش‌های upstream، تصمیم0015، پذیرشT66، راهنمای تست گوشی، صفحه دریافت و راه‌انداز QA15. باینری بعد از آزمون عوض نشده است.
