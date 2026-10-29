# گزارش اجرای محلی و تماس دو شبیه‌ساز — ۲۰۲۶/۱۰/۲۸

سرور و APK از `192.168.1.151` استفاده می‌کنند. دو شبیه‌ساز Android 8 / API 26 و Android 15 / API 35 با داخلی‌های ۱۰۱ و ۱۰۲ تماس برقرار کردند، پاسخ دادند و از طریق Asterisk بسته صوتی دوطرفه مبادله کردند. Android 9 تا 14 طبق درخواست دانلود نشده‌اند و اجرای واقعی روی آن نسخه‌ها NOT_RUN است.

این نتیجه، اعتبارسنجی گوشی واقعی یا تضمین بدون‌خطابودن کل محصول نیست. شبیه‌سازها با `-no-audio` اجرا شدند؛ شنیده‌شدن صدا، کیفیت میکروفن/گوشی/بلندگو و headset آزموده نشده‌اند.

## نتایج قابل بازبینی

| آزمون | نتیجه و شاهد |
|---|---|
| ورود و ثبت دو داخلی | PASS — `two-registered-contacts.txt` و `api35-login-result.json`؛ رمز حساب و SIP مستقل‌اند؛ `credential-handoff-live.json` |
| اندروید ۸ → اندروید ۱۵ | PASS در دامنه شبیه‌ساز — `eighth-call-result.json`؛ پاسخ از UI، Bridge مشترک، رشد RTP هر دو جهت، قطع و صفرشدن کانال‌ها |
| اندروید ۱۵ → اندروید ۸ | PASS در همان دامنه — `reverse-call-retry-result.json`؛ تصاویر `reverse-call-retry-caller.png` و `reverse-call-retry-callee.png` تایمر مکالمه را نشان می‌دهند |
| رد تماس | PASS پس از اصلاح — `decline-call-retry-result.json`؛ پاک‌شدن کانال‌ها و بازگشت هر دو UI به آماده |
| لغو هنگام زنگ | PASS — `cancel-call-result.json`؛ بدون کانال یا UI معلق |
| بی‌پاسخ معمولی | PASS — `timeout-call-result.json`؛ پاک‌شدن کانال‌ها ۴۱٫۶۳ ثانیه پس از timestamp ثانیه‌ای admission مشاهده شد؛ زمان شامل دقت timestamp و فاصله نمونه‌برداری است |
| آماده‌شدن دیرهنگام مقصد | PASS — `delayed-ready-timeout-result.json`؛ ready پس از ۱۵ ثانیه، پایان مشاهده‌شده در ۴۰٫۱۹ ثانیه از admission؛ مهلت دوباره شروع نشد |
| تست‌های خودکار | PASS — `unit-final.log`؛ ۴۵ تست Control، ۲۲ تست Flutter، ۸ تست wrapper، به‌همراه اعتبارسنجی قراردادها؛ exit 0 |
| بررسی مخزن و تحلیل Flutter | PASS — `check-final-current.log` و `analyze-message-rerun.log`، exit 0 |
| ساخت و امضای APK | PASS برای باینری آزمایش محلی — `android-message-build.log` و `apk-signature.txt`؛ امضای انتشار کارفرما هنوز BLOCKED |
| جست‌وجوی رمزهای واقعی شناخته‌شده در سورس/گزارش‌ها و APK بازشده | PASS در دامنه محدود — `known-secret-scan.json`؛ ۱۰ الگوی raw/base64 بدون تطابق. این نتیجه ممیزی کامل container/IPA نیست |

رشد واقعی RTP نمونه اول: دریافت/ارسال داخلی ۱۰۱ از ۵۶۲/۱۶۵ به ۷۷۹/۲۹۷ و داخلی ۱۰۲ از ۱۶۵/۴۹۰ به ۲۹۷/۷۰۷، codec=ulaw. در جهت عکس نیز هر دو شمارنده رشد کردند. شواهد در فایل‌های `*-media-*.txt` و `*-bridge-*.log` قرار دارند. صفرشدن کانال‌ها پس از هر سناریوی موفق ثبت شده است.

## اصلاحات انجام‌شده

- API ورود، رمز مستقل SIP را پس از احراز هویت و با `Cache-Control: no-store` تحویل می‌دهد؛ ذخیره امن حساب و SIP جدا است. DTO لاگ‌شونده رمزها را مخفی می‌کند.
- SIP دارای transport صریح WS روی WSS معتبر است؛ خطای شروع await می‌شود؛ INVITE خروجی attemptId و ورودی شناسه صادرشده سرور را بررسی می‌کند. پاسخ فقط پس از اقدام کاربر است.
- دکمه شماره‌گیری واقعاً کنترلر تماس را اجرا می‌کند. حالت‌ها، جهت تماس، انتظار admission و رقابت answer/INVITE اصلاح شده‌اند.
- API تماس، قرارداد عمومی `caller/callee/deviceGeneration/expiresAt/...` را می‌فرستد؛ ساختار داخلی دیتابیس/PBX بیرون داده نمی‌شود.
- اشتراک و مجوز خواندن AMI شامل `user` شده تا رویدادهای Dialplan دریافت شوند. پیام کنترلی ثابت SIP فقط اپِ باز را برای واکشی احرازشده وضعیت مطلع می‌کند؛ قابلیت چت یا جایگزین Push پس‌زمینه نیست.
- Dialplan از `CHANNEL(endpoint)`، نحو واقعی WaitForCondition و مهلت باقیمانده استفاده می‌کند. پیشوند `__` برای نوشتن متغیر ارث‌بری حفظ شده و خواندن با نام پایه است تا شناسه تماس خالی نشود.
- مسیرهای API رد/پایان، بعد از اولین انتقال اتمیک وضعیت فرمان Hangup می‌فرستند؛ تکرار درخواست این فرمان را دوباره فعال نمی‌کند. تست SQLite هم‌زمانی اضافه شده است.
- اعتماد به CA عمومی LAN فقط با گزینه ساخت `--trusted-ca-file` انجام می‌شود؛ chain/SAN و بررسی hostname/IP خاموش نشده‌اند.

فایل‌های اصلی تغییر: `services/control/src/Smi.Control/{Program.cs,Auth/SessionService.cs,Ami/AmiClient.cs,Ami/AmiCallCoordinator.cs,Calls/CallStore.cs,Calls/CallStateResponse.cs}`، تست‌های Control؛ `apps/mobile/lib/{main.dart,api,call,sip,secure,ui}` و تست‌های Flutter؛ پیکربندی Asterisk، اسکریپت‌های build/deploy، قرارداد OpenAPI و تصمیم‌های 0004/0005. فهرست کامل فایل‌های تغییرکرده با مسیر مطلق در `changed-files.txt` است. تغییرهای نصب مرحله قبل نیز در همین working tree هستند؛ commit یا انتشار ساخته نشده است.

## اجرای مجدد

از ریشه مخزن و پس از بارگذاری `/home/changer/.config/mini-voip-free/env.sh`:

```bash
./smi test unit
./smi check
./smi build android --release --server-host 192.168.1.151 --trusted-ca-file qa/reports/2026-10-28-local/lan-root-ca.crt
sg docker -c './smi server up'
```

شاهد هر فرمان در لاگ‌های نام‌برده بالاست. سناریوهای UI با ADB و شبیه‌سازهای 5554/5556 اجرا شدند. هیچ رمز یا access token در گزارش‌ها ثبت نشده است. نتیجه‌های FAIL اولیه حذف نشده‌اند؛ README انگلیسی همین پوشه، علت، اصلاح و بازآزمون هر تلاش را نگه می‌دارد. اولین اجرای اسکن اسرار به‌اشتباه README پوشه اسرار را خودش secret فرض کرده بود؛ این تشخیص نادرست در `known-secret-scan-first.json` حفظ و اسکن برای فایل‌های واقعی اسرار اصلاح شد.

## باینری و محدودیت تحویل

APK: `/home/changer/Desktop/flash/mini-voip-free/artifacts/android/mini-voip-free-192.168.1.151-call-test.apk`

SHA256: `faf53e2e7a1301635b601298c034ec489887a5b90967cdda73be0bad7448f436`؛ همان APK در تماس‌های موفق استفاده شد. این پروفایل مخصوص LAN و CA فعلی است و signing انتشار نهایی ندارد.

- CodeReady کامل: BLOCKED؛ آزمون‌های دامنه foreground محلی بالا پاس شده‌اند، اما کل الزامات محصول تحویل نشده‌اند.
- DeviceValidated: BLOCKED؛ گوشی واقعی در دسترس نیست. سناریوهای قفل، Doze، تماس سیستمی، Push واقعی و صوت فیزیکی تأیید نشده‌اند.
- Deployed در LAN: PASS؛ IP ثابت 151/24 و HTTPS readiness با db/ami=ok تأیید شد.
- Published: NOT_RUN. iOS، حساب/امضای اپل، FCM/APNs و keystore انتشار آماده نیستند.
- Android 9–14 و صدها چرخه/بار کامل آزموده نشده‌اند. از تست دو نسخه مرزی نمی‌توان سازگاری قطعی همه دستگاه‌ها را نتیجه گرفت.
- پس از restart سرور یک تلاش در بازه ثبت مجدد ناموفق بود؛ برای بازآزمون اپ بازگشایی شد. بازیابی بی‌وقفه پس از restart PBX تأیید نشده است.
- میزبان VMware فاقد KVM است. ANRهای System UI/Quickstep اندروید ۱۵ و یک توقف رابط اندروید ۸ ثبت شده‌اند. backend گرافیکی جدید swiftshader برای اجرای نهایی انتخاب شد. درخواست RAM کمتر در خط فرمان، طبق meminfo مهمان به حداقل تقریباً ۱٫۵ گیگابایت محدود شد؛ کاهش RAM را نتیجه آزموده‌شده تلقی نمی‌کنیم. ۴ گیگابایت swap موقت با اجرای کاربر اضافه شد؛ بوت سیستم را تغییر نمی‌دهد.

تمام ۶۰ ردیف پذیرش حفظ شده‌اند. PASS محلی، سناریوهای نیازمند گوشی یا iOS را سبز نمی‌کند. مرحله بعد، ورودی‌های Push/امضای نهایی، آزمون سخت‌افزار واقعی و تکمیل گیت‌های P0/P2/P3 است.

## پنجره‌های دسکتاپ

ابزار host-only `scrcpy 5.0.1` به‌صورت user-local نصب شد. آینه Tencent برای آن 404 داد؛ fallback رسمی GitHub استفاده و SHA256 با digest رسمی asset مقایسه شد (`scrcpy-install.json`، تصمیم 0006). ADB بسته‌بندی‌شده آن استفاده نمی‌شود؛ ADB قفل‌شده SDK پروژه به آن داده می‌شود. صدا و همگام‌سازی clipboard در پنجره‌ها خاموش و نرخ تصویر حداکثر ۵ فریم است. این ابزار وابستگی اپ نیست.

میانبرهای `/home/changer/Desktop/Mini VoIP Android 8.desktop` و `/home/changer/Desktop/Mini VoIP Android 15.desktop`، فایل `/home/changer/.local/bin/mini-voip-emulator` را اجرا می‌کنند. این راه‌انداز برای boot، شناسایی APK، RUNNING_UNLOCKED و شروع موفق Activity منتظر می‌ماند. در تلاش اولیه اندروید ۱۵، framework با وجود علامت boot، هنوز «Too early to start activity» می‌داد؛ نتیجه حذف نشده است. پروفایل نهایی از شبیه‌ساز بدون پنجره و پنجره نمایش ADB استفاده می‌کند؛ RAM درخواستی اندروید ۸ برابر ۱۵۳۶ و اندروید ۱۵ برابر ۲۰۴۸ مگابایت است؛ meminfo مهمان ۱۵ در عمل MemTotal=2532900 kB گزارش کرد، بنابراین مقدار مؤثر را صرفاً از flag نتیجه نمی‌گیریم. backend اندروید ۱۵ همان swiftshader_indirect آزمون‌های موفق و اندروید ۸ swiftshader است.

در آخرین راه‌اندازی اندروید ۸، restore خودکار یک بار ناموفق شد؛ علت دقیق از لاگ موجود اثبات نشده است. ورود دستی مجدد با همان حساب/installation موفق شد (`api26-final-login-result.json`). بنابراین راه‌اندازی سرد خودکار در این میزبان را بی‌نقص اعلام نمی‌کنیم. این محدودیت علاوه بر تأخیر و ANRهای محیط VMware باقی است.

هر دو پنجره نمایش با عنوان Android 8 | 101 و Android 15 | 102 باز شدند (`desktop-windows.txt`). ورود مجدد هر دو حساب و دو contact واقعی در `final-contacts.txt` تأیید شد؛ اندروید ۱۵ هم بعد از هشدار System UI و restore ناموفق به ورود مجدد نیاز داشت. تصویر `api35-final-ready.png` وضعیت آماده و هشدار صریح نبود اعلان پس‌زمینه را نشان می‌دهد. فایل تست UI نهایی از /data/local/tmp استفاده می‌کند تا به آماده‌بودن FUSE مسیر /sdcard وابسته نباشد.
