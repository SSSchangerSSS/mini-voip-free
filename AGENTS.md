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

- **نامزد تست دستی 2026-10-31:** نسخه0.1.1+2 با همان کلید محلی آزمایشی روی Android8/101 و Android15 بومی/103 ارتقا یافت؛ حساب‌ها حفظ شدند. پنج خطای شبکه کنترل تماس با regression اصلاح و نشت FD9/قفل شروع به daemon تازهADB در دو راه‌انداز رفع شد. 45Control+40Flutter+8wrapper+4قفل=97 تست PASS؛ ساخت Release و analyze PASS. چهار تماس پاسخ‌داده‌شده، RTP، پایداری141.08s، میوت70.47s، کلیدهای UI صوت، رد/لغو/timeout40.45s و دو شروع سرد15 با SIP تازه13.00/13.03s و بدونANR/crash بررسی شدند. صوت فیزیکی/Push/گوشی واقعی/امضای سازمانی BLOCKED؛ نامزد فقط برای تست دستی foreground محلی است. راهنما `docs/MANUAL_TEST.fa.md`، artifact/hash/محدودیت‌ها `qa/reports/2026-10-31-manual-rc/REPORT.fa.md`. این مرحله هنوز push نشده است.

- **تحویل نامزد نهایی تست دستی 2026-10-31:** نامزدهای2/3 به‌علت پیام خطای کاذب پایان و پیام قبلی روی تماس ورودی کنار گذاشته شدند و شواهد FAIL آن‌ها حفظ شد. نسخه0.1.1+4 با SHA256 `3b51431c961e234d3f1b5be1545bfaebe6af461aa3ec18835c2a9950194e10f1` روی8/101 و15بومی/103 نصب است. 97 تست و analyze/build PASS؛14 child-step واقعی باexit0: تماس دو جهت، RTP، پایداری123.96s، میوت70.46s، رد/لغو/timeout41.18s، دو شروع سرد15 باSIPتازه14.49/12.95s و تماس پس از آن. outer فرمان طولانی ترمینال exit143/FAIL داشت؛ علت اثبات نشد و در گزارش جدا است؛ بررسی کوتاه مستقل باینری/سلامت/صفرکانال/رویدادها exit0/PASS بود. ANR/crash نهایی هر دو صفر است. نامزد فقط foreground محلی است؛ CodeReady کامل/DeviceValidated/Published همچنان BLOCKED. شواهد همان باینری `qa/reports/2026-10-31-manual-rc/final/`، گزارش `qa/reports/2026-10-31-manual-rc/REPORT.fa.md` و راهنما `docs/MANUAL_TEST.fa.md`. source/گزارش این مرحله هنوز commit/push نشده‌اند.

- **آماده‌سازی دو گوشی واقعی 2026-10-31:** طبق درخواست کاربر و تأیید اتصال هر دو Android به Wi-Fi همین شبکه، داخلی‌های تازه104/105 با CLI ساخته و پس از reload واقعی PJSIP مشاهده شدند؛101/103 حفظ شدند. رمزها فقط در deploy/secrets باmode600 و Git-ignore هستند و در ویرایشگر محلی باز شدند، نه چت/لاگ. صفحه موقت دریافت همانAPK4 روی151:8765، فقط باAPK/اطلاعات عمومی، راه افتاد؛ دریافت کامل از سمتPC و SHA واقعی PASS؛ دسترسی/ورود/صوت از خود گوشی‌ها هنوزNOT_RUN/BLOCKED است. wrapper `./smi device reset` مسیرDocker پیدا کرد؛9 تست wrapper PASS و reset واقعی104 قبل از ورود گوشی PASS شد؛ reset رمز ورود را عوض نمی‌کند. CLI reload راPENDING می‌گذارد و اعمال آن در این مرحله با `module reload res_pjsip.so` جدا تأیید شد. APK/کد محصول عوض نشد. راهنما `docs/REAL_PHONES.fa.md` و شواهد ignored در `.tool-results/real-phone-setup/` هستند؛ پنل مدیریت گرافیکی اضافه نشده است.
- **تأیید دسترسی گوشی:** کاربر بازشدن صفحه دریافت APK روی یکی از Androidهای واقعی در همان Wi-Fi را تأیید کرد؛ دسترسی صفحه PASS با مدرک گزارش کاربر. ورود اپ/ثبتSIP/صوت گوشی‌ها همچنان NOT_RUN تا اجرای واقعی‌اند.

- **قابلیت‌های درخواستی مالک — 2026-10-31:** مالک foreground دو گوشی را برای نسخه قبلی تأیید کرد؛ سپس قفل/پس‌زمینه، اصلاحSpeaker،CLI وپنل/نام/دفترچه خواست. مدل گوشی شرط پیاده‌سازی نیست؛ دامنه عمومیAndroid8–15 و اجرای نمونه8/15 است. به درخواست صریح مالک Firebase/حسابGoogle ازAndroid حذف و آماده‌باش مستقیمFGS پیاده شد (تصمیم0013؛ دوباره پروژهFirebase درخواست نشود). پنل/Control/CLI همین151 فعال و تستAPI واقعی PASS است؛ نام‌هایQA101/103 به مقدار اصلی برگشتند و104/105 resetنشدند.52Control+49Flutter+9wrapper+4قفل=114تست PASS؛ Release/Analyzer و تماس/RTP رویQA8/15،قفل8 باfallbackAPI26–28 وcold bootstrap15 مشاهده شدند. صدای فیزیکی/OEM/نسخه‌های میانی BLOCKED/NOT_RUN هستند. **گیتSDKلاگT66=FAIL:** اطلاعات موقتICE در لاگبومی مانده؛ کنترلnone رفع کامل نبود. trial144 ناسازگار و rollbackشد(0014)،pin150 حفظ شد؛ patchسورس پیشنهادی درpatches/webrtc هنوزNOT_RUN است. APK15 فقطQA باSHA011a169db15a8c25d8c433d0c59e544911049a03d4839a62f21e8fccd8fb3799،نه تحویل امننهایی؛ CodeReadyکامل/DeviceValidated/Published BLOCKED و APK جدید منتشر نشده است. گزارش دقیق و شکست‌های حفظ‌شده: qa/reports/2026-10-31-phase2/REPORT.fa.md. SDK144 پذیرفته نشد و source این مرحله commit/pushنشده است.

- **رفع گیت لاگ و نامزد دو گوشی — 2026-10-31:** علتSDK150 درLoggingConfig/JNI مشخص شد؛ نسخه144.7559.15 با patch محدود و قابل‌ممیزی plugin1.6.3 درthird_party جایگزین شد (تصمیم0015؛ SHAواقعی درlock). APK0.2.1+16 universal ساخته شد؛ هر سه.so باAAR144 برابر، امضا باAPK4 یکسان و49Flutter/analyze/static PASS. تماس هر دو جهت باscreen-off وBridge/RTP وگیت runtime روی8/15 PASS؛ همچنین شروع سرد15 بدونActivity و تماس پس از آن بررسی شد. T66 جدیدPASS وFAIL15 درhistory حفظ است. APK برای تست دستی مالک روی151:8765 قرار گرفت؛ صدای فیزیکی، قفل طولانی/OEM وDeviceValidated همچنانBLOCKED تا تست گوشی‌ها. رمز104/105 عوض یاreset نشد. راهنماdocs/PHONE_RC_TEST.fa.md؛ گزارشqa/reports/2026-10-31-sdk-privacy/REPORT.fa.md. هیچcommit/push این مرحله انجام نشد.

- **اصلاح خروج از Recent و ادامه زنگ — 2026-11-01:** مالک swipe از Recent و ادامه زنگ بعد از پاسخ را گزارش کرد. اعلان‌ها به همان سرویس foreground آماده‌باش منتقل شدند؛ startForegroundService دوم ازمسیر دریافت حذف، اعلان زنگ4101 با اعلان بی‌صدای4102 جابه‌جا وIDقدیمی cancel می‌شود. قصد پاسخ پیش ازHTTP/SIP زنگ را ساکت می‌کند؛ latch جلوی برگشت آن را می‌گیرد. singleTask و پاک‌سازی فقط taskهای قدیمی اپ، چندکارت‌شدن را اصلاح کردند؛ حساب‌ها حفظ شدند. کمبود مجوز/باتری/سرویس دیگر آماده سبز نیست و دکمه تنظیمات دارد. APK0.2.2+21 باSHA256 `5a02949c8898f49a7d3e2026e109fb5d0a7e246342f78366b5720bc3bdda0393` ساخته/نصب شد.119unit وcheck PASS؛ سه تماس همانAPK باswipeواقعی8،task-remove15 وscreen-off8،RTP/قطع زنگ وقطع/صفرکانال PASS؛hold60s باuptime72/75s وlost0. Gestureتزریقی15 کارت را نبست وPASS معرفی نشد. نمونه18 باCallStyleغیرforeground کرش داشت و منتشر نشد؛ SystemUI8 ANR وfixtureراه‌اندازی‌نشده نیز درگزارشFAIL حفظ‌اند؛ رفع کامل همهANRها ادعا نیست. گیتSDK/هش سهABI/امضایUpgrade PASS. گوشی‌های واقعی21/صدای شنیداری/OEM همچنانBLOCKED تا تست مالک؛104/105 reset یا تغییررمز نشدند. تصمیم0016، راهنماdocs/PHONE_RC_TEST.fa.md، گزارشqa/reports/2026-11-01-background-ringing/REPORT.fa.md. صفحه151:8765 برای دریافت موقت21 فعال؛ انتشاررسمی/commit/push اینمرحله انجام نشده است.

- **گزارش POCO X7 Pro — 2026-11-01:** مالک درباره نسخه جدید بازخورد مثبت کلی داد ولی دریافت پس از بستن اپ رویPocoX7Pro راFAIL گزارش کرد. T64/T70 با مدرک کاربرFAIL هستند؛ تستAOSP آن را رفع‌شده نمی‌کند. نسخه واقعیAndroid/HyperOS و ماندن اعلان پس ازswipe خواسته شده‌اند. منابع رسمی autostart/No restrictions/background lock وpopup بررسی وdocs/POCO_HYPEROS.fa.md آماده شد. علتOEM هنوز فرضیه است؛ تنظیمات اختصاصی بامعافیتAndroid یکی فرض نشود. کد/APK21 و104/105 تغییر نکردند؛ APKجدید یاIntentخصوصی تأییدنشده ساخته نشد. بررسی فیزیکیHyperOS BLOCKED تا داده/آزمون مالک. گزارشqa/reports/2026-11-01-poco-background/REPORT.fa.md.

- **تکمیل داده Poco — 2026-11-01:** مالک Android16 buildBP2A.250605.031.A3 وHyperOS3.0.7.0.WOJMIXM را اعلام وناپدیدشدن اعلان پس ازswipe را تأیید کرد. این رام درماتریس اجراشده8/15 نبوده؛ targetSdk36 مدرکDeviceValidated نیست. وضعیت autostart وNo restrictions هنوزنامعلوم است وخواسته شد. حذف اعلان با توقف سرویس سازگار است ولی بدونعلتخروج/تستتنظیمات،killقطعی یاJobSchedulerAndroid16 علت اثبات‌شده نیست. کد/APK تغییرنکرد؛ گزارشPoco وراهنما به‌روز شدند.

- **راه‌اندازی مجوز داخل اپ — 2026-11-01:** درخواست runtime میکروفن/اعلان، هدایت رسمی باتری/full-screen، بازخوانی پس از برگشت و مسیر guarded تنظیمات HyperOS با fallback و وضعیت نامشخص اضافه شد(0017). APK0.2.3+24 با SHA73b0d990ac0932baa2d34cad14a2e6e2eb41618ea5c4e70be42d5797206ff8e3ساخته و در151:8765قرارگرفت.126تست/check/analyze/buildPASS؛پنجره واقعی میکروفن/تأییدباتری و بازخوانیAPI35PASS. تماس24/API26مجدد و شاخه‌هایnativeاعلان/full-screenNOT_RUN؛Poco16/HyperOS3BLOCKED وT70FAILمالک حفظ است. امضای ارتقا/SDKسهABI/اسکن محدوداسرار/دریافتHTTPPASS. حساب104/105عوض نشد. گزارشqa/reports/2026-11-01-reception-setup/REPORT.fa.md؛انتشار رسمی/commit/pushانجام نشد.

- **مدیریت حساب و تنظیم سرور — 2026-11-01:** APK0.3.0+29 با SHA256 `221367448dc762a699e1f5965baa734d35bd97de2f9f1a5f6136352fdcd0d32f` در151:8765 آماده تست دستی است. پنل فیلتر/حذف/اجبار ورود و ابطال نشست، دفترچه long-poll با cache مشترک، تنظیم host پشت رمز دولوپر، CLI configure و آماده‌سازی مجوزهای runtime اضافه شدند(0018). Logout/binding، درخواست logout بدونتوکن و سازگاری حساب بی‌نام اصلاح شدند.
  - 135 تست، check/analyze/build PASS؛ رمز دولوپر، دفترچه زنده/ابطال درUI، شروع سرد و حفظ151:443 روی8/15 PASS.
  - دو تماس نهایی با نام+داخلی،RTP،قفل8/task-remove15،قطع زنگ،hold60s باuptime96/99 وlost0،صفرکانال و حذف اعلان PASS؛گیتSDK هرPID9marker و نشت0. SHAسهABI/امضایupgrade/اسکن محدوداسرار/HTTP PASS.
  - شکست‌های helper و انتظار اعلان در گزارش حفظ‌اند. نام‌های QA101/103 به مقدار اصلی برگشتند؛104/105 reset یا تغییررمز نشدند. مالک24 را به‌صورت کلی موفق گزارش کرد؛ گوشی واقعی29 BLOCKED است.
  - README.md راهنمای صفحه GitHub؛ گزارش `qa/reports/2026-11-01-accounts-live/REPORT.fa.md`. پس از صفرکانال فقطQA8/15 برای آزادکردن منابع متوقف شدند؛محصول و سرور دانلود فعال‌اند. تحویل Git پس از این مدارک ثبت می‌شود؛انتشار رسمیAPK/iOS NOT_RUN.
