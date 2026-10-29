# بررسی هنگ Android15 و SystemUI/Quickstep — 2026-10-29

بار دائمی CPU کاهش یافت، اما رفع کامل SystemUI روی SDK/TCG تأیید نشد. مسیر جایگزین Android15 بومی آماده شده و فعلاً برای فعال‌شدن Binder به اقدام محلی administrator نیاز دارد. APK و سرور محصول تغییر نکرده‌اند؛ شکست‌های قبلی حفظ شده‌اند.

## یافته‌ها و اقدام‌ها

- میزبان Ubuntu/VMware با4vCPU و7.2GiB RAM/4GiB swap است؛ `/dev/kvm` و پرچم vmx/svm در اختیار این مهمان نیستند. API35 با TCG اجرا می‌شود.
- با scrcpy فعال، سرویس `media.swcodec` مهمان مصرف CPU بالایی داشت. اندازه‌گیری12ثانیه‌ای پردازش API35 روی میزبان:107.91٪ با scrcpy،34.08٪ پس از بستن فقط همان نمایشگر. `mirror-ab.json` شاهد این مقایسه است؛ بقیه تنظیمات در این A/B عوض نشدند.
- اندازه فیزیکی API35 هنوز720x1280 بود و فقط override مهمان480x800 شده بود. تنظیم فیزیکی480x800/density160 شد؛ اطلاعات حساب پاک نشد.
- نمایش مستقیم Qt با `QT_QPA_PLATFORM=xcb` جای کدگذاری ویدئو درون مهمان را می‌گیرد. نسخه SDK همان37.3.5/build16632760 است. هیچ image جدیدی دانلود نشده است.
- EGL میزبان VMware SVGA3D را گزارش کرد (`host-egl.json`). آزمایش صریح GPU میزبان هنوز warning سازگاری، ANR و رندر ناقص Flutter داشت و کنار گذاشته شد؛ نتیجه آن PASS معرفی نمی‌شود.
- SystemUI و Launcher3/Quickstep در وضعیت ART=`verify` بودند. با `cmd package compile -m speed` کامپایل شدند و وجود واقعی artifact با `pm art dump` تأیید شد. اسکریپت `scripts/qa/prepare-api35-art.sh` اجرای ترتیبی، رد کامپایل هم‌زمان و اعتبارسنجی artifact را دارد.
- نسخه اولیه worker کامپایل اشتباهاً هم‌زمان اجرا شد. اجرای تکراری متوقف شد؛ خروجی خام Failure همراه exit0 در `draft-art-worker.log` نشان می‌دهد exit0 اندروید به‌تنهایی معتبر نیست. هیچ PASS آن worker پذیرفته نشده است. اجرای معتبر بعدی `prepare-art-validated.log` و فایل‌های `*-art.txt` دارد.
- پس از خاموشی یک اجرای قبلی، QEMU تک‌نخی بدون handle مهمان و با مصرف نزدیک100٪ باقی ماند؛ همان پردازش متعلق به اجرای بسته‌شده پاک شد. راه‌انداز جدید هر engine را در process group مستقل اجرا می‌کند و فقط باقی‌مانده همان گروه را پس از خروج engine جمع می‌کند. در stop اجرای native2، state حذف شد و هیچ QEMU در گروه مربوط باقی نماند (`native2-leftovers-after-stop.txt`).
- قفل startup میزبان، بوت سرد دو AVD را ترتیبی می‌کند؛ پس از آماده‌شدن، هر دو می‌توانند هم‌زمان مقیم و قابل تماس باشند. engine قفل startup را به ارث نمی‌برد.

## آزمایش‌های حفظ‌شده

| آزمون | وضعیت | شاهد و توضیح |
|---|---|---|
| A/B حذف scrcpy روی API35 | PASS در دامنه اندازه‌گیری CPU | `mirror-ab.json`؛ حدود68٪ کاهش در این نمونه کوتاه |
| نمایش مستقیم، GPU میزبان، دو هسته، ART اولیه | FAIL | `native1-result.json`، `native1-anr-events.txt`، `native1-current.png`؛ ANR سیستم/Quickstep/Phone/Bluetooth |
| کامپایل معتبر SystemUI و Quickstep | PASS | `prepare-art-validated.log`، `systemui-art-after.txt`، `launcher-art-after.txt`؛ status=speed |
| نمایش مستقیم/GPU میزبان پس از AOT | FAIL | `native2-result.json`؛ bootReady196.48s، ثبت SIP در253.4s، پنج رویداد ANR و تصویر ناقص؛ GPU میزبان رد شد |
| SwiftShader جدید، Vulkan غیرفعال، یک هسته، AOT | FAIL در دامنه بوت بدون ANR | `native3-result.json`؛ bootReady210.46s و ثبت SIP288.52s؛ چهار ANR شامل SystemUI، تصویر خود اپ درست و حساب خودکار ثبت شد |

probe طولانی native1 با exit143 پیش از نوشتن نتیجه نهایی متوقف شد؛ داده‌های مستقل رویداد/تصویر و محدودیت در `native1-result.json` ثبت شده‌اند. native2 با exit0 اجرا شد، اما وضعیت آزمون FAIL است؛ وضعیت عملکرد از exit خود ابزار استنتاج نشده است.

## محدوده تغییر و منابع

فایل‌های فعلی این کار: `scripts/qa/launch-emulator.sh`، `scripts/qa/prepare-api35-art.sh`، `docs/decisions/0008-software-emulator-stability.md` و همین شواهد. کپی نصب‌شده راه‌انداز: `/home/changer/.local/bin/mini-voip-emulator`؛ تنظیم AVD: `/home/changer/.android/avd/mini-voip-api35.avd/config.ini`. نسخه قبل در `launcher-before.sh` و `api35-config-before.ini` حفظ شده‌اند.

روش برگشت تنظیم AVD: پس از بستن آن، config قبلی را از `api35-config-before.ini` بازگردانید و launcher-before را جایگزین کنید. برای برگرداندن ART به حالت قبلی می‌توان برای همین دو package، `cmd package compile -m verify -f PACKAGE` اجرا کرد؛ این دستور rollback در این مرحله اجرا نشده و اطلاعات حساب را پاک نمی‌کند. هیچ watchdog/تشخیص ANR یا سرویس SystemUI/Quickstep برای سبزکردن گزارش غیرفعال نشده است.

مستندات اصلی: [شتاب‌دهی Emulator](https://developer.android.com/studio/run/emulator-acceleration)، [فیلترهای ART](https://source.android.com/docs/core/runtime/configure)، [پیکربندی ART Service](https://source.android.com/docs/core/runtime/configure/art-service)، [README رسمی ART Service](https://android.googlesource.com/platform/art/+/main/libartservice/service/README.md). در این منابع verify بدون AOT و speed با کامپایل همه متدها توضیح داده می‌شوند؛ توصیه عمومی جای نتیجه آزمایش این سیستم نیست.

## نتیجه SDK و حدود بهبود

در native2 و native3 هیچ رویداد ANR برای Quickstep/Launcher3 ثبت نشد؛ این مشاهده در دو بوت است و تضمین رفع دائمی آن نیست. **SystemUI در هر دو بوت همچنان ANR داشت.** native3 با SwiftShader جدید تصویر اپ را درست نمایش داد و حساب را بدون رمز بازیابی کرد، ولی دیالوگ SystemUI روی آن باقی ماند (`native3-followup.png`). بنابراین آن پروفایل فقط fallback قابل‌بازگشت است و «راه‌اندازی قابل‌اعتماد بدون دخالت» محسوب نمی‌شود.

در خاموش‌کردن درخواستی native3، SDK با exit139 و Segmentation fault خارج شد؛ خود آن exit موفق نیست. wrapper دو باقی‌مانده QEMU متعلق به همان گروه را جمع کرد و مصرف CPU اضافی رها نشد (`native3-emulator.log`). سابقه این خرابی SDK حذف یا به PASS تبدیل نشده است.

Android8 با نمایش مستقیم دوباره بوت شد، حساب101 ثبت و صفحه آماده دیده شد؛ ANR جدید در events دیده نشد (`api26-native-ready.png`، `api26-native-anr.txt`، `contacts-current.txt`). این بررسی PASS در دامنه startup همان شبیه‌ساز است.

## مسیر جایگزین آماده‌شده: Android15 بومی در کانتینر

کرنل فعلی7.0.0-42-generic ماژول امضاشده `binder_linux.ko.zst` و پشتیبانی Binder دارد، اما ماژول هنوز بارگذاری نشده است. تصویر رسمی ReDroid Android15 amd64/64only با Digest ثابت زیر از رجیستری رسمی resolve شد:

`sha256:58e548d78c4854f032912757dc0782d7a86b9d602ffc10b2f09fb9e86731adf3`

میرور DaoCloud با خطای media type شکست خورد (`redroid-mirror-pull.log`، exit1). دریافت از میرور چین `docker.1ms.run` کامل و Digest دقیقاً با مرجع رسمی یکسان شد (`redroid-mirror2-pull.log`، exit0، `redroid-official-manifest.json`، `redroid-image-verified.txt`). وابستگی QA در `toolchain.lock.json` با تصمیم0009 ثبت شده است. Android9–14 یا16 دانلود نشده‌اند.

کانتینر جداگانه `smi-qa-android15` با `qa/redroid-compose.yaml` ساخته شده ولی **Created/غیرفعال** است. این کانتینر Android طبق روش رسمی ابزار privileged است؛ فقط داده خصوصی QA را mount می‌کند و ADB فقط `127.0.0.1:5565` دارد. در stack سه‌سرویسی محصول وارد نشده و autostart ممتاز در بوت نصب نشده است. تصویر نرم‌افزاری، memfd،480x800/density160 و سقف2CPU/2560MiB تنظیم شده‌اند. داده و حساب AVD قبلی دست‌نخورده حفظ شده و هیچ داخلی/credential جدیدی در این مرحله ساخته یا reset نشده است.

**وضعیت اجرای مسیر جایگزین: BLOCKED.** `scripts/qa/start-android15-container.sh` با exit3 علت واقعی نبودن Binder را گزارش کرد؛ گزارش آن `redroid-start-prerequisite.log` است. `sudo -n true` نیز احراز هویت local را در دسترس نشان نداد. برای ادامه، دستور محلی زیر لازم است:

```bash
sudo sh /home/changer/Desktop/flash/mini-voip-free/scripts/qa/enable-qa-binder.sh
```

اسکریپت فقط `modprobe binder_linux` درایور موجود را اجرا و بارگذاری واقعی را بررسی می‌کند؛ نصب پکیج، تغییر IP/شبکه، تغییر بوت یا دریافت رمز در چت ندارد. پس از فراهم‌شدن این پیش‌نیاز، آزمون‌های boot/reboot، SystemUI/Quickstep، نصب همان APK، بازیابی حساب و تماس/RTP/قطع باید روی کانتینر انجام شوند. **این آزمون‌ها هنوز NOT_RUN هستند؛ کانتینر آماده با Android15 آزموده‌شده یکی نیست.**

## وضعیت تحویل همین مرحله

- فایل APK همان `mini-voip-free-192.168.1.151-startup-fix.apk` با SHA256 `565ecc09c5f9f02c91aa52277bc9df47900aa5a9d9c75fdb63fdf37d0df0d335` است؛ نیازی به APK تازه برای این تنظیمات محیط نیست.
- تغییرات: چهار helper در `scripts/qa/` (راه‌انداز، آماده‌سازی ART، فعال‌سازی Binder و شروع کانتینر)، `qa/redroid-compose.yaml`، تصمیم‌های0008/0009، قفل وابستگی QA و گزارش‌ها/مستندات وضعیت. IP سرور همچنان192.168.1.151 و readiness واقعی db/ami برابرok است. صفر کانال فعال در پایان ثبت شده است.
- `./smi check`، `bash -n` helperها و `docker compose -f qa/redroid-compose.yaml config --quiet` با exit0 اجرا شدند. 88 تست محصول مربوط به گزارش startup-fix قبلی‌اند و در این مرحله دوباره به‌عنوان تست جدید ادعا نمی‌شوند؛ کد محصول تغییر نکرده است.
- آزمون تماس تازه روی محیط Android15 جدید هنوز NOT_RUN/BLOCKED به‌علت پیش‌نیاز کرنل است. تماس موفق گزارش قبلی را جای تماس محیط جدید نمی‌گذاریم.
- Android8 باز و آماده است؛ SDK Android15 پس از ثبت شکست برای آزادشدن منابع متوقف شد؛ کانتینر Android15 آماده ولی اجرا نشده است.
- CodeReady کامل محصول، DeviceValidated و Published از این مرحله نتیجه نمی‌شوند. گوشی واقعی، صوت شنیداری، Push و قفل همچنان BLOCKED هستند؛ همه60 ردیف پذیرش حفظ شده‌اند.

مرجع تصویر جایگزین و تنظیم‌های Binder/memfd/گرافیک: [مستندات رسمی ReDroid](https://github.com/remote-android/redroid-doc). این روش اجرای native روی کرنل میزبان است و مشکل TCG را دور می‌زند؛ موفقیت روی این میزبان فقط پس از آزمون واقعی قابل اعلام است.

## ادامه پس از اقدام محلی کاربر

بلاک Binder در ادامه رفع شد و تنظیم pids کانتینر اصلاح شد. نتایج محیط جدید، تماس‌ها و بوت‌های سرد در [گزارش ادامه Android15 بومی](../2026-10-29-native-android15/REPORT.fa.md) ثبت‌اند؛ شکست‌های SDK و مرحله اولیه این گزارش تاریخی حفظ شده‌اند.
