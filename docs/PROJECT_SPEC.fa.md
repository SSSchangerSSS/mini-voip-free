# مشخصات اجرایی پروژه SMI Phone
## تلفن داخلی ساده برای Android و iOS — قرارداد پیاده‌سازی و تحویل

**نسخه سند:** 1.0 — **تاریخ تدوین:** 2026-10-27  
**مخاطب:** ایجنت توسعه، از جمله GLM 5.3 Flash، با دسترسی به مخزن، ترمینال و مستندات رسمی.  
**ماهیت این فایل:** تعریف پروژه و معیار تحویل است؛ کد اجراشده، نتیجه آزمون یا گواهی سازگاری کتابخانه‌ها نیست.

> دستور اصلی: یک محصول کوچک و قابل‌استفاده بساز، نه صرفاً نمونه نمایشی یا اسکلت پروژه. هر ادعای ساخت، تست، نصب یا انتشار باید به خروجی واقعی و قابل‌بازبینی متصل باشد. نبود دستگاه، حساب اپل یا کلید Push را با موفقیت ساختگی جایگزین نکن.

این سند، مرجع واحد تصمیم‌های فنی این پروژه است و بر پیشنهادهای پراکنده قبلی اولویت دارد. عبارت‌های «باید» الزام اجرایی‌اند. مواردی که صریحاً «هدف اندازه‌گیری»، «پیش‌فرض طراحی» یا «کاندید بررسی» نامیده شده‌اند، نباید واقعیت آزموده‌شده یا تأیید کارفرما تلقی شوند.

---

# ۱. هدف، نیاز واقعی و مرز پروژه

## ۱.۱. نیاز کارفرما

کارکنان، با اپ Android یا iOS، از طریق سرور متعلق به شرکت و شماره داخلی با هم **تماس صوتی دونفره** برقرار کنند. سرور دارای IP ثابت است. اینترنت در دسترس کاربران فرض می‌شود. دریافت تماس وقتی اپ در پس‌زمینه و صفحه گوشی قفل است باید پیاده‌سازی و روی گوشی واقعی آزمایش شود.

**تماس بدون اینترنت، شبکه کاملاً ایزوله، Local Push اپل و PWA جزو نیاز نیستند.** اپ نباید به موتور هوش مصنوعی وابسته باشد؛ مدل فقط ابزار ساخت پروژه است.

اولویت‌ها به ترتیب: کارکرد صحیح تماس، حداقل دامنه و زمان پیاده‌سازی، قابلیت نصب و استفاده آسان، سپس ظاهر. دریافت تماس در حالت قفل در نسخه تحویلی آزمون پذیرش دارد؛ حذف آن برای سریع‌تر تمام‌کردن، بدون تأیید کارفرما مجاز نیست.

## ۱.۲. قابلیت‌های داخل نسخه ۱

| شناسه | قابلیت | تعریف دقیق |
|---|---|---|
| F01 | ورود اولیه | دامنه سرور، شماره داخلی و رمز؛ حفظ امن حساب پس از راه‌اندازی مجدد |
| F02 | شماره‌گیری | ورود شماره داخلی و برقراری فقط یک تماس خروجی |
| F03 | تماس ورودی | نام برنامه و شماره داخلی تماس‌گیرنده؛ پاسخ و رد |
| F04 | مکالمه | صدای دوطرفه، قطع، میوت و جابه‌جایی گوشی/بلندگو |
| F05 | پس‌زمینه | Push معتبر، رابط بومی تماس و پاسخ از صفحه قفل |
| F06 | نتیجه قابل‌فهم | مشغول، پاسخ داده نشد، در دسترس نیست، تماس لغو شد، اتصال قطع شد |
| F07 | مدیریت حداقلی | ایجاد/غیرفعال‌کردن داخلی و تعویض دستگاه از CLI سرور؛ بدون پنل وب |
| F08 | عملیات | نصب، بررسی سلامت، پشتیبان، بازیابی، به‌روزرسانی و بازگشت نسخه مستند |
| F09 | تحویل | یک monorepo، ساخت تکرارپذیر، آزمون، فایل نصب امضاشده و مدارک انتشار |

## ۱.۳. خارج از محدوده

چت، ویدئو، ضبط، پیام صوتی، کنفرانس، انتقال تماس، انتظار تماس دوم، چند دستگاه برای یک داخلی، دفترچه کارکنان، تماس شهری و SIP trunk، IVR، نسخه وب/ویندوز، ثبت‌نام عمومی، پنل مدیریت، CRM، گزارش مدیریتی، SSO، چندشرکتی، Kubernetes، Redis، RabbitMQ، سرویس پولی تلفنی، Analytics و Crashlytics وارد نسخه ۱ نشوند. سابقه تماس در رابط کاربر نیز لازم نیست؛ نگهداری محدود رخدادها فقط برای تشخیص خطا مجاز است.

به‌جای ساخت feature اضافی، خطای واقعی را اصلاح و تست آن را اضافه کن. تغییر معماری، تعویض موتور SIP یا افزودن قابلیت بیرون از این فهرست، نیازمند ثبت تصمیم و تأیید است.

## ۱.۴. پیش‌فرض‌های طراحی، نه اطلاعات تأییدشده کارفرما

- ظرفیت هدف برای پذیرش: **۳۰ داخلی فعال و ۱۰ تماس صوتی هم‌زمان**. تعداد دقیق کارکنان در گفتگو قطعی نشده؛ این عدد هدف آزمون است، نه ادعای تعداد کارکنان.
- فقط یک شرکت، یک سرور، یک دستگاه فعال برای هر داخلی و یک تماس برای هر دستگاه.
- داخلی‌ها رشته سه‌رقمی در بازه `101..199`؛ حداکثر ۳۰ حساب فعال. داخلی ناشناخته یا تماس با خود رد شود.
- مرجع استقرار: یک VM یا سرور اختصاص‌یافته **Ubuntu Server 24.04 LTS، amd64**. سیستم‌عامل واقعی سرور کارفرما هنوز مشخص نشده است؛ روی Windows Server می‌توان VM لینوکس داشت، اما نصب مستقیم این بسته روی Windows مسیر پشتیبانی‌شده نیست.
- حداقل پشتیبانی هدف: Android 10 / API 29 با Google Play services، و iOS 16. این کف‌ها باید در مرحله صفر با نسخه‌های وابستگی تطبیق داده شوند؛ افزایش بی‌سروصدای حداقل سیستم‌عامل ممنوع است.
- نقطه شروع ظرفیت سرور: ۲ vCPU، رم ۴ GB و SSD با فضای آزاد ۳۰ GB؛ **صرفاً برآورد اولیه**، مشروط به آزمون بار. GPU لازم نیست.
- سرور باید دامنه واقعی، DNS صحیح و گواهی TLS مورداعتماد داشته باشد. IP ثابت به‌تنهایی جایگزین این موارد نیست.

---

# ۲. معماری قطعی و دلیل باقی‌ماندن اجزا

## ۲.۱. اجزای محصول

| جزء | انتخاب | مسئولیت محدود |
|---|---|---|
| اپ | Flutter / Dart | صفحات ساده و کنترل وضعیت مکالمه |
| موتور تلفنی اپ | `sip_ua` + `flutter_webrtc` | SIP، SDP، ICE و صوت؛ این پروتکل‌ها از صفر نوشته نشوند |
| پل بومی iOS | Swift + PushKit + CallKit | اعلان VoIP، رابط سیستم و هماهنگی صوت |
| پل بومی Android | Kotlin + FCM native + AndroidX Core-Telecom + CallStyle | دریافت اعلان، تماس بومی و سرویس هنگام تماس |
| مرکز تلفن | Asterisk 22 LTS / PJSIP | احراز هویت SIP، Dialplan، برقراری و عبور صوت |
| هماهنگ‌کننده | یک برنامه ASP.NET Core Minimal API روی .NET 10 LTS | نشست دستگاه، Push، وضعیت محدود تماس و ارتباط AMI |
| ذخیره‌سازی | یک SQLite محلی | حساب‌ها، دستگاه‌ها، نشست‌ها و وضعیت محدود تماس |
| ورودی TLS | Caddy 2 | HTTPS، WSS و تمدید گواهی؛ بدون منطق تجاری |

**FreePBX و ARI استفاده نشوند.** ارتباط کنترل با Asterisk از **AMI روی loopback** است. AMI یک سرویس تجاری اضافه نیست؛ رابط داخلی همان Asterisk است. به‌جای HTTP polling دائمی در Dialplan یا اجرای shell برای هر تماس، رخداد و متغیر کانال از AMI منتقل شود. قابلیت‌های UserEvent، Setvar و پردازش رویداد در مستندات Asterisk موجودند. [S04–S08]

**Caddy نیز بک‌اند دوم نیست.** فقط مسئول گواهی و ورودی امن است؛ حذف آن مستلزم پیاده‌سازی و نگهداری همان مسئولیت در جای دیگری است. راهکار نهایی یک مسیر TLS داشته باشد، نه Caddy همراه Nginx و Certbot. [S18]

## ۲.۲. مسیر داده

```text
Android / iPhone
    ├── HTTPS /api/v1/... ───┐
    └── SIP over WSS /ws ───┤
                            ▼
                       Caddy :443
                    ┌───────┴────────┐
                    ▼                ▼
              Control API       Asterisk HTTP/WS
              127.0.0.1:5080    127.0.0.1:8088/ws
                    │                │
                    └─ AMI localhost:5038 ─┘
                    │
                    ├── APNs VoIP → iPhone
                    └── FCM → Android

Audio: App A ⇄ DTLS-SRTP ⇄ Asterisk ⇄ DTLS-SRTP ⇄ App B
```

صوت از .NET، Caddy، FCM یا APNs عبور نکند. `direct_media=no`؛ ارتباط صوتی از Asterisk عبور کند. این معماری **رمزنگاری در مسیر** دارد، نه E2EE بین کارکنان؛ Asterisk به رسانه دسترسی فنی دارد. از عبارت «رمزنگاری سرتاسری» برای این محصول استفاده نکن.

## ۲.۳. استقرار کوچک

در حالت پیش‌فرض، Docker Compose دقیقاً سه سرویس دائمی دارد: `edge`، `pbx` و `control`. SQLite فایل است، نه کانتینر چهارم. ابزارهای تست فقط در CI یا profile جدا اجرا شوند.

روی Linux هر سه سرویس از host networking استفاده کنند تا تنظیم RTP و loopback روشن بماند. در این حالت `ports:` ننویس و از DNS نام سرویس‌های Compose استفاده نکن؛ آدرس‌های داخلی صریحاً `127.0.0.1` هستند. در host networking، محدودسازی bind هر سرویس الزامی است. [S19]

برای نسخه پایه، تنها TCP 80/443 و UDP 10000–10199 از اینترنت قابل‌دسترسی باشند. SSH فقط برای آدرس‌های مدیریتی مجاز باشد. پورت‌های 5038، 5080، 8088 و SIP معمولی 5060/5061 عمومی نباشند. HTTP 80 فقط برای ACME/redirect است و API یا رمز روی HTTP پذیرفته نشود.

IPv4 مسیر پایه است. تا زمانی که IPv6 و تمام مسیرهای آن آزموده نشده‌اند، رکورد AAAA و ادعای پشتیبانی کامل IPv6 اضافه نشوند. اگر IP عمومی روی روتر NAT شده، mapping و IP اعلان‌شده در SDP باید واقعاً آزموده شوند.

## ۲.۴. TURN: شرط شبکه، نه لایه همیشگی

`TURN_ENABLED=false` پیش‌فرض است. وجود IP عمومی، کارکرد رسانه در همه شبکه‌های کاربر را تضمین نمی‌کند. مرحله صفر باید Wi-Fi و اینترنت موبایل واقعی را بررسی کند.

اگر مسیر مستقیم رسانه در شبکه هدف شکست خورد، افزودن **coturn روی همین سرور و در profile اختیاری `turn`** مجاز است و باید با تست relay اجباری همراه باشد. این profile تنها زمانی وارد استقرار می‌شود که نیاز آن با شواهد مشخص شود. برای حذف آن، اجازه ادعای پشتیبانی از شبکه‌ای که آزمونش شکست خورده وجود ندارد.

در profile اختیاری، TURN روی UDP/TCP 3478، با محدوده relay جدا از RTP و احراز هویت زمان‌دار فعال شود. استفاده از relay ناشناس، رمز ثابت تعبیه‌شده در اپ و دسترسی relay به شبکه‌های داخلی/metadata cloud ممنوع است. allowlist مقصد باید تنها IP رسانه PBX را مجاز کند؛ اولویت allow/deny را با تست واقعی بررسی کن. اعتبارنامه را API احرازشده با secret سمت سرور صادر کند، نه خود اپ. [S20]

TURN/TCP روی 3478 به معنی پشتیبانی از شبکه‌ای که فقط TCP 443 را باز می‌گذارد نیست. چنین شبکه‌ای در نسخه پایه تضمین نمی‌شود؛ این محدودیت باید در گزارش پذیرش درج شود، نه با تنظیم ناامن مخفی شود.

---

# ۳. مرحله صفر: جلوگیری از فرض‌های نادرست

## ۳.۱. قبل از توسعه گسترده

ابتدا ابزارها و حساب‌ها را بررسی و `docs/PREFLIGHT.md` ایجاد کن. موارد ناموجود را `BLOCKED` بنویس؛ کار مستقل از آن‌ها را ادامه بده. فقدان یک کلید نباید به ساخت کلید جعلی یا کنارگذاشتن پنهانی قابلیت منجر شود.

موارد لازم: دسترسی سرور آزمایشی، IP و دامنه، کنترل DNS، مسیر شبکه، Mac/Xcode برای iOS، Apple Developer و قابلیت Push، Firebase project برای Android، یک آیفون واقعی و یک اندروید واقعی، و دسترسی ایمن به اسرار از فایل/secret store.

**کارفرما نباید اسرار را در متن گفتگو یا Git قرار دهد.** برای هر مورد، نام متغیر، مسیر امن مورد انتظار و آزمون بررسی آن را اعلام کن.

## ۳.۲. قفل نسخه‌ها

خط مبنا: Flutter stable، Asterisk 22 LTS و .NET 10 LTS. برای شروع بررسی، در تاریخ تدوین سند این نسخه‌ها در منابع رسمی دیده شده‌اند: `sip_ua 1.1.0`، `flutter_webrtc 1.6.3` و خانواده Flutter 3.47. **این‌ها کاندید سازگاری‌اند، نه ترکیب آزمایش‌شده توسط نویسنده سند.** [S01–S03، S16–S17]

قبل از تثبیت، پروژه کمینه را روی Android و iOS در حالت Release بساز. سپس نسخه دقیق Flutter/Dart، .NET SDK، Asterisk patch، Caddy، Java، Gradle، Kotlin، Android SDK، Core-Telecom، Firebase Android، Xcode و وابستگی‌های Apple را در `toolchain.lock.json` ثبت کن. نسخه‌های `latest`، شاخه Git شناور و checksum ساختگی ممنوع‌اند.

`global.json`، `pubspec.lock`، Gradle wrapper و lockfiles متناسب، NuGet lock و lockfile مدیر وابستگی iOS باید commit شوند. برای source tarball و image نیز checksum/digest واقعی ثبت شود. نسخه stable جدیدتر فقط وقتی جایگزین شود که دلیل و نتیجه آزمون ثبت شده باشد؛ downgrade فریم‌ورک یا دورزدن conflict با `dependency_overrides` بدون بررسی و ثبت تصمیم مجاز نیست.

## ۳.۳. آزمایش امکان‌پذیری اجباری

پیش از طراحی کامل ظاهر، این مسیر را اثبات کن:

`Push واقعی → رابط بومی روی گوشی قفل → شروع runtime → REGISTER → INVITE همان تماس → پاسخ → صدای دوطرفه → قطع و پاک‌شدن همه وضعیت‌ها`

روی هر دو سیستم‌عامل و **Release build** انجام شود. `flutter run` در Debug، نمایش یک اعلان آزمایشی، تماس فقط در foreground و موفقیت simulator جای این آزمون نیستند.

اگر موتور یا bridge انتخابی در cold start واقعی جواب نداد، مشکل و لاگ را ثبت کن و راه‌حل حداقلی در همان معماری را بررسی کن. تغییر بی‌اجازه به PWA، سرویس تجاری یا مدل «کاربر باید اپ را باز نگه دارد» ممنوع است. نبود دستگاه یعنی این دروازه هنوز قبول نشده، نه اینکه باید کل کار متوقف یا موفق اعلام شود.

---

# ۴. شناسه‌ها، زمان و قواعد مشترک

## ۴.۱. شناسه‌ها

| نام | تولیدکننده | کاربرد |
|---|---|---|
| `extension` | CLI مدیر | هویت حساب، مانند `101`؛ رشته ASCII |
| `installationId` | اپ، CSPRNG UUID | نصب مشخص؛ IMEI، شماره سیم‌کارت یا advertising ID نیست |
| `deviceGeneration` | سرور، عدد افزایشی | با تعویض دستگاه افزایش می‌یابد؛ اعلان نسل قبلی معتبر نیست |
| `attemptId` | اپ تماس‌گیرنده، UUID v4 | یک بار فشردن تماس؛ در header مخصوص SIP قرار می‌گیرد |
| `pbxUniqueId` | Asterisk | پیوند به کانال ورودی؛ شامل زمان راه‌اندازی/شناسه نمونه PBX برای رفع برخورد |
| `callId` | Control، UUID v4 | شناسه هم‌بستگی تماس در اپ، Push، API و لاگ؛ UUID تماس ورودی بومی |
| `sipCallId` | stack SIP هر leg | فقط شناسه پروتکل؛ **جایگزین callId نیست** |
| `nativeEventId` | کد بومی | تکرارزدایی و تأیید دریافت رویدادهای پاسخ/قطع |
| `nativeCallUuid` | adapter بومی | ورودی: callId؛ خروجی: attemptId تا پایان همان تماس، با mapping به callId |

Asterisk یک B2BUA است؛ از برابر بودن SIP Call-ID دو سمت تماس استفاده نکن. ارتباط legها باید از متغیرهای PBX و `callId` به دست آید.

## ۴.۲. زمان‌ها

همه timestampهای API، DB و Push به صورت UTC / RFC 3339 با `Z` باشند. ساعت سرور با NTP هماهنگ باشد. timer درون پردازش از clock یکنواخت و تست‌پذیر استفاده کند؛ زمان دستگاه تنها مرجع اعتبار تماس نباشد.

پیش‌فرض‌ها:

| متغیر | مقدار | معنا |
|---|---:|---|
| `SETUP_TIMEOUT_SECONDS` | 40 | از پذیرش اولیه تماس تا پاسخ؛ Push مجدد آن را تمدید نمی‌کند |
| `AMI_ADMISSION_TIMEOUT_SECONDS` | 3 | حداکثر انتظار PBX برای تصمیم Control |
| `PENDING_STATUS_POLL_MS` | 1000 | فقط در مدت تماس ورودی pending و قبل از اتصال SIP معتبر |
| `RECONNECT_GRACE_SECONDS` | 15 | فرصت بازیابی اختلال واقعی رسانه؛ نه قطع خودکار صرفاً به علت میوت |
| `SESSION_IDLE_DAYS` | 90 | انقضای نشست بی‌استفاده؛ استفاده معتبر آن را تمدید می‌کند |
| `DIAGNOSTIC_RETENTION_DAYS` | 7 | حذف رخداد و تماس پایان‌یافته قدیمی |

پارامترها یک تعریف مرکزی داشته باشند؛ timeoutهای متعارض در Dart، Swift، Kotlin و Dialplan ممنوع‌اند. تنظیمات لازم و deadline از پاسخ API منتقل شوند.

## ۴.۳. invariantهای غیرقابل‌نقض

- برای هر داخلی حداکثر یک call slot رزروشده یا متصل وجود دارد.
- reservation هر دو داخلی در **یک transaction** انجام شود؛ check-then-set خارج transaction ممنوع است.
- `Ended` نهایی است؛ رویداد دیررس، Push تکراری یا `ready` آن را احیا نمی‌کند.
- صوت قبل از اقدام پاسخ کاربر شروع نشود؛ receipt اعلان یا REGISTER پاسخ به تماس نیست.
- صرفاً دریافت پاسخ موفق FCM/APNs، تحویل به گوشی یا زنگ‌خوردن محسوب نمی‌شود.
- ورود به `Connected` تنها با شواهد PBX درباره برقراری legها/bridge؛ نه صرفاً لمس دکمه پاسخ.
- میوت، خاموشی صفحه و بسته‌شدن Activity به‌خودی‌خود پایان تماس نیستند.
- هیچ ورودی کلاینت نباید نام کانال AMI، متغیر دلخواه PBX یا مقصد غیرمجاز را تعیین کند.

---

# ۵. منطق دقیق تماس و هماهنگی Push

## ۵.۱. یک مسیر واحد

برای ساده‌سازی نسخه ۱، تمام تماس‌های ورودی اپ از همین handshake استفاده کنند؛ حتی وقتی اپ مقصد باز است. اتصال SIP قدیمی یا وجود contact در PBX به‌تنهایی مجوز Dial نیست. یک Push معتبر و پاسخ `ready` همان تماس لازم است. در نتیجه، در این نسخه دسترس‌پذیری سرویس Push بخشی از مسیر برقراری تماس ورودی است؛ تماس مستقل از Push به عنوان قابلیت جداگانه پیاده نشود.

این تصمیم جلوی دو مسیر متفاوت و خطاهای contact مانده را می‌گیرد. اگر Push در شبکه واقعی کارکنان در دسترس نیست، این موضوع در مرحله صفر مانع پذیرش است؛ آن را با وعده «اینترنت دارد پس حتماً زنگ می‌خورد» نادیده نگیر.

## ۵.۲. ترتیب تماس موفق 101 → 102

1. اپ 101 باید حساب معتبر، میکروفون مجاز و SIP ثبت‌شده داشته باشد. یک `attemptId` بسازد و INVITE فقط به `sip:102@<domain>` بفرستد؛ header ورودی `X-SMI-Attempt-ID` همین UUID است. در حال تماس، فشردن دوباره دکمه تماس هیچ INVITE جدیدی نسازد.
2. Asterisk هویت را از **endpoint احرازشده** مانند `CHANNEL(endpoint)` بگیرد، نه `From`، Caller-ID یا header قابل‌جعل. شماره مقصد را با حساب‌های فعال تطبیق دهد و دسترسی به contextهای دیگر ندهد. [S06]
3. Dialplan برای کانال ورودی hangup handler نصب کند، اطلاعات فنی را آماده و `UserEvent(SMICallRequested, ...)` ارسال کند. کانال هنوز Answer نشده است.
4. Control رخداد را پردازش کند، داخلی‌ها و نشست دستگاه را بررسی، در SQLite هر دو slot را اتمیک رزرو و `callId` / deadline را ایجاد کند. در busy، disabled، unknown یا duplicate attempt، بدون Push تصمیم رد ارسال شود.
5. Control با AMI ابتدا `__SMI_CALL_ID` و متغیرهای لازم را روی **همان کانال معتبر ذخیره‌شده** قرار دهد و پاسخ موفق هر action را بررسی کند؛ سپس `SMI_ADMITTED=1`. ترتیب معکوس یا Setvar بدون بررسی نتیجه مجاز نیست.
6. Dialplan حداکثر ۳ ثانیه منتظر admission بماند. در شکست، به‌صورت کنترل‌شده تماس را رد کند. در پذیرش، `Ringing()`/پاسخ موقت مناسب بدهد؛ **قبل از پاسخ واقعی مخاطب `Answer()` نکند**.
7. Control اعلان را ارسال کند. تماس تا deadline در `Pending` است. Retry انتقال اعلان کوتاه و محدود است و هر بار همان UUID/deadline را نگه می‌دارد.
8. در iOS کد بومی فوراً تماس را به CallKit گزارش کند؛ در Android اعلان تماس و lifecycle بومی فعال شوند. سپس اعتبار وضعیت سرور بررسی و runtime مشترک Flutter آماده شود. منتظر بارگذاری صفحه برای نمایش تماس نمان.
9. اپ مقصد SIP را متصل و REGISTER معتبر دریافت کند. صرف بازشدن WebSocket کافی نیست. سپس `POST /calls/{callId}/ready` بفرستد. اگر تماس منقضی، لغوشده یا متعلق به نسل قدیمی دستگاه است، همه UI و تلاش‌های اتصال آن تماس پایان یابند.
10. Control بعد از احراز هویت و بررسی callee و deadline، `SMI_DIAL_ALLOWED=1` را روی کانال ورودی تنظیم کند. `ready` تکراری نباید تماس دوم بسازد.
11. Dialplan شرط را با `WaitForCondition` ارزیابی کند؛ عبارت باید با روش ارزیابی مجدد متغیرها نوشته شود، نه expansion یک‌باره در ابتدای انتظار. وجود contact فعلی بررسی و تنها برای **زمان باقی‌مانده تا deadline** یک `Dial` اجرا شود. نبود contact در این لحظه فقط یک انتظار محدود کوتاه در همان deadline دارد؛ retry نامحدود Dial ممنوع است. [S07]
12. در pre-dial handler روی **کانال خروجی**، `X-SMI-Call-ID` از UUID تولیدشده سرور اضافه شود. header هم‌نام کلاینت نباید مبنای اعتماد باشد. تنظیم header روی کانال اشتباه ممنوع است. [S08]
13. اپ 102 پس از رسیدن INVITE، header UUID را با تماس بومی pending تطبیق دهد. اگر کاربر قبلاً پاسخ را زده، intent ذخیره‌شده دقیقاً یک بار مصرف و SIP answer اجرا شود. اگر هنوز پاسخ نداده، بدون شروع میکروفون در حالت زنگ باقی بماند.
14. لمس پاسخ پیش از INVITE باید به `accept intent` تبدیل شود، نه تماس خروجی جدید یا اتصال ساختگی. `POST /accept` این intent را ثبت می‌کند؛ خود این API صوت را متصل نمی‌کند.
15. Asterisk با پاسخ SIP و برقراری bridge، رخدادهای متناظر را اعلام کند. Control `Connected` و `connectedAt` را ثبت کند. اپ timer مکالمه را بر مبنای اتصال واقعی شروع کند؛ کیفیت رسانه را با ICE/آمار واقعی تشخیص دهد.
16. قطع از هر سمت، مسیر SIP عادی CANCEL/BYE را اجرا کند. API `end` مسیر هماهنگی/پشتیبان است. Asterisk leg دیگر را جمع کند؛ Control نتیجه را نهایی و هر دو slot را آزاد کند؛ UI و audio resources هر دو گوشی آزاد شوند.

## ۵.۳. رد، لغو و هم‌زمانی

- **رد مخاطب پیش از INVITE:** API `/decline` معتبر، پایان درخواست از سمت Control/AMI؛ اگر بعداً INVITE رسید، با همان نتیجه رد شود. علامت‌زدن فقط UI کافی نیست.
- **لغو تماس‌گیرنده پیش از آماده‌شدن مخاطب:** قطع کانال ورودی در PBX مرجع اصلی است؛ تماس DB پایان یابد و `ready` بعدی رد شود.
- **لغو بعد از INVITE:** از SIP CANCEL استفاده شود؛ پس از پاسخ، BYE. پایان native UI حتماً به پروتکل هم برسد.
- **پاسخ و لغو هم‌زمان:** transitionها transactional باشند؛ اگر کانال PBX از بین رفته یا تماس terminal شده، پاسخ برنده محسوب نمی‌شود. تماس terminal هرگز دوباره Dial نشود.
- **دو تماس به یک داخلی یا تماس متقابل هم‌زمان:** reservation اتمیک فقط یک تماس را مجاز کند؛ تماس دیگر busy شود. برای deadlock از ترتیب ثابت داخلی‌ها/transaction کوتاه استفاده شود.
- **همان ready/accept/decline/end دوباره:** نتیجه سازگار و بدون side effect تکراری؛ mutationها `Idempotency-Key` داشته باشند.
- **پاسخ نزدیک پایان مهلت:** deadline سرور مرجع است؛ پذیرفتن intent تضمین برقراری خارج از deadline نیست. UI باید شکست قابل‌فهم نشان دهد.

## ۵.۴. اعلان دیررس، تکراری و لغو اعلان

`callId`، `expiresAt` و `deviceGeneration` در Push باشند. Push نباید رمز SIP، token نشست یا کلید خصوصی داشته باشد.

برای iOS، VoIP Push کانال عمومی «لغو/وضعیت» نیست. **برای cancel، یک VoIP Push جدید نفرست.** هنگام دریافت تماس VoIP، قواعد گزارش فوری CallKit رعایت شود؛ پس از آن اگر وضعیت سرور terminal/expired بود، همان UUID پایان داده شود. Push تکراری نباید UUID جدید و تماس دوم ایجاد کند. رفتار callback تکراری باید با API/SDK واقعی اپل آزموده شود؛ dedup نباید الزام CallKit را نادیده بگیرد. [S09]

تا پیش از دریافت INVITE، برنامه برای همان تماس pending، وضعیت را هر ۱ ثانیه می‌خواند؛ polling فقط در پنجره محدود تماس است، نه تمام روز. بعد از تشکیل SIP session، CANCEL/BYE مسیر اصلی پایان است. Android می‌تواند cancel data message معمولی به‌عنوان کمک دریافت کند؛ درست‌بودن سیستم نباید به تحویل آن وابسته باشد.

سیستم‌عامل ممکن است زمان اجرای پس‌زمینه را محدود کند؛ بنابراین نمی‌توان توقف زنگ در همان میلی‌ثانیه قطع تماس را در تمام وضعیت‌ها تضمین کرد. deadline محلی، بررسی سرور و SIP باید از زنگ مانده جلوگیری کنند. در آزمون، تأخیر واقعی cancel ثبت شود. روی iOS قدیمی/تحت محدودیت، نمایش خیلی کوتاه تماس دیررس ممکن است ناشی از الزام گزارش CallKit باشد؛ **اتصال تماس منقضی‌شده مطلقاً مجاز نیست**.

## ۵.۵. اختلال و راه‌اندازی مجدد

- قطع Control یا AMI: تماس جدید fail-closed شود؛ Asterisk مستقل از آن می‌تواند تماس رسانه‌ای موجود را ادامه دهد. صرف restart بک‌اند نباید دستور قطع همه تماس‌ها صادر کند.
- بعد از اتصال مجدد AMI، ابتدا snapshot کانال‌ها و وضعیت تماس‌های ذخیره‌شده reconcile شود. تا آن زمان readiness سرویس false باشد. رویدادهای گم‌شده AMI را قابل replay فرض نکن.
- تماس pending ذخیره‌شده بدون کانال زنده به `Ended/ServerRestart` برسد؛ تماس متصل زنده حفظ و دوباره map شود. DB قدیمی نباید برای همیشه busy بسازد.
- restart خود Asterisk تماس جاری را از بین می‌برد؛ اپ باید آن را تشخیص داده و به Idle برگردد. بازیابی بی‌وقفه مکالمه جزو تعهد نیست.
- تغییر Wi-Fi به دیتا: بازیابی signaling و registration انجام شود. حفظ بی‌وقفه تماس جاری تضمین نیست؛ اگر رسانه در ۱۵ ثانیه برنگشت، پایان شفاف و امکان تماس مجدد لازم است.
- هرگز روی همان `callId` پایان‌یافته، به‌صورت خودکار redial نکن.

---

# ۶. ماشین حالت و داده‌های پایدار

## ۶.۱. وضعیت سمت سرور

ماشین حالت اصلی فقط این موارد را دارد:

`Pending → Connecting → Connected → Ended`

از `Pending` و `Connecting` نیز می‌توان مستقیم به `Ended` رفت. `Connecting` یعنی intent پاسخ/اتصال در جریان است، نه اثبات صوت. اگر رویدادها جابه‌جا رسیدند، شواهد معتبر PBX می‌تواند `Pending` را مستقیماً به `Connected` برساند؛ downgrade ممنوع است.

مرحله جزئی با timestampهای `pushAcceptedAt`، `deviceReadyAt`، `sipDialStartedAt`، `acceptedAt` و `connectedAt` ثبت شود؛ برای هر پرچم یک state machine جدا نساز.

دلایل پایان ثابت: `Completed`، `Declined`، `CallerCancelled`، `NoAnswer`، `Busy`، `Unavailable`، `Expired`، `NetworkLost`، `ServerRestart`، `SetupFailed`، `AccountDisabled`.

پایان معتبر PBX مرجع آزادکردن منابع است. درخواست API برای پایان می‌تواند `endRequestedAt` را ثبت کند؛ پاسخ موفق API را با قطع تأییدشده کانال یکی ندان. اگر AMI موقتاً قطع بود، دستور پایان pending با deadline و retry محدود ذخیره و پس از reconcile اجرا شود؛ اجازه ورود تماس جدید برای slot مربوط تا روشن‌شدن وضعیت داده نشود.

## ۶.۲. وضعیت اپ

`Unconfigured`، `SigningIn`، `Idle`، `OutgoingPending`، `IncomingPending`، `Connecting`، `Connected`، `Ending`، `Error`.

یک `CallController` واحد، قابل‌آزمون و مستقل از widgetها مالک وضعیت است. UI، SIP events و native events همگی به همین کنترل‌کننده ورودی دهند. چند singleton جدا برای «تماس Flutter»، «تماس Push» و «تماس CallKit» نساز.

`AnswerRequested` یک intent هم‌بسته با callId است. آماده‌نبودن Dart یا INVITE نباید آن را از بین ببرد. native event queue باید تا ACK واقعی نگهداری کند. restart اپ، رویداد قدیمی مربوط به تماس پایان‌یافته را اجرا نکند.

## ۶.۳. SQLite

یک DB محلی با WAL، foreign keys، migration شماره‌دار، busy timeout و backup سازگار داشته باش. ORM کامل لازم نیست؛ `Microsoft.Data.Sqlite` و query پارامتردار کافی است.

جدول‌های حداقلی:

- `Extensions`: extension PK، enabled، password hash/salt/parameters، configurationGeneration و timestamps.
- `Devices`: installationId، extension با unique فعال، platform، deviceGeneration، Push token/provider/environment، قابلیت‌ها و lastSeenAt.
- `Sessions`: hash token با unique، deviceId، createdAt، idleExpiresAt، revokedAt؛ token خام ذخیره نشود.
- `Calls`: callId PK، attemptId، caller/callee، نسل دستگاه مقصد، PBX instance/uniqueid/channel mapping، state، timestamps، deadline، reason و revision.
- `CallSlots`: extension PK و callId FK؛ گرفتن دو slot در transaction کوتاه. constraint باید مانع race شود، نه فقط کد برنامه.
- `PendingActions`: دستورهای کوچک لازم برای reconciliation/end؛ نوع ثابت، callId، attempts، nextAttemptAt، deadline. این یک جدول داخل همان DB است، نه message broker عمومی.
- `SchemaMigrations`: نسخه و checksum migration.

برای `(caller, attemptId)` و `(pbxInstance, pbxUniqueId)` محدودیت unique لازم است. همه mutationهای تماس باید revision یا شرط state داشته باشند. تماس‌ها و رخدادهای پایان‌یافته قدیمی‌تر از ۷ روز پاک شوند؛ active call و داده امنیتی لازم حذف نشوند.

---

# ۷. قرارداد API عمومی

## ۷.۱. قواعد مشترک

Base path: `/api/v1`. JSON با UTF-8 و نام فیلد camelCase. HTTP فقط از پشت TLS و reverse proxy شناخته‌شده. برای غیر از login/health، `Authorization: Bearer <opaque-token>` الزامی است.

JWT، OAuth server، ثبت‌نام و سرویس هویت جدا لازم نیست. token تصادفی حداقل ۲۵۶ بیت، فقط یک بار در پاسخ login، با hash SHA-256 سمت سرور نگهداری شود؛ چون token تصادفی پرآنتروپی است، آن را با رمز انسانی اشتباه نگیر.

رمز حساب با PBKDF2-HMAC-SHA256، salt تصادفی مستقل حداقل ۱۶ بایت و ۶۰۰٬۰۰۰ iteration نگهداری شود؛ از primitive استاندارد .NET استفاده کن، نه الگوریتم دست‌ساز. رمز SIP ایجادشده از CSPRNG و حداقل ۲۴ نویسه امن ASCII باشد. [S21]

برای login، محدودیت ترکیبی IP/extension مانند ۵ تلاش ناموفق در دقیقه اعمال شود؛ پیام شکست اطلاعات وجود حساب را افشا نکند. APIهای تماس نیز سقف مشخص داشته باشند، بدون آنکه polling مجاز یک‌ثانیه‌ای را مسدود کنند. به `X-Forwarded-For` از اینترنت اعتماد نکن؛ تنها proxy loopback شناخته‌شده معتبر است.

## ۷.۲. مسیرها

| Method / path | ورودی یا وظیفه | پاسخ و قواعد |
|---|---|---|
| `POST /sessions` | extension، password، installationId، platform | token و تنظیمات لازم؛ فقط پس از بررسی رمز |
| `DELETE /sessions/current` | logout | revoke session و Push binding، حذف امن محلی و SIP unregister |
| `GET /me` | حساب و تنظیمات عمومی اپ | extension، نسل دستگاه، codec، timeout، sip URI و WSS URL |
| `PUT /devices/current/push` | provider، token، environment، capabilities | فقط برای دستگاه نشست؛ token خالی برابر unregister صریح است |
| `GET /calls/current?attemptId=...` | تماس همین حساب | بدون query: فقط active؛ با attemptId: همان attempt مجاز، حتی terminal در retention؛ null در نبود آن |
| `GET /calls/{callId}` | وضعیت معتبر | فقط طرفین همان تماس؛ برای دیگران 404 |
| `POST /calls/{callId}/ready` | registered=true، deviceGeneration | فقط callee؛ اعتبار deadline، نشست و نسل بررسی شود |
| `POST /calls/{callId}/accept` | ثبت intent پاسخ | فقط callee؛ بدون پاسخ‌دادن خودکار به SIP |
| `POST /calls/{callId}/decline` | رد pending | فقط callee؛ در Connected از end استفاده شود |
| `POST /calls/{callId}/end` | درخواست پایان | هر یک از طرفین؛ پاسخ 202 تا تعیین تکلیف PBX قابل استفاده است |
| `GET /ice-servers` | فقط وقتی TURN فعال است | credential کوتاه‌عمر و محدود؛ با احراز هویت و rate limit |
| `GET /health/live` | زنده‌بودن پردازش | بدون اطلاعات داخلی یا اسرار |
| `GET /health/ready` | DB، migration و AMI reconciled | 200/503؛ readiness عمومی فقط خلاصه |

هیچ endpoint عمومی برای `send-push`، `run-command`، `setvar`، ایجاد حساب یا تعیین caller وجود نداشته باشد. شروع تماس فقط از endpoint SIP احرازشده وارد Dialplan می‌شود.

## ۷.۳. نمونه‌های قرارداد

نمونه login:

```json
{
  "extension": "101",
  "password": "<provided-out-of-band>",
  "installationId": "279db4f1-7b36-4dd0-aa13-f955b889d107",
  "platform": "android"
}
```

پاسخ login باید شامل این فیلدها باشد: `accessToken`، `idleExpiresAt`، `extension`، `deviceGeneration`، `sipUri`، `sipUsername`، `sipPassword`، `wssUrl`، `setupTimeoutSeconds` و `serverTime`. طبق تصمیم 0004، رمز SIP فقط در پاسخ ورود معتبر روی HTTPS با Cache-Control: no-store منتقل و در ذخیره‌ساز امن جدا نگهداری می‌شود؛ /me و Push حامل آن نیستند. رمز نباید به response log راه یابد؛ اپ همان رمز ورودی را امن نگهداری می‌کند. SIP realm/domain از تنظیم سرور می‌آید، نه حدس اپ.

نمونه وضعیت تماس:

```json
{
  "callId": "1450d21c-c471-492d-89cd-2e58c6638b64",
  "attemptId": "c675277e-f71b-4d69-91a9-25e6a9ef1230",
  "caller": "101",
  "callee": "102",
  "state": "Pending",
  "deviceGeneration": 1,
  "revision": 3,
  "createdAt": "2026-10-27T06:00:00Z",
  "expiresAt": "2026-10-27T06:00:40Z",
  "acceptedAt": null,
  "connectedAt": null,
  "endedAt": null,
  "endReason": null,
  "serverTime": "2026-10-27T06:00:03Z"
}
```

خطا در قالب Problem Details با extensionهای `code`، `traceId` و در موارد مجاز `callId` باشد. کدها حداقل شامل `INVALID_CREDENTIALS`، `DEVICE_ALREADY_BOUND`، `SESSION_EXPIRED`، `CALL_NOT_FOUND`، `CALL_ENDED`، `CALL_EXPIRED`، `STALE_DEVICE`، `INVALID_TRANSITION`، `PBX_NOT_READY` و `RATE_LIMITED` شوند. متن فنی انگلیسی در UI خام نمایش داده نشود.

401 برای نشست نامعتبر، 403 برای عمل غیرمجاز روی حساب خود، 404 برای منبع متعلق به دیگری، 409 برای conflict، 410 برای تماس مجاز ولی منقضی/terminal، 429 برای محدودیت و 503 برای سرویس آماده‌نبودن است. درخواست idempotent تکراری با همان key باید نتیجه قبلی معتبر یا وضعیت terminal فعلی را برگرداند، نه عمل تکراری.

OpenAPI واقعی از کد/قرارداد تولید و به `contracts/openapi.json` صادر شود. CI باید schema/contract را بررسی کند. endpoint مستندنشده یا نمونه JSON ناسازگار با کد قابل‌قبول نیست.

## ۷.۴. یک دستگاه و خروج از حساب

ورود از installationId جدید وقتی دستگاه فعال وجود دارد، بعد از تأیید رمز `409 DEVICE_ALREADY_BOUND` بدهد؛ takeover خودکار ممنوع است. CLI مدیر با `device reset` نسل دستگاه، tokenها و رمز SIP را تعویض کند. دستگاه قبلی نباید با رمز قدیمی دوباره ثبت شود. تغییر config و وضعیت DB باید سازگار و قابل rollback باشد.

ورود مجدد همان installationId با رمز صحیح می‌تواند token نشست را rotate کند. token جدید native و Dart از یک مخزن امن مشترک بخوانند. logout در حین تماس، ابتدا پایان همان تماس را درخواست و سپس unregister/revoke کند. اگر اینترنت قطع است، پاک‌کردن محلی انجام و عدم تأیید revoke سرور شفاف گزارش شود؛ نباید ادعا شود سرور حتماً پاک شده است.

---

# ۸. تنظیم Asterisk و قرارداد AMI

## ۸.۱. تنظیمات پایه PBX

از `chan_pjsip` استفاده شود، نه `chan_sip`. Asterisk 22 در image قابل‌ساخت مخزن، از نسخه رسمی با checksum واقعی ساخته یا از منبع قابل‌اعتماد با نسخه/digest دقیق تأمین شود. استفاده از image ناشناخته با رمز پیش‌فرض قابل‌قبول نیست.

فایل‌های تولیدشده باید از templateهای مخزن باشند: `pjsip.conf`، `extensions.conf`، `http.conf`، `manager.conf`، `rtp.conf`، `modules.conf` و فایل داخلی‌های تولیدشده. تعریف حساب در چند فایل مستقل و ناسازگار ممنوع است.

مسیر WS داخلی از HTTP server خود Asterisk روی `127.0.0.1:8088/ws` استفاده کند؛ transport داخلی PJSIP از نوع `ws` است و WSS بیرونی در Caddy terminate می‌شود. فعال‌کردن `wss` روی PBX بدون تعریف TLS داخلی جای این تنظیم نیست. headerهای WebSocket و subprotocol `sip` باید عبور کنند. فقط path دقیق `/ws` proxy شود، نه کل HTTP server Asterisk.

برای هر داخلی، endpoint/auth/AOR مشخص داشته باش. نام‌گذاری باید با routing همان داخلی هماهنگ باشد. تنظیمات لازم endpoint:

```ini
; Contract of required endpoint settings, not a complete deployable config.
context=smi-internal
webrtc=yes
dtls_auto_generate_cert=yes
direct_media=no
disallow=all
allow=ulaw
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
```

برای AOR، `max_contacts=1` و `remove_existing=yes` تنظیم شود. `webrtc=yes` مجموعه‌ای از تنظیمات لازم WebRTC، از جمله DTLS/ICE/rtcp-mux را فعال می‌کند؛ نتیجه پیکربندی واقعی با CLI بررسی شود. گواهی خودامضای DTLS با fingerprint را با گواهی TLS نامعتبر برای HTTPS/WSS اشتباه نگیر. [S03]

**codec پایه نسخه ۱، PCMU / G.711 μ-law (`ulaw`) است** تا نیاز به transcoder/افزونه Opus اضافه نشود. هر دو اپ باید همین codec را negotiate کنند؛ اگر WebRTC offer چند codec دارد، PBX فقط codec مجاز را انتخاب کند. SDP را با دستکاری رشته‌ای شکننده برای حذف codecها بازنویسی نکن. افزودن Opus یک بهینه‌سازی بعدی است و برای اتمام این نسخه لازم نیست.

audio-only اجرا شود؛ video track، مجوز دوربین و capture تصویر وجود نداشته باشند. silence/mute طولانی نباید به RTP timeout اشتباه و قطع تماس منجر شود. سیاست تشخیص قطعی رسانه باید با mute حداقل ۶۰ ثانیه آزموده شود.

RTP range دقیقاً با firewall و healthcheck هماهنگ باشد. `http`، AMI و REST عمومی PBX فعال نشوند. ARI، AMI وب، sample dialplan تماس شهری و contextهای دسترسی بیرونی حذف/غیرفعال باشند.

## ۸.۲. Dialplan به‌صورت قرارداد الگوریتمی

ایجنت باید syntax نهایی را بر اساس Asterisk 22 مستند و با خود PBX آزمایش کند. الگوریتم الزامی:

```text
on authenticated INVITE for an allowed internal extension:
    identify caller from the authenticated endpoint
    validate destination and normalize safe, server-derived values
    install a lightweight hangup handler
    initialize SMI_ADMITTED=0, SMI_DIAL_ALLOWED=0
    emit SMICallRequested using this channel's unique identity
    wait up to 3 seconds for admission, abort on hangup
    if not admitted: terminate with an explicit mapped failure
    emit provisional ringing without answering
    wait for SMI_DIAL_ALLOWED or terminal/timeout, using remaining deadline
    if not allowed or caller channel is gone: terminate
    resolve current PJSIP contact for the callee
    create exactly one outbound Dial for remaining setup time
    on outbound pre-dial: attach server call UUID header
    after Dial/hangup: report final result, then return/hang up safely
```

این pseudocode را به عنوان فایل `.conf` قابل‌اجرا ذخیره نکن. تنظیم واقعی باید `dialplan show`، تست زنده و تست لغو در حین انتظار داشته باشد. استفاده اشتباه از expansion متغیر در `WaitForCondition`، `Wait(40)` ثابت بدون بررسی قطع، یا full timeout دوباره پس از آماده‌شدن گوشی، شکست پذیرش است.

hangup handler باید کوتاه باشد و از اجرای HTTP طولانی، ارسال مستقیم Push و sleep در مسیر پایان تماس خودداری کند. رخداد نهایی و AMI Hangup باید برای reconciliation کافی باشند. [S05]

### متغیرهای دقیق handshake در Dialplan

| متغیر | نویسنده | مقدار/معنا |
|---|---|---|
| `SMI_ADMITTED` | ابتدا Dialplan، سپس Control | `0` منتظر، `1` پذیرفته، `-1` رد؛ شرط انتظار `!=0` |
| `__SMI_CALL_ID` | Control | UUID سرور، پیش از admission؛ با inheritance به leg مقصد |
| `__SMI_CALLEE` | Dialplan | داخلی اعتبارسنجی‌شده، نه dial string آزاد |
| `SMI_DEADLINE_EPOCH` | Control | زمان پایان setup برحسب Unix seconds؛ همان deadline پاسخ API |
| `SMI_DIAL_ALLOWED` | ابتدا Dialplan، سپس Control | `0` تا ready معتبر و `1` پس از آن؛ فقط یک Dial |
| `SMI_REJECT_CAUSE` | Control/Dialplan | cause محدود و whitelistشده برای رد؛ ورودی آزاد کلاینت نیست |

Control مقادیر callId/deadline را پیش از `SMI_ADMITTED=1` بنویسد. deadline با دقت ثانیه انتخاب و در API نیز همان لحظه نمایش داده شود. clock سرور و PBX روی همان میزبان/هماهنگ است. Dialplan از `deadline - now` استفاده کند و اگر باقی‌مانده صفر یا منفی بود، حتی با ready مثبت Dial نکند.

Causeهای پیش‌فرض Q.850 برای آزمون mapping: busy=17، rejected=21، unknown/unallocated=1 و unavailable=20. خروجی SIP واقعی نسخه انتخابی با آزمون بررسی و mapping پیام اپ ثبت شود؛ از یکسان‌بودن cause عددی با SIP status code نتیجه‌گیری نکن. اگر Control پاسخ admission نمی‌دهد، failure کنترل‌شده داشته باش، نه انتظار ۴۰ثانیه‌ای بی‌دلیل.

## ۸.۳. رخدادهای اختصاصی

UserEventهای موردنیاز: `SMICallRequested`، `SMICallDialing` و `SMICallFinished`. هر رخداد باید identity کانال و فیلدهای قابل‌اعتبارسنجی داشته باشد. `SMICallRequested` حداقل شامل `SchemaVersion=1`، `PbxUniqueId`، `Channel`، `CallerEndpoint`، `Callee` و `AttemptId` است.

`callId` پس از admission از Control می‌آید. اطلاعات قابل‌جعل از SIP headers نباید مستقیماً به نام AMI action، channel یا variable تبدیل شوند. name فیلدها، schema و decoder در تست قرارداد ثابت باشند.

از رویدادهای استاندارد نظیر `Hangup`، `DialBegin`/`DialEnd` و `BridgeEnter`/`BridgeLeave` نیز استفاده شود. `DIALSTATUS=ANSWER` یا `accept` تنها کافی نیست؛ تشخیص Connected باید با شواهد bridge دو leg همان تماس مطابقت داشته باشد. آماری که برای این تشخیص انتخاب می‌کنی در `docs/AMI-MAPPING.md` ثبت و با trace واقعی ثابت شود.

## ۸.۴. کلاینت AMI

یک اتصال طولانی‌عمر loopback با login مستقل، heartbeat، backoff و reconnect داشته باش. اگر از کتابخانه استفاده می‌کنی، سازگاری واقعی با .NET 10 را بررسی کن؛ برای نام package/API حدس نزن. در صورت پیاده‌سازی adapter کوچک، parser باید fragmentation TCP، چند پیام در یک read، CRLF، فیلدهای تکراری و eventهای interleaved با response را تحمل کند.

هر action `ActionID` مستقل، timeout، response matching و بررسی Error دارد. کار روی هر call در صف/قفل منطقی کوتاه serial شود؛ global lock هنگام network I/O نگه داشته نشود. queue محدود و backpressure داشته باشد.

Actionهای runtime به مجموعه لازم محدود شوند: Login/Ping/Logoff، Setvar/Getvar، Hangup و snapshot کانال‌های موردنیاز. AMI `Command` و shell execution مسیر runtime ندارند. permissionهای manager با مستندات نسخه واقعی تنظیم شوند؛ تصور نکن نام هر action الزاماً یک permission مستقل است. allowlist کد و bind loopback هر دو لازم‌اند. [S04، S22]

پس از قطع AMI، event replay وجود ندارد؛ snapshot + DB + uniqueid منبع reconciliation است. دریافت `Success` برای Setvar روی کانال، مجوز ساخت تماس جدید بدون وجود رکورد و deadline نیست.

---

# ۹. دریافت Push و هماهنگی بومی

## ۹.۱. قرارداد اعلان

Schema مشترک اعلان ورودی:

```json
{
  "schemaVersion": 1,
  "type": "incoming_call",
  "callId": "1450d21c-c471-492d-89cd-2e58c6638b64",
  "callerExtension": "101",
  "calleeExtension": "102",
  "deviceGeneration": 1,
  "expiresAt": "2026-10-27T06:00:40Z"
}
```

در FCM فیلدهای data با قالب موردنیاز سرویس، از جمله تبدیل عددها به string، encode شوند. parsing native باید type/range/UUID را بررسی کند و crash نکند. فیلدهای API حساس از Push قابل‌اعتماد فرض نشوند؛ سرور مرجع نهایی است. محتوای اعلان فقط حداقل اطلاعات تماس باشد.

در این نسخه نام کارکنان الزامی نیست؛ نمایش «داخلی ۱۰۱» کافی است. Push tokenهای iOS و FCM قابل‌جایگزینی با یکدیگر نیستند.

## ۹.۲. APNs برای iOS

APNs مستقیم، با HTTP/2 و credential متعلق به bundle شرکت استفاده شود. headerها: `apns-push-type: voip`، topic متناظر `<bundle-id>.voip`، priority مناسب VoIP و expiration کوتاه، ترجیحاً صفر برای اجتناب از queue طولانی. `expiresAt` در payload همچنان لازم است؛ expiration سرویس تضمین نبود اعلان دیررس نیست. [S09]

Sandbox/Production به امضای build وابسته است. **TestFlight از APNs production استفاده می‌کند**؛ نام Debug/Release به‌تنهایی جای بررسی entitlement و token واقعی را نمی‌گیرد. هر محیط deployment فقط bundle/topic/environment مجاز خودش را بپذیرد.

private key `.p8`، Team ID و Key ID فقط سمت سرور باشند. JWT امضاشده با ابزار استاندارد ES256 تولید و در بازه مجاز cache شود؛ ساختن الگوریتم crypto یا نگهداری JWT منقضی ثابت ممنوع است. پاسخ‌های APNs، status و `apns-id` برای trace ثبت شوند، بدون ثبت payload حساس/token کامل.

در خطای token باطل، فقط همان token/نسلی که درخواست برای آن ارسال شده غیرفعال شود؛ خطای پاسخ قدیمی نباید token تازه ثبت‌شده را حذف کند. در 429/خطای موقت retry کوتاه با backoff و رعایت deadline؛ هیچ retry پس از پایان تماس انجام نشود.

## ۹.۳. پیاده‌سازی iOS

برای کمینه‌کردن تداخل lifecycle، یک adapter باریک Swift با **PushKit و CallKit رسمی** نوشته شود؛ provider دوم یا پلاگین دوم تماس افزوده نشود. این adapter موتور SIP نیست و منطق تجاری تماس را دوباره پیاده نمی‌کند. رابط عمومی آن در بخش ۱۰ آمده است.

`PKPushRegistry` در مسیر شروع native ثبت شود. هنگام VoIP Push، native باید گزارش تماس را سریع انجام دهد؛ network request، REGISTER، شروع Dart یا ساختن صفحه نباید پیش‌شرط گزارش CallKit باشند. completion callback دقیقاً یک بار و طبق قرارداد API اجرا شود. رفتار `providerDidReset`، action timeout و خطای گزارش CallKit مدیریت شود. [S09]

یک `CXProvider` و یک call slot وجود داشته باشد. ویدئو، group، hold و چند تماس در configuration خاموش باشند. در تماس **ورودی**، native UUID همان `callId` سرور است. تماس خروجی باید از همان اقدام کاربر به سیستم گزارش شود؛ چون callId سرور هنوز وجود ندارد، native UUID آن برابر `attemptId` است و تا پایان تغییر نمی‌کند. پس از دریافت وضعیت سرور، mapping `attemptId ↔ callId ↔ nativeCallUuid` ثبت شود. UUID تماس outgoing را وسط مکالمه عوض یا با call جدید جایگزین نکن. همین قاعده در Android رعایت شود. قطع قبل از رسیدن callId باید با attempt/SIP session فعلی انجام شود و منتظر API نماند.

پاسخ/رد/قطع در native queue ثبت و بدون انتظار نامحدود برای Dart رسیدگی شود. fulfill/fail actionها مطابق قرارداد CallKit انجام شود؛ دریافت `didActivate` را قبل از fulfill لازم نکن که deadlock بسازد. در مقابل، لمس پاسخ به معنی Connected شدن سرور نیست.

audio session با `playAndRecord` و حالت مناسب صوت مکالمه و lifecycle رسمی CallKit هماهنگ شود. WebRTC باید فعال/غیرفعال‌شدن audio session را دریافت کند. دو مالک مستقل که مدام audio route یا activation را بازنویسی کنند ممنوع‌اند. ادعای صدای قفل‌شده فقط با آزمون Release روی دستگاه معتبر است. [S10]

Keychain به‌گونه‌ای تنظیم شود که پس از اولین unlock پس از reboot، در حالت قفل برای پردازش تماس قابل‌استفاده باشد؛ مانند `AfterFirstUnlockThisDeviceOnly`. پیش از اولین unlock پس از روشن‌شدن گوشی، کارکرد کامل وعده داده نشود. رمز/نشست در UserDefaults یا فایل plaintext ذخیره نشوند.

## ۹.۴. FCM و Android

روی Android از Firebase Messaging SDK **در کد native Kotlin** استفاده شود. یک `FirebaseMessagingService` مالک دریافت پیام است؛ ایجاد handler دوم در `firebase_messaging` Dart برای همان پیام ممنوع است. Firebase Auth/Firestore/Analytics اضافه نشوند.

پیام تماس time-sensitive با high priority از FCM HTTP v1 و TTL برابر زمان باقی‌مانده ارسال شود. پیام باید به اعلان واقعی قابل‌مشاهده منجر شود. receipt سرور FCM فقط پذیرش درخواست ارسال است. در `onMessageReceived` کار طولانی انجام نشود؛ display/dispatch سریع و ادامه کار در lifecycle مجاز باشد. [S11–S12]

برای lifecycle از AndroidX Core-Telecom، یک phoneCall foreground service هنگام تماس و اعلان CallStyle استفاده شود. نیازمندی‌های target SDK، `MANAGE_OWN_CALLS`، `FOREGROUND_SERVICE`، `FOREGROUND_SERVICE_PHONE_CALL` و مجوزهای میکروفون/اعلان طبق API واقعی بررسی شوند؛ صرف نوشتن permission در manifest کافی نیست. `phoneCall` را بدون Telecom معتبر برای دورزدن محدودیت microphone به کار نبر. [S13–S14]

اعلان/foreground باید در مهلت سیستم منتشر شود؛ callbackهای Telecom را با اجرای network/Dart طولانی block نکن. full-screen intent در نسخه‌های جدید اندروید مجوز و محدودیت دارد؛ از `canUseFullScreenIntent` و مسیر تنظیمات مجاز استفاده و در نبود آن notification مناسب نمایش داده شود. برنامه overlay دائمی یا درخواست default dialer نداشته باشد. [S15]

میکروفون فقط پس از اقدام کاربر و مجوز مجاز شروع شود. wake lock کوتاه‌مدت، timeoutدار و فقط در صورت ضرورت مجاز است؛ battery exemption و foreground service دائمی در حالت Idle راهکار اصلی نباشند. سرویس بعد از پایان آخرین تماس متوقف و اعلان ongoing حذف شود.

Force Stop از Settings یک وضعیت جداست: انتظار بیدارشدن عادی نداریم؛ بازکردن مجدد اپ باید ثبت token/حساب را بازیابی کند. نبود Google Play services در نسخه ۱ پشتیبانی نمی‌شود و باید در onboarding روشن تشخیص داده شود؛ سرویس جایگزین Huawei به پروژه اضافه نکن. [S12، S23]

## ۹.۵. محدودیت‌های واقعی سیستم‌عامل

DND/Focus، مجوزهای خاموش، Force Stop، قطع اینترنت، مسدودبودن دسترسی به Apple/Google، و token نامعتبر می‌توانند دریافت را محدود کنند. اپ نباید ادعای زنگ صددرصدی در تمام شرایط یا دورزدن سکوت کاربر داشته باشد. در عوض، قابلیت‌ها و وضعیت مجوزها را روشن نمایش دهد و سناریوی عادی آنلاین/قفل را واقعاً پاس کند.

بسته‌شدن Activity، حذف از recent apps، کشته‌شدن process توسط OS و Force Stop را در گزارش تست یکی ننام. روش ایجاد هر وضعیت را ثبت کن. به‌ویژه محدودیت‌های background message معمولی FCM در iOS را خودکار به PushKit VoIP تعمیم نده.

---

# ۱۰. ساختار اپ و رابط بومی

## ۱۰.۱. کمینه ساختار Dart

رابط کاربری فقط این صفحات را داشته باشد: تنظیم/ورود حساب؛ شماره‌گیر با وضعیت آماده‌بودن؛ صفحه تماس. خطا و وضعیت مجوز می‌تواند در همان صفحات باشد؛ dashboard جدید لازم نیست.

متن فارسی و RTL، شماره تلفن و شناسه‌ها LTR. ارقام فارسی و عربی ورودی قبل از اعتبارسنجی به ASCII تبدیل و فاصله‌های اطراف حذف شوند؛ مقصد باید فقط ۳ رقم مجاز باشد. نمونه `۱۰۲` و `١٠٢` هر دو به `102` تبدیل شوند. string دلخواه به URI/SIP header نچسبان.

هنگام بازشدن صفحه، focus مناسب روی ورودی اصلی باشد. نام داخلی فعلی، وضعیت «آماده»، «در حال اتصال» یا مشکل قابل‌اقدام نمایش داده شود. خطای SIP/stack trace خام نمایش داده نشود. اگر نیاز به ورود مجدد هست، صفحه نباید خود را آماده نشان دهد.

برای state management، یک کنترل‌کننده قابل‌آزمون با `ChangeNotifier` یا primitive استاندارد Flutter کافی است؛ چند framework هم‌زمان اضافه نشود. dependencyهای transitive کتابخانه SIP موضوع متفاوتی هستند.

اجزای منطقی کمینه: `CallController`، `SipAdapter`، `ControlApiClient`، `NativeCallBridge`، `SecureCredentialStore`، `CallViewModel`. wrapperها فقط برای مرز واقعی تست/پلتفرم باشند، نه لایه repository/service/use-case تکراری برای هر تابع.

### ترتیب onboarding و وضعیت آماده

دامنه ورودی فقط hostname معتبرِ سرور، بدون path، userinfo یا scheme ناامن باشد؛ URLهای API و WSS پس از login از تنظیم معتبر سرور خوانده شوند. برای نسخه ۱ پورت عمومی 443 ثابت است. دامنه ساختگی `example.com` یا placeholder نباید در release عملیاتی باقی بماند.

onboarding به ترتیب: اعتبارسنجی ورودی → login → نگهداری امن حساب/installation → مجوز میکروفون و قابلیت‌های لازم سیستم → دریافت و ثبت Push token → ثبت SIP. UI فقط وقتی آماده نشان دهد که حساب و قابلیت‌های ضروری قابل‌استفاده‌اند؛ یک خطای Push نباید زیر علامت سبز پنهان شود. هیچ مجوزی برای camera/contacts/location درخواست نشود.

native و Dart باید secure store مشترک داشته باشند. در Android از Android Keystore و primitive استاندارد AES-GCM برای داده private app استفاده شود، با IV تازه و بدون الزام biometric برای هر تماس؛ در iOS از Keychain قابل‌دسترسی پس از unlock اولیه استفاده شود. کلید رمزگذاری export یا در source hardcode نشود. backup معمولی سیستم نباید رمزهای حساب و صف رخداد تماس را به نصب تازه نامعتبر منتقل کند. upgrade باید داده را حفظ کند، reinstall باید وضعیت نصب را تشخیص دهد و در صورت نیاز ورود/reset روشن بخواهد.

صف native فقط رویدادهای محدود همان تماس را نگه دارد، سقف ۶۴ رخداد و پاک‌سازی منقضی داشته باشد؛ رمز/کلید در آن نباشد. ACK فقط پس از تحویل و پردازش idempotent باشد. در replay، ابتدا اعتبار call و نسل دستگاه بررسی شود.

## ۱۰.۲. قرارداد bridge

یک MethodChannel/EventChannel با schema نسخه‌دار تعریف شود. نام پیشنهادی ثابت: `smi.phone/native/v1`. فقط یک مالک event dispatcher داشته باش.

عملیات ضروری: `configure`، `getCapabilities`، `getPushToken`، `reportOutgoing`، `updateCallState`، `endCall`، `setMuted`، `setSpeaker`، `getPendingEvents`، `ackEvent` و دسترسی محدود به secure store.

رویدادها: `incomingReported`، `answerRequested`، `declineRequested`، `endRequested`، `audioActivated`، `audioDeactivated`، `pushTokenChanged`، `nativeCallReset` و `capabilityChanged`. payload شامل `eventId`، `callId`، type، native timestamp و فیلدهای موردنیاز باشد؛ همیشه nullable/unknown type مدیریت شود.

token/رمز را در broadcast عمومی، Intent بدون محدودیت یا log قرار نده. اجزای Android به‌جز مواردی که سیستم الزام دارد `exported=false` باشند؛ PendingIntentها صریح و مطابق الزامات SDK ساخته شوند.

## ۱۰.۳. runtime و cold start

یک FlutterEngine/موتور SIP اصلی برای هر process داشته باش. در Android آن را lifecycle سرویس تماس/engine cache نگه دارد؛ Activity فقط attach شود. در iOS نیز نمایش native تماس از UI Flutter مستقل باشد و engine روی تقاضا آماده شود. Activity یا screen تازه نباید SIP UA دوم ایجاد کند.

`main()` و registration pluginها باید برای شروع بدون نمایش صفحه نیز کار کنند. plugin وابسته به Activity را در background بدون activity فراخوانی نکن. native event تا consumer آماده و ACK نشده حذف نشود. پس از resume، `getPendingEvents` و وضعیت سرور reconcile شوند؛ reliance صرف به event stream زودگذر قابل‌قبول نیست.

این بخش یک **ریسک فنی نیازمند اثبات در مرحله صفر** است. وجود API یا package به‌تنهایی تأیید قابلیت cold start آن در ترکیب انتخابی نیست.

## ۱۰.۴. صوت و پاک‌سازی

پیش‌فرض پخش، گوشی/receiver باشد؛ اگر سیستم route مناسب headset را فعال کرده، بی‌دلیل به speaker تغییر نده. دکمه بلندگو و میوت باید با حالت native همگام باشند. انتخابگر پیشرفته Bluetooth لازم نیست؛ اتصال/قطع مسیر عادی headset نباید crash، سکوت دائمی یا ادامه میکروفون پس از پایان ایجاد کند.

پایان تماس باید tracks، peer connection، timerها، native call، foreground service و notification را پاک کند. websocket ثبت حساب را فقط طبق سیاست lifecycle حفظ/بازیابی کن؛ بازماندن آن در پس‌زمینه پیش‌شرط دریافت تماس نیست.

Idle بدون polling دائمی، audio recording، wakelock یا foreground service باشد. هنگام بازبودن اپ، SIP registration لازم مجاز است. تست memory leak باید نشان دهد پس از تماس‌های متوالی، track/peer/timer/کانال زنده انباشته نمی‌شود.

---

# ۱۱. امنیت، مدیریت داخلی و اسرار

## ۱۱.۱. امنیت الزامی

اعتبارسنجی TLS در Android/iOS خاموش نشود؛ `badCertificateCallback=true`، trust-all و cleartext production ممنوع‌اند. exception آزمایش باید از artifact انتشار حذف و در CI بررسی شود. مرجع امنیت هیچ‌وقت صرفاً Push payload نیست.

PBX اینترنتی به معنای SIP anonymous مجاز نیست. REGISTER و INVITE با حساب واقعی احراز شوند. caller spoofing با From/PAI یا `X-SMI-Call-ID` خنثی شود. routing فقط داخلی‌های ساخته‌شده و فعال است؛ هیچ dial string آزاد/ترانک یا escape به context دیگر وجود ندارد.

API مقدار `extension` موجود در body را برای تعیین هویت درخواست احرازشده قبول نکند. `callId` تصادفی جای authorization را نمی‌گیرد. IDOR، replay نسل قبلی و race هم‌زمان آزمون داشته باشند.

CORS عمومی باز نباشد؛ اپ native به CORS آزاد نیاز ندارد. body size و header size محدود، queryها پارامتردار و logها redacted باشند. endpoint سلامت اطلاعات حساب، نسخه جزئی آسیب‌پذیر، path یا stack trace منتشر نکند.

## ۱۱.۲. منبع واحد حساب و provisioning

CLI و server از مدل واحد حساب استفاده کنند. مدیر با یک فرمان حساب می‌سازد؛ ابزار هم hash API و هم تنظیم SIP را تولید می‌کند. مدیر مجبور نشود یک داخلی و رمز را جداگانه در دو سامانه وارد کند.

رمز SIP برای کارکرد PBX در فایل پیکربندی محافظت‌شده لازم است؛ آن فایل secret محسوب شود، در Git/گزارش/CI artifact نباشد و فقط سرویس لازم آن را بخواند. SQLite برای احراز هویت API hash نگه دارد، نه نسخه plaintext رمز.

تغییر حساب باید transaction/journal داشته باشد: render به فایل موقت، validation ورودی، atomic replace، reload محدود، بررسی مشاهده config توسط PBX و سپس اعلام موفقیت. اگر مرحله‌ای شکست خورد، rollback یا وضعیت `provisioning_failed` صریح باشد. «DB موفق اما PBX رمز قبلی» موفقیت نیست.

برای تغییرات حساس مثل reset/rotate، ابتدا نبود تماس فعال مربوط را بررسی کن؛ پیش‌فرض فرمان با پیام روشن رد شود تا تماس زنده بی‌خبر قطع نشود. flag صریح و تأییدشده برای قطع تماس فعال در عملیات اضطراری قابل‌استفاده است، اما پیش‌فرض نیست.

## ۱۱.۳. اسرار و فایل‌های محلی

اسرار شامل APNs key، Firebase service account، AMI credential، رمز داخلی، signing key Android، signing material اپل و secret اختیاری TURN هستند. فقط runtime مربوط به هر secret دسترسی داشته باشد. runtimeها نباید Docker socket داشته باشند.

فایل‌های واقعی در `deploy/secrets/` و `deploy/site.env` فقط روی میزبان/secret store ایجاد شوند و در `.gitignore` باشند. نمونه‌ها مقدار خالی یا placeholder واضح دارند. script باید placeholder باقی‌مانده را تشخیص و در production fail کند؛ fallback با رمز پیش‌فرض ممنوع است.

Firebase client configuration با service account یکی نیست. فایل‌های کلاینت متناسب با پروژه ساخته شوند؛ service account و `.p8` هرگز در APK/IPA قرار نگیرند. scanner روی repository و unpacked release artifact باید این موضوع را بررسی کند.

## ۱۱.۴. حریم خصوصی و مجوز نرم‌افزار

هیچ ضبط صوت، analytics و ارسال محتوای صوت به طرف سوم نداشته باش. داده عملیاتی محدود تماس و شناسه دستگاه برای راه‌اندازی لازم است. متن privacy ساده باید واقعاً همین جمع‌آوری را توضیح دهد؛ «هیچ داده‌ای جمع نمی‌کنیم» ادعای نادرست است.

`THIRD_PARTY_NOTICES.md` و فهرست dependency/license تهیه شود. درباره ترکیب مجوزهای Asterisk و کتابخانه‌ها نتیجه حقوقی خودکار نساز؛ تعهدات متن مجوزهای واقعی رعایت و source/notices لازم هنگام توزیع image فراهم شود. عدم بررسی مجوز با برچسب «همه open source هستند» پوشانده نشود.

---

# ۱۲. ساختار مخزن واحد

ساختار زیر قرارداد تحویل است؛ فایل خالی تزئینی نساز. فایل‌های تولیدی ابزارها می‌توانند افزوده شوند ولی سرویس جدید خارج از scope نه.

```text
smi-phone/
├── AGENTS.md
├── README.fa.md
├── CHANGELOG.md
├── THIRD_PARTY_NOTICES.md
├── .gitignore
├── .editorconfig
├── global.json
├── toolchain.lock.json
├── smi                         # CLI wrapper for Linux/macOS
├── smi.ps1                     # Windows entry point
├── apps/mobile/
│   ├── lib/
│   │   ├── call/
│   │   ├── sip/
│   │   ├── api/
│   │   ├── native/
│   │   └── ui/
│   ├── android/                # native FCM + Telecom adapter
│   ├── ios/                    # native PushKit + CallKit adapter
│   ├── test/
│   ├── integration_test/
│   ├── pubspec.yaml
│   └── pubspec.lock
├── services/control/
│   ├── src/
│   ├── tests/
│   ├── migrations/
│   └── Dockerfile
├── infra/
│   ├── asterisk/               # Dockerfile, templates, modules, dialplan
│   ├── caddy/
│   └── turn/                   # only if network gate proves it necessary
├── deploy/
│   ├── compose.yaml
│   ├── site.env.example
│   └── secrets/README.md       # no real secrets
├── contracts/
│   ├── openapi.json
│   ├── native-events.schema.json
│   └── push.schema.json
├── tests/system/
│   ├── fixtures/
│   └── scenarios/
├── scripts/
│   ├── doctor/
│   ├── build/
│   ├── deploy/
│   └── release/
├── docs/
│   ├── PROJECT_SPEC.fa.md
│   ├── PREFLIGHT.md
│   ├── ARCHITECTURE.md
│   ├── AMI-MAPPING.md
│   ├── RUNBOOK.fa.md
│   ├── ANDROID-RELEASE.fa.md
│   ├── IOS-RELEASE.fa.md
│   ├── USER-GUIDE.fa.md
│   ├── SECURITY.md
│   └── decisions/
├── qa/
│   ├── acceptance-tests.json
│   ├── device-test-matrix.json
│   └── reports/
└── .github/workflows/
    ├── ci.yml
    └── release.yml
```

قابلیت مدیریت حساب، یک حالت اجرای همان برنامه Control باشد؛ نیازی به پروژه microservice مستقل نیست. کدهای native در همین مخزن باشند؛ fork مخفی، فایل دستی خارج از Git و dependency روی patch محلی ثبت‌نشده ممنوع است.

README باید با حداکثر چند مرحله کاربر را به نصب سرور، ساخت دو داخلی و نصب اپ برساند. جزئیات طولانی در Runbook باشند، اما هر دستور README واقعاً کار کند.

---

# ۱۳. فرمان‌های استاندارد تحویل

ایجنت باید wrapper واقعی این قرارداد را بسازد. این نام‌ها صرفاً نمونه دستور موجود نیستند؛ جزء خروجی‌ای هستند که باید پیاده‌سازی و آزموده شود.

```bash
./smi doctor
./smi check
./smi test unit
./smi test integration
./smi build android --release
./smi build ios --release

./smi server init --config deploy/site.env
./smi server up
./smi server status
./smi server logs --call-id <UUID>

./smi extension add 101 --credential-file <secure-path>
./smi extension disable 101
./smi device reset 101 --credential-file <secure-path>

./smi backup --output <secure-backup-path>
./smi restore --input <secure-backup-path> --confirm
./smi upgrade --release <version> --drain
./smi rollback --release <previous-version> --drain
./smi verify-release --manifest <release-manifest.json>
```

`build ios` روی Windows باید پیام روشن درباره نیاز macOS بدهد؛ موفقیت مصنوعی یا تولید فایل خالی مجاز نیست. wrapper Windows کارهای قابل‌پشتیبانی را با PowerShell اجرا و عملیات Linux-only را به محیط مشخص WSL/SSH واگذار یا متوقف کند؛ اجرای کار روی سرور اشتباه ممنوع است.

رمز در command line/history چاپ نشود. `--credential-file` فایل با دسترسی محدود بسازد و فقط محل آن را اعلام کند. عملیات destructive بدون flag صریح/تأیید مناسب اجرا نشود. script نصب نباید SSH یا firewall فعلی را بدون گزارش و رضایت تغییر دهد.

Exit codeها مشخص باشند: 0 موفق، 1 خطای اجرایی/آزمون، 2 ورودی یا پیش‌نیاز نامعتبر، 3 عملیات مسدود به علت حساب/دستگاه/تأیید لازم. خروجی machine-readable اختیاری `--json` و log انسانی خوانا داشته باشد.

`doctor` باید SDKها، platform، lockfileها، secret presence بدون نمایش مقدار، DNS، port conflict، clock، قابلیت دسترسی PBX/API و مسیر Push را بررسی کند. وجود فایل credential به‌تنهایی موفقیت ارسال واقعی Push محسوب نشود.

---

# ۱۴. نصب، نگهداری و بازگشت

## ۱۴.۱. نصب اولیه

مسیر نصب هدف، VM خالی Linux است. اگر 80/443/5038 یا RTP range اشغال بود، script با توضیح conflict متوقف شود؛ سرویس موجود را kill نکند. کارفرما فقط config غیرمحرمانه و فایل‌های secret را تأمین کند؛ route، داخلی و Dialplan نباید دستی و پراکنده ویرایش شوند.

توالی: preflight → اعتبارسنجی config → ساخت/دریافت image قفل‌شده → ساخت volume و permission → migration → بالا آمدن PBX/Control → اتصال و reconcile AMI → راه‌اندازی TLS → readiness و smoke test. ترتیب وابستگی واقعی بررسی شود، نه اتکا به start order صرف Compose.

`server up` idempotent باشد و داده/کلید موجود را overwrite نکند. data volumeهای SQLite، PBX و Caddy پایدار باشند. root filesystem تا حد عملی read-only، service user غیرroot و capabilityهای اضافه حذف شوند. استثنای لازم برای bind پورت edge مستند باشد.

## ۱۴.۲. health و گزارش

live با ready تفاوت دارد. ready به migration سالم، DB قابل‌استفاده، AMI وصل و reconciliation کامل وابسته است. بررسی providerهای خارجی باید خطاها را ثبت کند، اما نباید برای هر health request یک Push واقعی به کارکنان بفرستد.

logها structured با UTC، level، callId، attemptId، pbxUniqueId، platform و event باشند. token، password، Authorization، private key، SDP کامل یا محتوای صوت در log عادی ممنوع است. debug logging حساس فقط موقت و با redaction و آگاهی مدیر فعال شود.

Docker log rotation و سقف حجم تعیین شود. در نسخه ۱ stack جدا Prometheus/Grafana/ELK لازم نیست. CLI status و logهای هم‌بسته برای اندازه فعلی کافی‌اند.

## ۱۴.۳. backup و restore

backup باید SQLite را به روش سازگار با WAL/SQLite backup API بگیرد؛ کپی‌کردن فقط فایل `.db` حین نوشتن کافی نیست. config داخلی‌ها، migration version، image digests و secretهای لازم بازیابی نیز لحاظ شوند.

backup شامل داده حساس است: رمزگذاری با ابزار استاندارد و کلید مستقل از backup، permission محدود و راهنمای نگهداری خارج از همان سرور لازم است. فایل backup رمزگشایی‌شده نباید در GitHub artifact عمومی بارگذاری شود.

restore روی محیط تمیز آزمایش شود: DB سالم، حساب‌ها و token bindingها سازگار، TLS قابل‌بازیابی، AMI آماده و یک تماس واقعی برقرار شود. بدون restore test، عبارت «پشتیبان‌گیری کامل» پذیرفته نیست.

## ۱۴.۴. upgrade/rollback

upgrade ابتدا پذیرش تماس جدید را متوقف کند، تا پایان تماس‌های موجود با مهلت مشخص منتظر بماند و اگر هنوز فعال‌اند بدون `--force` اعمال نشود. backup پیش از migration الزامی است.

schema changeها برای rollback برنامه‌ریزی شوند؛ صرف تغییر image به نسخه قبل با DB ناسازگار rollback نیست. اگر rollback نیاز به restore backup دارد، از قبل اعلام و با تأیید انجام شود؛ داده پس از backup ممکن است از دست برود.

سلامت و smoke test پس از upgrade اجرا و نتیجه ثبت شود. failure باید برنامه rollback مشخص داشته باشد؛ «کانتینر Running است» معیار پایان نصب نیست.

---

# ۱۵. برنامه آزمون: چه چیزی واقعاً «تست‌شده» محسوب می‌شود

## ۱۵.۱. سطوح آزمون

**Unit:** ماشین حالت، deadline، mapping شناسه‌ها، normalization، authorization، retry و idempotency. clock و providerها تزریق‌پذیر باشند. transitionهای حساس باید تست جدول‌محور و race داشته باشند؛ درصد coverage کلی جای آن‌ها نیست. هدف coverage برای کد خالص state/auth حداقل ۹۰٪ branch است؛ عدد واقعی گزارش شود.

**Integration:** SQLite واقعی، migration، transaction رقابتی، HTTP واقعی/host تست، AMI با Asterisk واقعی و lifecycle Dialplan. mock PBX به‌تنهایی کافی نیست. وجود تست FakePush برای خطا/تکرار/تأخیر لازم است ولی آن را دریافت واقعی APNs/FCM ننام.

**System خودکار:** دو client آزمایشی WebRTC با همان WSS/DTLS-SRTP، دو حساب واقعی و broker واقعی به PBX متصل شوند. fixture توسعه با Playwright + SIP.js و ورودی صوت مصنوعی مجاز است؛ این ابزارها فقط test dependency هستند و نسخه وب محصول محسوب نمی‌شوند. قفل dependency و log codec/ICE/bytes لازم است. پخش صوت باید با عبور داده واقعی و tone/energy سمت دریافت سنجیده شود، نه فقط HTTP 200 یا موفقیت SIP REGISTER.

FakePush adapter باید تنها از test host/پروژه تست قابل تزریق باشد و در image production هیچ API تستی برای تزریق Push یا دورزدن مجوز باقی نگذارد. داده اعلان تست می‌تواند به sink محلی fixture برود تا ready واقعی را فراخوانی کند. مرورگر آزمایش از CA تستِ نصب‌شده استفاده کند؛ اعتبارسنجی TLS production خاموش نشود.

**Device E2E:** Flutter واقعی روی آیفون و اندروید واقعی، build امضاشده Release، APNs/FCM واقعی، شبکه واقعی، پاسخ از قفل و صدای واقعی. این سطح با harness مرورگر یا emulator جایگزین نمی‌شود.

**Operations:** نصب از VM تمیز، upgrade، rollback، restore، سلامت TLS و بستن پورت‌های داخلی. تمام فرمان‌های README در محیط تمیز اجرا شوند.

## ۱۵.۲. ماتریس پذیرش

همه ردیف‌ها باید در `qa/acceptance-tests.json` و گزارش نهایی ردیابی شوند. «الزامی» یعنی قبل از پذیرش نهایی باید اجرا و قبول شود؛ BLOCKED مساوی PASS نیست. موارد شرطی فقط در صورت خارج‌بودن واقعی و مستند، NOT_APPLICABLE می‌شوند.

| ID | سناریو | نتیجه موردانتظار | سطح |
|---|---|---|---|
| T01 | login صحیح و نادرست | ورود واقعی؛ خطای عمومی امن و بدون افشای حساب | خودکار |
| T02 | داخلی غیرفعال/ناشناخته | عدم ثبت یا تماس مجاز؛ بدون Push | خودکار/PBX |
| T03 | ورودی فارسی، عربی و نامعتبر | تبدیل ۱۰۲ و ١٠٢؛ رد URI/header injection | خودکار |
| T04 | ورود دستگاه دوم | 409؛ عدم takeover دستگاه قبلی | خودکار |
| T05 | reset دستگاه | نسل/token/رمز قبلی نامعتبر؛ دستگاه تازه قابل‌استفاده | خودکار + دستگاه |
| T06 | token نشست منقضی/revoked | 401 و UI غیرآماده؛ نبود دسترسی به تماس دیگران | خودکار |
| T07 | تماس foreground دوطرفه | Android→iOS و iOS→Android؛ صوت دوطرفه و پایان صحیح | دستگاه |
| T08 | تماس هم‌پلتفرم | Android→Android و iOS→iOS؛ با دو دستگاه یا تست مستقل واقعی | دستگاه |
| T09 | تماس خروجی تکراری با چند tap | فقط یک attempt/INVITE/slot | خودکار + دستگاه |
| T10 | تماس با خود و شماره تعریف‌نشده | رد واضح؛ بدون تخصیص ماندگار slot | خودکار/PBX |
| T11 | میوت حداقل ۶۰ ثانیه | قطع صدای ارسال، ادامه تماس و بازگشت درست | دستگاه |
| T12 | بلندگو/receiver و مسیر عادی headset | کنترل درست، بدون crash یا میکروفون مانده | دستگاه |
| T13 | قفل صفحه حین مکالمه | مکالمه ادامه یابد؛ Activity مالک عمر تماس نباشد | دستگاه |
| T14 | incoming پس از ۳۰ دقیقه قفل | رابط native، پاسخ از قفل و صدای دوطرفه روی هر OS | دستگاه |
| T15 | incoming پس از دو ساعت بیکاری | بدون بازکردن قبلی اپ در همان بازه؛ نتیجه و تأخیر ثبت شود | دستگاه |
| T16 | cold start پس از kill توسط OS | رخداد native گم نشود؛ startup و صدا در Release موفق | دستگاه |
| T17 | Android Doze | اعلان واقعی و تماس مطابق قواعد سیستم؛ trace دریافت | دستگاه |
| T18 | Android Force Stop | عدم ادعای بیدارسازی؛ بازیابی پس از بازشدن دستی | دستگاه/محدودیت |
| T19 | Focus/DND یا notification permission خاموش | احترام به تنظیم کاربر؛ وضعیت روشن و بدون bypass | دستگاه/محدودیت |
| T20 | پاسخ قبل از رسیدن INVITE | intent حفظ، answer دقیقاً یک بار، بدون outgoing جدید | خودکار + دستگاه |
| T21 | رد پیش از REGISTER/INVITE | تماس سرور پایان یابد؛ دیررس‌ها زنده‌اش نکنند | خودکار + دستگاه |
| T22 | caller cancel پیش از Push receipt | terminal؛ stale Push اتصال ایجاد نکند | خودکار + دستگاه |
| T23 | caller cancel هنگام زنگ | CANCEL/UI cleanup و عدم زنگ مانده | خودکار + دستگاه |
| T24 | پاسخ هم‌زمان با cancel | یک نتیجه نهایی؛ بدون ghost bridge یا slot | race + دستگاه |
| T25 | پایان timeout | مهلت کل ۴۰ ثانیه؛ timeout بعد از ready از نو شروع نشود | خودکار/PBX |
| T26 | Push با تأخیر بیش از deadline | عدم اتصال تماس منقضی؛ پایان UI مطابق قواعد CallKit | خودکار + دستگاه |
| T27 | Push تکراری و event تکراری | یک UUID/UI/INVITE؛ بدون mic/session تکراری | خودکار + دستگاه |
| T28 | دو caller هم‌زمان به یک callee | یک تماس پذیرفته، دیگری busy؛ قفل اتمیک | race/PBX |
| T29 | تماس متقابل هم‌زمان | بدون deadlock/دو تماس فعال روی یک داخلی | race/PBX |
| T30 | contact قدیمی و غیرقابل‌دسترسی | Dial صرفاً با contact انجام نشود؛ ready همان تماس لازم | PBX + دستگاه |
| T31 | اپ مقصد بدون اینترنت | نتیجه timeout/unavailable؛ خطای کنترل‌شده و آزادشدن slot | دستگاه |
| T32 | APNs/FCM token باطل یا چرخش token | invalidate فقط نسل درست؛ token تازه حذف نشود | خودکار + دستگاه |
| T33 | 429/5xx provider | retry محدود تا deadline، بدون UUID تازه یا ارسال بعد از پایان | خودکار |
| T34 | قطع/reconnect AMI | fail-closed تماس جدید؛ reconcile و حفظ تماس زنده ممکن | PBX |
| T35 | restart Control در Pending/Connected | بدون busy دائمی و بدون قطع بی‌دلیل رسانه متصل | PBX + دستگاه |
| T36 | restart Asterisk | پایان قابل‌فهم؛ ثبت مجدد و تماس بعدی موفق | PBX + دستگاه |
| T37 | تغییر Wi-Fi/دیتا در تماس | recovery یا پایان روشن تا مهلت؛ عدم اتصال شبح | دستگاه |
| T38 | foreground/lock روی Wi-Fi شرکت و شبکه بیرونی | خروج از فرض LAN؛ WSS و صوت واقعی | دستگاه |
| T39 | IDOR و callId جعلی | ناتوانی در خواندن/رد/قطع/ready تماس دیگران | امنیت خودکار |
| T40 | جعل From/Caller-ID و headerها | هویت از endpoint؛ عدم جعل داخلی و UUID | امنیت PBX |
| T41 | race در ready/end/idempotency | terminal immutable، side effect دقیقاً یک بار | خودکار |
| T42 | TLS نامعتبر و endpoint ناامن | اتصال رد شود؛ release هیچ trust-all نداشته باشد | امنیت |
| T43 | secret scan سورس و APK/IPA/image | نبود کلید سرور، رمز واقعی و backdoor تست | CI/security |
| T44 | پورت و سطح دسترسی | AMI/API داخلی/HTTP PBX از اینترنت بسته باشند | عملیات |
| T45 | ۳۰ داخلی و ۱۰ تماس هم‌زمان، ۱۰ دقیقه | ثبت ظرفیت واقعی، صوت و منابع؛ بدون خطای منطقی | بار واقعی/خودکار |
| T46 | حداقل ۱۰۰ چرخه تماس/پایان | عدم رشد ماندگار channel/track/slot و خطای cleanup | خودکار + نمونه دستگاه |
| T47 | نصب روی VM تمیز | README و wrapper بدون اصلاح دستی پنهان کار کنند | عملیات |
| T48 | backup و restore روی محیط تمیز | بازیابی واقعی و تماس پس از restore | عملیات |
| T49 | upgrade و rollback | حفظ data/config و رفتار drain؛ schema سازگار | عملیات |
| T50 | Android signed APK و upgrade روی نصب قبلی | امضای ثابت، حفظ حساب، FCM/صوت واقعی | انتشار/دستگاه |
| T51 | iOS archive/TestFlight واقعی | امضا/entitlement/APNs production صحیح و تماس قفل | انتشار/دستگاه |
| T52 | انتشار پایدار iOS | لینک واقعی توزیع موردتأیید؛ TestFlight جای آن نیست | انتشار/وابسته به حساب |
| T53 | دسترس‌پذیری و RTL | ارقام/متن/دکمه‌ها خوانا، تغییر font scale خراب نکند | UI/device |
| T54 | TURN با UDP مسدود و relay اجباری | فقط در صورت فعال‌بودن profile؛ credential امن و رسانه واقعی | شرطی/شبکه |
| T55 | reboot گوشی و unlock اولیه | بازیابی token/حساب؛ رفتار قبل از unlock مستند | دستگاه |
| T56 | تمدید/تعویض گواهی و reconnect WSS | اتصال بعدی موفق؛ عدم ورود به حالت ready کاذب | عملیات |
| T57 | نبود/قطع secret یا اشتباه محیط Push | startup/preflight یا پیام صریح؛ بدون fallback ناامن | خودکار/عملیات |
| T58 | auth throttling و ورودی بزرگ/بدقالب | 429/4xx قابل‌کنترل؛ بدون crash یا اجرای command | امنیت خودکار |
| T59 | app/system phone interruption | پایان/مدیریت سیستم بدون ضبط پنهان و audio session گیرکرده | دستگاه |
| T60 | تطبیق tag، commit، checksum و گزارش‌ها | همان باینری آزموده‌شده انتشار یابد | انتشار |

## ۱۵.۳. دستگاه، شبکه و تعداد تکرار

حداقل یک iPhone واقعی و دو مدل Android از برندهای موجود شرکت برای آزمون پس‌زمینه لازم است. برای T08 در iOS به آیفون دوم یا دسترسی دستگاه واقعی دوم نیاز داریم؛ در نبود آن، همان ردیف BLOCKED می‌ماند و پوشش ادعایی کمتر است. این نیاز جدید محصول نیست؛ شرط اثبات پوشش اعلام‌شده است.

ماتریس باید مدل گوشی، نسخه OS، حالت نصب، build number، commit، شبکه/Wi-Fi/اپراتور، وضعیت باتری/مجوز و روش ایجاد background را ثبت کند. پوشش یک OS را به همه نسخه‌های min..current تعمیم نده؛ فهرست دستگاه‌های واقعاً تأییدشده را اعلام کن.

برای هر پلتفرم، در شرایط عادی شبکه، ۲۰ تماس ورودی در حالت قفل پس از خواب مناسب تکرار شود؛ دست‌کم یک آزمون ۳۰ دقیقه‌ای و یک آزمون دو ساعت بیکاری نیز جدا انجام شود. همه شکست‌ها ثبت شوند، حتی اگر به مشکل شبکه نسبت داده می‌شوند. آزمون دوباره، نتیجه شکست اولیه را پاک نکند.

## ۱۵.۴. هدف‌های اندازه‌گیری، نه وعده خارجی

- حالت آماده/foreground: هدف p95 از درخواست تماس تا UI مقصد ≤ ۳ ثانیه.
- background/locked با Push قابل‌دسترسی: هدف p95 ≤ ۸ ثانیه در نمونه آزمون تعریف‌شده.
- پس از پاسخ کاربر و آماده‌بودن شبکه: هدف p95 شروع صدای دوطرفه ≤ ۳ ثانیه.
- در اتصال signaling سالم: هدف حذف UI پس از قطع remote ≤ ۲ ثانیه؛ مسیر pre-INVITE با deadline نیز بررسی شود.
- در Idle: بدون سرویس تماس دائمی، capture صوت یا polling دائمی.

این اعداد **هدف مهندسی پیشنهادی** هستند، نه SLA تضمینی Apple/Google یا نتیجه benchmark. معیارها با تعداد نمونه و اندازه‌گیری واقعی ارائه شوند. برای سنجش بین دو دستگاه، clock skew لحاظ شود؛ stopwatch هماهنگ یا timestamps سرور/trace معتبر استفاده شود.

حجم APK/IPA، RAM و مصرف منابع سرور واقعی گزارش شوند. عدد تبلیغاتی برای حجم کم یا باتری ساخته نشود؛ WebRTC خود کتابخانه بومی دارد. اندازه Release، معماری ABI و روش نصب در گزارش مشخص باشد. [S27]

---

# ۱۶. CI، ساخت و انتشار

## ۱۶.۱. خط CI

برای هر pull request و commit اصلی، format/lint، Flutter analyze/test، .NET build/test، schema/contract checks، secret scan و integration PBX اجرا شوند. build Android Release در Linux و build iOS روی macOS runner با toolchain قفل‌شده انجام شود.

CI عمومی بدون signing secret می‌تواند خروجی unsigned/بدون codesign بسازد، اما نباید آن را installable iOS release بنامد. گام انتشار فقط در workflow محافظت‌شده، با secretهای کارفرما و approval مشخص اجرا شود. repository/actionها به‌صورت read-only پیش‌فرض باشند؛ write تنها در گام موردنیاز. هیچ secretی به PR نامطمئن/fork نرسد.

GitHub Actions و Docker imageها نسخه/commit/digest واقعی داشته باشند. ورودی release tag با commit و version فایل برنامه تطبیق داده شود. checksumها پس از ساخت فایل واقعی تولید شوند. آزمون skipped، build signing-skipped یا exit code نادیده‌گرفته‌شده نباید badge موفقیت کامل بسازد.

درخواست حاضر به معنی مجوز ساخت repository عمومی یا انتشار فوری در فروشگاه نیست. پیش‌فرض مخزن خصوصی است؛ عملیات بیرونی حساس باید با دسترسی و تأیید واقعی کارفرما انجام شوند.

## ۱۶.۲. انتشار Android

مسیر اولیه و کم‌هزینه: **APK Release امضاشده برای نصب مستقیم کارکنان**، با راهنمای نصب و به‌روزرسانی. حداقل arm64-v8a؛ خروجی ABIهای دیگر فقط با پشتیبانی واقعی dependencyها و اعلام پوشش. split-per-ABI برای جلوگیری از بسته بزرگ غیرضروری مناسب است. [S28]

keystore متعلق به کارفرما و خارج Git باشد و backup امن داشته باشد. نام package و کلید امضا پس از اولین انتشار ثابت بمانند. versionCode افزایشی و versionName مطابق release tag باشد. تست update روی نسخه قبلی باید حساب و دریافت تماس را حفظ کند.

فایل نصب از مسیر دسترسی موردتأیید شرکت توزیع شود. انتشار در Google Play برای نسخه ۱ لازم نیست؛ AAB/Play Console، حساب و فرآیند اضافی را بی‌دلیل شرط راه‌اندازی نکن. با این وجود target SDK و permissionها باید با محدودیت‌های واقعی Android سازگار باشند؛ APK مستقیم راه دورزدن قوانین runtime سیستم نیست.

## ۱۶.۳. انتشار iOS

ساخت iOS نیازمند macOS/Xcode، امضا و حساب مناسب اپل است. این پیش‌نیاز با Flutter یا توان مدل حذف نمی‌شود. [S24]

برای اعتبارسنجی اولیه، TestFlight استفاده شود؛ اما عمر تست هر build محدود است و **TestFlight راه توزیع دائمی محصول نیست**. طبق راهنمای اپل، buildهای آزمایشی تا ۹۰ روز قابل استفاده‌اند. [S25]

مسیر پیش‌فرض پیشنهادی انتشار پایدار: **Unlisted App در App Store** برای انتشار از طریق لینک، با ورود فقط حساب‌های داخلی شرکت. پذیرش آن در اختیار اپل است و نیاز به App Review و درخواست unlisted دارد. در صورت نبود حساب یا رد درخواست، وضعیت انتشار BLOCKED است؛ بدون تأیید کارفرما به enterprise signing نامعتبر، گواهی شخص ثالث یا روش دورزننده تغییر نده. [S26]

ایجنت باید: archive/IPA واقعی، entitlement inspection، ثبت bundle صحیح، metadata و privacy policy مطابق محصول، دستور/automation آپلود و گزارش وضعیت ارسال را آماده کند. حساب آزمایشی امن برای App Review باید از کانال امن ارائه شود و به داده واقعی کارکنان دسترسی ندهد.

یک صفحه استاتیک privacy/support برای الزامات انتشار مجاز است؛ این صفحه به معنی اضافه‌کردن وب‌اپ یا پنل نیست. نام و راه تماس شرکت را جعل نکن. اطلاعاتی که کارفرما نداده به‌عنوان ورودی انتشار مشخص شوند.

آپلود موفق، پذیرفته‌شدن build، عبور از Review و قابل‌نصب‌بودن برای کارکنان چهار وضعیت مختلف‌اند. فقط آخرین وضعیت، `Published` محسوب می‌شود. فایل `.ipa` به‌تنهایی به معنی نصب آزاد روی هر آیفون نیست.

## ۱۶.۴. artifactهای هر release

- source در commit/tag مشخص، imageها یا دستور build قابل‌تکرار با digest و toolchain lock؛
- Android APK امضاشده، SHA-256 و اطلاعات امضای قابل‌بازبینی؛
- iOS archive/IPA مطابق روش توزیع و، در صورت انجام، build ID و لینک واقعی دسترسی؛
- release manifest شامل نسخه، commit، زمان، hashes، schema version، toolchain و migration compatibility؛
- گزارش CI و تست‌های واقعی دستگاه، محدودیت‌ها، Runbook و راهنمای مختصر کارکنان؛
- عدم وجود secret، حساب واقعی یا فایل تنظیم خصوصی در artifact عمومی/قابل‌انتشار.

باینری پس از تست نباید دوباره با تغییرات پنهان ساخته و منتشر شود. هر rebuild نیازمند checksum و تطبیق evidence با همان build است.

---

# ۱۷. مراحل تحویل و کنترل پیشرفت ایجنت

| مرحله | خروجی عملی | دروازه عبور |
|---|---|---|
| P0 | preflight، قفل نسخه‌ها و آزمایش کوچک native/SIP | قابلیت اصلی cold start و صدای قفل با مدرک؛ در نبود دستگاه BLOCKED |
| P1 | monorepo، build scripts، SQLite/API و تست state/auth | build و unit/contract واقعی؛ بدون endpoint صوری |
| P2 | Asterisk، AMI، TLS و تماس دوطرفه foreground | دو داخلی واقعی و سناریوهای cancel/timeout/slots |
| P3 | تکمیل native Push، قفل و raceها | Device E2E و مجموعه T14–T33 |
| P4 | hardening، نصب/backup/restore، CI و release build | تست عملیات و باینری امضاشده واقعی |
| P5 | انتشار و تحویل استفاده روزمره | مدارک انتشار واقعی یا تفکیک روشن موانع بیرونی |

P0 یک spike کوچک است و نباید به ساخت دو محصول موازی منجر شود. کد معتبر آن در همان مخزن تکمیل شود. اگر حساب/دستگاه موجود نیست، P1/P2 و بخش‌های مستقل را ادامه بده؛ P0/P3/P5 را موفق اعلام نکن و هیچ جایگزین پنهانی به کار نبر.

در پایان هر مرحله، خلاصه شامل فایل‌های تغییرکرده، دستورهای اجراشده، نتیجه، evidence path، ایراد باقی‌مانده و مرحله بعد بده. گزارش برنامه‌ریزی‌شده را با گزارش اجرای واقعی مخلوط نکن. بعد از هر خطای تکرارشونده ابتدا minimal reproduction و یک regression test بساز، نه تعویض بی‌دلیل کتابخانه‌ها.

هر تصمیم مهم در `docs/decisions/NNNN-*.md` کوتاه ثبت شود: مسئله، گزینه انتخابی در همین scope، دلیل، اثر و آزمون. تصمیم جدید نباید خودکار نیاز جدید بسازد.

---

# ۱۸. معیار تحویل نهایی و صداقت وضعیت

چهار برچسب مستقل استفاده شود:

| برچسب | معنای قابل‌اثبات |
|---|---|
| `CodeReady` | کد کامل محدوده، static/unit/integration و buildهای قابل‌انجام قبول شده‌اند |
| `DeviceValidated` | تست‌های اجباری دستگاه واقعی با همان release artifact قبول شده‌اند |
| `Deployed` | سرور هدف واقعاً نصب و smoke/عملیات لازم ثبت شده‌اند |
| `Published` | کارکنان از روش توزیع موردتأیید واقعاً می‌توانند نسخه را نصب کنند |

این‌ها یکی نیستند. نبود Apple Developer می‌تواند Published را مسدود کند حتی وقتی CodeReady درست است. نبود Mac، DeviceValidated/iOS build را نیز محدود می‌کند. نبود آزمون باید در جدول باقی بماند؛ حذف تست برای سبزکردن گزارش ممنوع است.

هر test فقط یکی از `PASS`، `FAIL`، `NOT_RUN`، `BLOCKED` و `NOT_APPLICABLE` دارد. برای N/A دلیل scope و تأیید لازم ثبت شود. شواهد شامل command، exit code، زمان، محیط، commit/build و path گزارش/ویدئو/لاگ redacted باشند. تمام evidenceها نباید صرفاً اسکرین‌شات اعلام موفقیت خود ایجنت باشند.

**Definition of Done:** قابلیت‌های F01–F09 در محدوده توافق‌شده، آزمون‌های اجباری بدون FAIL/NOT_RUN/BLOCKED، نصب و restore آزموده، باینری‌های واقعی، اسناد قابل‌اجرا، secret scan پاک و وضعیت انتشار شفاف. کارفرما از روی راهنما باید بتواند دو داخلی ایجاد کند، اپ را نصب کند و تماس بگیرد؛ بدون اینکه بخشی از کد یا سرور را از نو بنویسد.

اگر محدودیت بیرونی مانع تحویل کامل است، بهترین خروجی واقعی را تحویل بده و دقیقاً بنویس چه بخش‌هایی آماده‌اند و برای رفع هر مانع چه دسترسی/اقدام لازم است. عبارت «کاملاً آماده تولید» بدون معیارهای بالا ممنوع است.

---

# ۱۹. اطلاعاتی که فقط کارفرما باید تأمین کند

این‌ها ابهام معماری نیستند و نباید موجب طراحی مجدد شوند:

| ورودی | محل/روش امن | استفاده |
|---|---|---|
| IP و دامنه سرور، دسترسی DNS | config غیرمحرمانه | آدرس واقعی و TLS |
| دسترسی VM و قواعد firewall | SSH امن، نه رمز در چت/Git | استقرار و بررسی شبکه |
| Firebase project و service account | secret file روی سرور/CI | ارسال FCM Android |
| Android client config | فایل متناسب با package نهایی | ثبت دستگاه در پروژه درست |
| Apple Team/Bundle/APNs key | secretهای Apple و فایل محافظت‌شده | امضا و Push iOS |
| Mac/Xcode یا runner مناسب | محیط توسعه/CI | ساخت و امضای iOS |
| keystore Android | secret store و backup امن | انتشار و update با امضای ثابت |
| دستگاه‌های واقعی و شبکه تست | اجرای آزمون با گزارش | پذیرش background و صدا |
| نام انتشار و راه تماس پشتیبانی | config/metadata | نام اپ و privacy/support |
| تأیید عملیات نشر | approval واقعی | انتشار در محیط/فروشگاه هدف |

در آغاز فقط موارد موجود/ناموجود را فهرست کن. سؤالاتی که این سند پاسخ داده را دوباره نپرس؛ برای موارد قابل‌تنظیم فایل نمونه بساز و کار مستقل را ادامه بده.

---

# ۲۰. دستور آماده برای سپردن پروژه به ایجنت

متن زیر را می‌توان همراه همین فایل به GLM 5.3 Flash یا ایجنت توسعه داد:

```text
این سند قرارداد پیاده‌سازی پروژه SMI Phone است. آن را کامل بخوان و پروژه را در یک monorepo خصوصی/محلی مطابق سند پیاده‌سازی کن؛ خروجی صرفاً توضیح، pseudocode یا scaffold نباشد.

ابتدا AGENTS.md و preflight را تهیه کن، نسخه‌های واقعی و APIهای رسمی را بررسی کن، و مرحله صفر را آغاز کن. هیچ قابلیت یا لایه خارج از scope اضافه نکن. Flutter + sip_ua/flutter_webrtc + پل بومی iOS/Android + Asterisk + یک Control Minimal API/SQLite + ورودی TLS معماری ثابت است. ARI، FreePBX، وب‌اپ، چت، ویدئو و سرویس تلفنی تجاری اضافه نشوند.

مرجع هویت تماس endpoint احرازشده PBX است. دریافت Push، پاسخ کاربر، REGISTER و اتصال صوت چهار رویداد متفاوت‌اند. callId واحد، deadline، idempotency، slot اتمیک و terminal state را دقیق پیاده‌سازی کن. برای API یا library نام و رفتار حدس نزن؛ مستندات و build واقعی را بررسی کن.

کار را مرحله‌ای با کد، تست و artifact واقعی تحویل بده و گزارش پیشرفت را در مخزن به‌روز کن. نبود credential، Mac، دستگاه یا دسترسی انتشار را BLOCKED ثبت کن؛ بخش مستقل را ادامه بده، اما آن آزمون یا انتشار را موفق اعلام نکن. اسرار را در چت، source یا log نخواه و قرار نده.

تا حد امکان از wrapperهای تعریف‌شده برای build/test/deploy استفاده کن و همان فرمان‌ها را واقعاً اجرا کن. هیچ TODO در قابلیت اصلی را با عبارت «آماده تولید» تحویل نده. در پایان commit/tag، فایل‌های نصب واقعی، hashes، وضعیت CodeReady/DeviceValidated/Deployed/Published، گزارش تک‌تک تست‌ها و راهنمای استفاده را ارائه کن.
```

---

# پیوست الف. قالب گزارش تحویل

```text
Release:
Commit:
Build IDs:
Toolchain lock hash:
Test period (UTC):

CodeReady: PASS / FAIL / BLOCKED
DeviceValidated: PASS / FAIL / BLOCKED
Deployed: PASS / FAIL / BLOCKED
Published: PASS / FAIL / BLOCKED

Artifact | SHA-256 | Signature status | Install/distribution location
Test ID | Status | Environment/device | Command/procedure | Evidence | Notes

Actual supported device/OS/network matrix:
Actual observed timing and sample counts:
Server load results:
Backup + restore result:
Upgrade + rollback result:
Known limitations:
Missing external prerequisites and exact next action:
Security/license checks:
Operator quick-start commands verified:
```

# پیوست ب. منابع رسمی و حدود استناد

این منابع برای رفتار ابزارها و پلتفرم‌ها در تاریخ تدوین بررسی شده‌اند. تصمیم‌های scope، endpointهای `/api/v1`، نام رویدادهای SMI، اعداد timeout و معیارهای پذیرش، **طراحی این پروژه** هستند و نباید به عنوان قابلیت آماده محصولات زیر معرفی شوند. compatibility نهایی فقط با مرحله صفر و lockfile اثبات می‌شود.

- **S01 — SIP UA رسمی پروژه:** https://github.com/flutter-webrtc/dart-sip-ua و https://pub.dev/packages/sip_ua
- **S02 — Flutter WebRTC رسمی پروژه:** https://pub.dev/packages/flutter_webrtc
- **S03 — Asterisk WebRTC:** https://docs.asterisk.org/Configuration/WebRTC/Configuring-Asterisk-for-WebRTC-Clients/
- **S04 — AMI / Setvar / UserEvent:** https://docs.asterisk.org/Configuration/Interfaces/Asterisk-Manager-Interface-AMI/ ؛ https://docs.asterisk.org/Latest_API/API_Documentation/AMI_Actions/Setvar/ ؛ https://docs.asterisk.org/Asterisk_22_Documentation/API_Documentation/AMI_Events/UserEvent/
- **S05 — Hangup handlers:** https://docs.asterisk.org/Configuration/Dialplan/Subroutines/Hangup-Handlers/
- **S06 — هویت endpoint کانال:** https://docs.asterisk.org/Latest_API/API_Documentation/Dialplan_Functions/CHANNEL/
- **S07 — WaitForCondition:** https://docs.asterisk.org/Asterisk_22_Documentation/API_Documentation/Dialplan_Applications/WaitForCondition/
- **S08 — Pre-dial و PJSIP_HEADER:** https://docs.asterisk.org/Configuration/Dialplan/Subroutines/Pre-Dial-Handlers/ ؛ https://docs.asterisk.org/Asterisk_22_Documentation/API_Documentation/Dialplan_Functions/PJSIP_HEADER/
- **S09 — PushKit / APNs:** https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit ؛ https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns ؛ https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns
- **S10 — CallKit و صوت:** https://developer.apple.com/documentation/callkit/cxproviderdelegate ؛ https://developer.apple.com/videos/play/wwdc2016/230/
- **S11 — اولویت FCM:** https://firebase.google.com/docs/cloud-messaging/android-message-priority
- **S12 — دریافت FCM در Android:** https://firebase.google.com/docs/cloud-messaging/android/receive-messages
- **S13 — Core-Telecom:** https://developer.android.com/develop/connectivity/telecom/voip-app/telecom
- **S14 — foreground serviceها:** https://developer.android.com/develop/background-work/services/fgs/service-types
- **S15 — محدودیت full-screen intent:** https://developer.android.com/about/versions/14/behavior-changes-14
- **S16 — نسخه‌های Asterisk:** https://docs.asterisk.org/About-the-Project/Asterisk-Versions/
- **S17 — .NET 10 و Flutter stable:** https://learn.microsoft.com/en-us/dotnet/core/releases-and-support ؛ https://docs.flutter.dev/release/release-notes
- **S18 — Caddy reverse proxy و HTTPS:** https://caddyserver.com/docs/caddyfile/directives/reverse_proxy ؛ https://caddyserver.com/docs/caddyfile/options
- **S19 — Docker Compose networking:** https://docs.docker.com/compose/how-tos/networking/ ؛ https://docs.docker.com/reference/compose-file/services/
- **S20 — coturn:** https://github.com/coturn/coturn/wiki/turnserver ؛ https://github.com/coturn/coturn/blob/master/examples/etc/turnserver.conf
- **S21 — نگهداری رمز OWASP:** https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- **S22 — AMI event filtering:** https://docs.asterisk.org/Configuration/Interfaces/Asterisk-Manager-Interface-AMI/AMI-Event-Filtering/
- **S23 — شرایط دریافت FCM و Force Stop:** https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- **S24 — ساخت و انتشار Flutter iOS:** https://docs.flutter.dev/deployment/ios ؛ https://docs.flutter.dev/platform-integration/ios/setup
- **S25 — TestFlight و عمر build:** https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
- **S26 — Unlisted distribution:** https://developer.apple.com/support/unlisted-app-distribution/ ؛ https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods/
- **S27 — اندازه‌گیری حجم برنامه:** https://docs.flutter.dev/perf/app-size
- **S28 — ساخت و انتشار Flutter Android:** https://docs.flutter.dev/deployment/android

**پایان مشخصات نسخه ۱.۰.** این سند احتمال خطای پیاده‌سازی را با قرارداد و آزمون کاهش می‌دهد؛ جای اجرای واقعی، بازبینی کد و آزمون دستگاه را نمی‌گیرد.


## اصلاح ثبت‌شدهٔ foreground و TLS محلی — تصمیم 0005

در حالت اپِ باز و SIP ثبت‌شده، رخداد ثابت SIP MESSAGE با بدنهٔ ثابت smi-call فقط hint برای واکشی احرازشدهٔ calls/current است؛ منبع هویت یا مجوز تماس نیست و جای Push پس‌زمینه را نمی‌گیرد. تنها عمل MessageSend برای مقصد داخلی معتبر و بدنهٔ ثابت به فهرست اعمال AMI افزوده می‌شود. polling دائمی idle همچنان ممنوع است. در پروفایل LAN، اعتماد صریح به CA اختصاصی با --trusted-ca-file مجاز است؛ اعتبارسنجی زنجیره و SAN خاموش نمی‌شود. استقرار عمومی و پذیرش دستگاه واقعی مستقل باقی می‌مانند.
