# مدیریت حساب، دفترچه زنده و تنظیم سرور — 0.3.0+29

2026-11-01. قابلیت‌های درخواستی مالک پیاده و APK نهایی برای تست دستی آماده شد. مالک نسخه قبلی24 را به‌صورت کلی موفق اعلام کرد؛ این بازخورد، آزمون نسخه29 روی گوشی واقعی محسوب نمی‌شود.

## رفتار نهایی

- پنل وب: مشاهده و ساخت حساب با نام، داخلی و رمز؛ جست‌وجوی نام/شماره و فیلتر فعال، غیرفعال، دارای دستگاه و بدون دستگاه. وضعیت دستگاه، binding است و تضمین آنلاین‌بودن نیست. رمزها در فهرست برگردانده نمی‌شوند.
- تغییر رمز، اجبار ورود، غیرفعال‌کردن و حذف، نشست‌های قبلی را باطل می‌کنند. تغییر رمز/اجبار ورود/حذف، اعتبار SIP را هم می‌چرخاند. حذف از دفترچه و PBX اعمال می‌شود؛ tombstone برای سوابق و FKها باقی می‌ماند. ساخت دوباره شماره، توکن قبلی را احیا نمی‌کند. عملیات حساس در تماس فعال رد می‌شود.
- گوشی آنلاین با401، credential و دفترچه محلی را پاک و SIP را متوقف می‌کند؛ دفترچه باز کنار می‌رود و ورود دستی نمایان می‌شود. در شروع سرد نیز توکن ذخیره‌شده پیش از ورود خودکار بررسی می‌شود. گوشی آفلاین پس از ارتباط دوباره از ابطال مطلع می‌شود.
- تنظیمات سرور از آیکون تنظیمات در ورود/شماره‌گیر باز می‌شود. رمز دولوپر با verifier نمک‌دار PBKDF2 و محدودیت تلاش بررسی می‌شود؛ آدرس host[:port] در ذخیره امن می‌ماند. پس از تغییر، ورود دستی لازم است. قفل محلی جای احراز هویت سرور نیست؛ TLS و hostname validation حفظ‌اند. CA جدید به APK متناسب با آن نیاز دارد.
- `./smi server configure --host <ip-or-dns> --tls internal|public` آدرس اعلان‌شده را تنظیم و `./server start` اعمال می‌کند. IP کارت شبکه را تغییر نمی‌دهد. آدرس همین سیستم151 حفظ شد؛ config152 فقط در فایل ایزوله آزموده شد.
- README.md راهنمای اصلی صفحه GitHub است: نصب تازه، CLI، فایل‌های خصوصی، TLS/CA، پنل، ساخت/نصب APK، تنظیم دولوپر، قفل و عیب‌یابی. README.fa.md به آن ارجاع می‌دهد.

رمز دولوپر فقط در `deploy/secrets/developer-password` سیستم سازنده است؛ plaintext وارد سورس/Git نشده است. حساب و رمز104/105 تغییر نکردند. برای تعویض IP همان دیتابیس، ترتیب خروج گوشی‌ها هنگام دسترسی به آدرس قبلی و راه بازیابی binding در README آمده است؛ خروج از سرور قطع‌شده قابل تأیید نیست.

## بهینه‌سازی و رگرسیون‌ها

پس از آزمون واقعی اولیه، snapshot و hash دفترچه در singleton تا5ثانیه مشترک cache شدند؛ تغییر پنل پس از commit، فوری invalidate و signal می‌دهد. بررسی session مستقل باقی است. GET تکراری زمان login حذف و snapshot نخست watch جای آن استفاده شد. تغییرات CLI حداکثر5ثانیه بررسی می‌شوند. قطع عادی long-poll خطای500 لاگ نمی‌شود و پاسخ قدیمی بعد از تغییر حساب با epoch کنار گذاشته می‌شود.

نقص قدیمی Logout نیز اصلاح شد: قبلاً پس از پاک‌شدن installationID، binding فعال می‌ماند و ورود با نصب تازه را مسدود می‌کرد. اکنون همه نشست‌های همان installation اتمیک باطل و دستگاه inactive می‌شود. Validate نیز Active/Enabled/Deleted و همخوانی داخلی را بررسی می‌کند. تست ورود دوباره با installation جدید و API واقعی پاس شد.

پیش از اولین ورود، logout بدونتوکن درخواست غیرقابل‌احراز به host پیکربندی‌نشده می‌فرستاد و تنظیمات را تا timeout معطل می‌کرد؛ رگرسیون baseline آن FAIL شد و guard نبودتوکن اصلاحش کرد. حساب‌های قدیمی با نام خالی نیز برای تغییر وضعیت به نام‌گذاری اجباری نیاز ندارند؛ ساخت جدید همچنان نام می‌خواهد.

برای نصب تازه، helper موجود Docker در start، مالکیت پوشه‌های runtime را برای UID1001 آماده می‌کند. فقط گروه سرویس به چهار secret مورد نیاز دسترسی خواندن می‌گیرد(mode640)، بدون world-read؛ رمز دولوپر600 باقی می‌ماند. fixture ایزوله دسترسی1001 و عدم‌دسترسی1002 را آزمود؛ نصب کامل روی VPS تازه NOT_RUN است.

## نتایج همان APK و سرور

تمام مسیرهای زیر نسبت به `evidence/` هستند. پاسخ PASS فقط به دامنه همان سطر مربوط است.

| آزمون / دستور | نتیجه و مدرک |
|---|---|
| `./smi test unit --json` | PASS؛ exit0،54Control+66Flutter+11wrapper+4قفل=135؛unit29-final.log وexit |
| analyze، Release، `./smi check`، diff-check | PASS؛analyze29.log،build29.log/build29-exit.txt،check29-final.log |
| API واقعی ساخت دو حساب و PBXapply، logout/ورود دوباره، اجبار ورود، تغییر رمز، حذف و استفاده دوباره شماره | PASS؛api-e2e28-final.log؛توکن قدیمی نامعتبر و metadata حساب‌های قبلی حفظ شد |
| دو اتصال احرازشده long-poll | PASS؛تغییر بدون refresh؛مشاهده اولیه0.174s،پس ازcache0.164s و تکرار آخر0.006s؛benchmark جامع CPU/بار نیست |
| فیلتر و جست‌وجوی پنل | PASS با assets واقعی و دو حساب ساختگی/mock fetch؛ورود production بدون خطایJS بارگذاری شد؛API واقعی جدا آزموده شد؛browser-ui.json |
| runtime مجوز فایل نصب و config CLI | PASS در fixture ایزوله؛runtime-permissions.json وstatic-config.log؛شبکه151 عوض نشد |
| رمز دولوپر روی API26/35 | PASS؛رمز غلط رد،صحیح ذخیره،151:443 و ورود دوباره؛native-final29.json |
| دفترچه باز هر دو Android، بدون refresh | PASS؛ساخت4.826s،نام4.682s،حذف4.534s زمان مشاهده با UIAutomator؛contacts29.json؛این اعداد تأخیر قطعی انتقال نیستند |
| ابطال نشست با دفترچه باز | PASS؛دفترچه بسته،ورود نمایان و ورود دستی موفق؛contacts29.json |
| Android8→15 پس از حذف rootTask فقط اپ15 | PASS؛بدون Activity و با سرویس؛نام+داخلی،زنگ،پاسخ،Bridge/RTP،پایان؛task15-state.json/runner |
| Android15→8 با صفحه خاموش8 | PASS؛نام+داخلی،زنگ،پاسخ وRTP؛lock8-state.json/runner |
| زنگ پس از پاسخ | PASS در NMS؛soundKey/vibrateKey هردوnull و4101حذف شد؛صوت شنیداری NOT_RUN |
| پایداری مکالمه دوم | PASS؛hold60ثانیه اضافه،uptime96/99ثانیه،RTP دوطرفه وlost0؛lock8-hold60.json/rtp-after60.txt |
| پایان هر دو تماس | PASS؛صفرکانال و حذف4101/4102؛بازگشت4201؛مشاهده cleanup0.067s و2.422s؛state/end-count |
| گیت runtime لاگ SDK144 پس از تماس‌ها | PASS؛هر PID9marker،صفر ICE/SDP/Authorization/FATAL؛final-runtime-log-gate.json؛rawlog نوشته نشد |
| شروع سرد و حفظ آدرس/حساب در8و15 | PASS؛PIDجدید،بازیابی حساب و151:443؛cold-config29.json؛بازکردن صریح بعد ازforce-stop،نه دریافت درforce-stop |
| هش نصب‌شده هر دو، امضای ارتقا و SDK سهABI | PASS؛provenance29.json/signer29.txt؛overlayبا build یکسان |
| اسکن محدود credentialهای شناخته‌شده وbase64 درworktree/APK | PASS؛secret-scan29.json؛auditجامع نیست |
| دریافت کامل APK از151:8765 درPC | PASS؛HTTP200،90,874,038بایت وSHAیکسان؛http29.json؛آزمون دانلود گوشی نیست |
| گوشی واقعیAPK29،صدای شنیداری و قفل طولانی/OEM | BLOCKED؛دستگاه متصل نیست؛نمونه‌ها به همه مدل‌ها تعمیم داده نمی‌شوند |
| Android9–14 در این مرحله | NOT_RUN؛طبق ترجیح مالک فقط8/15 استفاده شدند |

مجموع دو اجرای نهایی تماس،10مرحله باexit0 بود. نام‌های موقت QA ALPHA/BETA روی101/103 پس از آزمون به مقدار اصلی برگشتند؛104/105 لمس نشدند. تصاویر تماس و دفترچه فقط داده آزمایشی/عمومی دارند؛ تصاویر تلاش‌های ناموفق ورود دارای احتمال نمایش رمز درGit نیستند.

## شکست‌های حفظ‌شده

- build25 با shadowشدن java در GradleKotlinDSL نتوانست Properties را resolve کند؛ import صریح رفع کرد. runner طولانی build27 خروج143 داشت؛ اجرای مستقل detached بعدیexit0 بود. نمونه‌های25تا28 منتشر نشدند.
- helperهای پروتوتایپ27/28، disabled-server را اشتباه EditText شمردند و با IME مختصات field دیگر تغییر کرد. انتظار2ثانیه نیز برای مسیر قدیمی logout بدونتوکن کوتاه بود. ورودSIP پس از تنظیم151:443در28 بعداً PASSشد؛ به29نسبت داده نمی‌شود.
- دو UIAutomator هم‌زمان روی یک guest بودند و prepare27 باexit137 شکست خورد؛ علت قطعی کرنل ثابت نشد. helper نسل28 نیز در جایگزینی نسخه، loopback127را128 کرد؛ fixture اصلاح شد وIPمحصول تغییر نکرد.
- در8، tooltip با newline آغاز می‌شد؛ selector نخست FAIL و normalize در helper موفق شد. selector فیلتر وب با label هم پیدا نشد و ID مستند موفق بود.
- status بلافاصله پس از compose،درکمتر از1ثانیه live000/BLOCKED داد؛ پس از readiness200 ادامه یافت. یک helper دفترچه هم متغیر path را با URL بازنویسی کرد و هنگام ذخیره عکس/گزارش TypeError داد؛ namespace جدا و تکرار نهایی PASSشد.
- تماس اول29 در مرحله end،صفرکانال داشت ولی همان لحظه4102هنوز بود؛ مشاهده مستقل بعدی4201را نشان داد. runner برای پاک‌سازی asynchronous نیز bounded انتظار اضافه کرد؛ دو اجرای نهایی PASSشدند. کد محصول برای این مورد تغییر نکرد؛ FAIL اولیه نگه داشته شد.

DB پیش از migration با Control متوقف‌شده، خصوصی وmode600 کپی و سرویس بلافاصله برگردانده شد؛ backup در tool-results نادیده‌گرفته‌شده است. restore آن NOT_RUN است. برای جبران wipe شناسه در پروتوتایپ، bindingQA103 یک‌بار آزاد شد؛ رمز آن تغییر نکرد. secrets واقعی،DBbackup و rawSDKlog واردGit نیستند.

## تحویل و مرحله بعد

APK: `artifacts/android/mini-voip-free-0.3.0+29-lan.apk`

SHA256: `221367448dc762a699e1f5965baa734d35bd97de2f9f1a5f6136352fdcd0d32f`

همان فایل در `http://192.168.1.151:8765/` و Desktop/Mini VoIP Manual Test قرار دارد؛ امضای قبلی حفظ شده است. صفحه دریافت موقت است و restart خودکار آن بعد از خاموشیPC ادعا نمی‌شود. راهنمای مالک `docs/PHONE_RC_TEST.fa.md` و راهنمای عمومی README.md است.

فایل‌های اصلی: ManagementRoutes/ExtensionManager/assets،migration3،SessionService/Logout،ControlApiClient/CallController/AppConfig،ServerSettingsPage و ورود/شماره‌گیر/دفترچه،SmiDeveloperGate/NativeChannels/overlay/Gradle/buildwrapper،server-configure/prepare-runtime/server-up،قراردادها،تست‌ها،تصمیم0018 و راهنماها. changed-files.txt کلworktree شامل مراحل قبلی commitنشده را هم ثبت می‌کند.

CodeReady: PASS در محدوده اجراشده؛گیت کل محصول باز است. DeviceValidated: BLOCKED برایAPK29 روی گوشی واقعی. Deployed: PASS برای سرور و دریافت محلی همینAPK. Published: NOT_RUN برای انتشار رسمیAPK/iOS. تحویل منبع GitHub پس از ثبتQA جدا ثبت می‌شود.

مرحله بعد: Update روی دو گوشی، تست دفترچه زنده/ابطال نشست و تماس؛ برایسرورجدید،config/TLS/CAرا مطابقREADME آماده کنید. QA8/15 پس از صفرکانال برای آزادکردن منابع متوقف شدند؛سه سرویس محصول و دریافتAPK فعال ماندند.

برای حفظ bytes منبع vendor و context معتبر patch، بررسی whitespace با .gitattributes برای import و فایلdiff مستثناست؛ EOFدو فایل بومیِ متعلق‌به‌پروژه فقط از blankline اضافی پاک شد، بدون تغییر دستور یا خط کد. overlayها با هم برابرند.

## تحویل منبع GitHub

PASS؛ commit کد آزموده‌شده [421c032](https://github.com/SSSchangerSSS/mini-voip-free/commit/421c032449ce793685974fa3773bb67c5079b4fc) بهorigin/main ارسال و SHAازخودremoteتطبیق داده شد؛worktreeدرلحظهبررسیتمیزبود. README.mdازAPIواقعیGitHubدریافتوهشblobباREADMEمحلیبرابرشد. شواهد github-source-delivery.json وgithub-readme.json هستند. این تحویل، انتشار رسمی APK/AppStore نیست. این رسید و وضعیتT81درcommitمستنداتبعدیثبت می‌شوند.
