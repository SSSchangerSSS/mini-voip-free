from pathlib import Path
import json,hashlib,datetime,subprocess
root=Path('qa/reports/2026-10-31-manual-rc');b=root/'final'
def read(name):return json.loads((b/name).read_text())
steps=read('steps.json');assert len(steps)==14 and all(x['status']=='PASS' and x['exitCode']==0 for x in steps)
a=read('android8-smoke.json');ui=read('ui-cycles-result.json');c=read('call-to8-stages.json');s=read('soak-result.json');t=read('timeout-result.json');cold=[read('cold1-result.json'),read('cold2-result.json')]
assert read('visual-review.json')['status']=='PASS'
apk=Path('artifacts/android/mini-voip-free-0.1.1+4-lan.apk');sha=hashlib.sha256(apk.read_bytes()).hexdigest()
assert sha=='3b51431c961e234d3f1b5be1545bfaebe6af461aa3ec18835c2a9950194e10f1'
text=f'''# نسخه آزمایشی0.1.1+4 برای تست دستی — 2026-10-31

**نتیجه: PASS برای سناریوهای foreground ثبت‌شده روی همین PC.** APK نهایی روی Android8/API26/داخلی101 و Android15/API35/ReDroid/داخلی103 نصب شد؛ همه14 مرحله داخلی runner با exit0 تمام شدند. فرمان بیرونی ترمینال exit143 داشت؛ وضعیت اجرای بیرونی FAIL است و دلیل قطعی آن مشخص نشد. نتیجه عملکرد از شواهد مستقل مرحله‌ها و بررسی کوتاه نهایی با exit0 ارزیابی شده است. این تأیید تولید، همه مدل‌های گوشی یا صدای شنیداری نیست.

## فایل نصب و محیط

- APK: `artifacts/android/mini-voip-free-0.1.1+4-lan.apk`؛ SHA256: `{sha}`؛ versionName0.1.1/versionCode4، minSdk26، targetSdk36. باینری پس از آزمون بازسازی/تعویض نشد. امضا همان کلید **Android Debug محلی** است؛ امضای کارفرما BLOCKED. `final/signature.txt` و `final/apk-badging.txt`.
- سرور TLS محلی `192.168.1.151` با همان CA خصوصی؛ صحت زنجیره/SAN خاموش نشده است. Android8 همان AVD با نمایش Qt و Android15 همان کانتینر ReDroid با digest قفل‌شده تصمیم0009 است. AVD قدیمی15 با TCG برای fallback حفظ شده؛ ANRهای آن رفع‌شده معرفی نمی‌شوند. فقط runtime8 و15 استفاده شدند؛ target/compile36 به معنی دانلود runtime16 نیست.
- manifest سورس/نسخه/hash در `release-manifest.json` است. commit پایه در آن ثبت شده و تغییرات این مرحله هنوز commit/push نشده‌اند. فایل نصب، secretها و داده runtime خارج Git هستند.

## اصلاح‌های لازم برای این نامزد

پنج خطای بازتولیدشده در کنترل تماس رفع شدند: timeout پایان، شکست SIP هنگام پایان، قطع اتصال accept/decline/ready. پایان SIP و API مستقل تلاش می‌شوند؛ UI در Ending باقی نمی‌ماند و تأیید ناقص صریح است. پاسخ تأییدنشده نیازمند عمل تازه کاربر است و INVITE دیررس خودکار پاسخ داده نمی‌شود. ready ناموفق شبکه/502/503/504 با همان کلید idempotency در پنجره موجود تکرار می‌شود. همچنین پایان عادی ENDED/Completed از شکست واقعی جدا شد؛ پیام‌های قبلی هنگام تماس جدید، پاسخ مجدد و Connected پاک می‌شوند. تغییرات در همان کنترل‌کننده و قرارداد قبلی‌اند؛ wire identifiers، نسخه وابستگی‌ها و deadline عوض نشدند. جزئیات و regressionها: تصمیم0010.

در راه‌اندازها، سرور تازهADB دیگر FD9/قفل شروع را به ارث نمی‌برد. نشت واقعی و چهار آزمون flock در تصمیم0011 و `lock-inheritance-before/after.txt` و `launcher-regression.log` ثبت‌اند. helper نصب‌شده با سورس همسان است. پس از reboot میزبان، Binder به احراز هویت محلی نیاز داشت؛ کاربر آن را بارگذاری کرد. تنظیم دائمی boot اضافه نشد.

## فرمان‌ها و خروجی واقعی

پس از `source /home/changer/.config/mini-voip-free/env.sh`:

| فرمان | نتیجه | مدرک |
|---|---|---|
| `./smi test unit` | PASS/exit0؛45Control+40Flutter+8wrapper+4QA-lock=97 | `final/unit.log` |
| `cd apps/mobile && flutter analyze` | PASS/exit0؛ بدون مسئله | `final/analyze.log` |
| `./smi build android --release --server-host 192.168.1.151 --trusted-ca-file qa/reports/2026-10-28-local/lan-root-ca.crt` | PASS/exit0 | `final/build.log` |
| `./smi check` | PASS/exit0 | `final/check.log` |
| نصب ارتقایی `adb install -r` روی هر دو | PASS؛ حساب حفظ شد | `final/upgrade8.log`، `final/upgrade15.log` |
| مرحله‌های داخلی runner | PASS؛ همه14 مرحلهexit0 | `final/steps.json` و log هر مرحله |
| فرمان بیرونی طولانی ترمینال | FAIL/143؛ علت قطعی مشخص نشد | `final/outer-wrapper.json` |
| بررسی کوتاه مستقل باینری/رویدادها/سلامت/صفرکانال | PASS/exit0 | `final/collect-final.log` |

اخطار مهاجرت آتی Kotlin وابستگی‌ها در لاگ ساخت حفظ شده است؛ ارتقای بی‌تصمیم انجام نشده است. تست‌های قفل، فرایند واقعی/flock را می‌آزمایند و تست دستگاه نیستند. تست‌های Flutter/Control نیز جای دستگاه واقعی نیستند.

## آزمون همین APK روی دو محیط QA

| سناریو | نتیجه | مدرک در `final/` |
|---|---|---|
| اجرای سرد اپ8، بازیابی بدون رمز/پاک‌کردن داده | PASS؛{a['coldAppRestores'][0]['seconds']}s تا مشاهدهReady در procedure | `android8-smoke.json` و تصویر upgrade-ready |
| تماس با خود101 و داخلی ناشناخته199 | PASS در smoke؛ برگشت بهidle | همان JSON و تصاویر rejected |
| سه چرخه Home/برگشت و باز/بسته‌کردن اعلان‌ها در15 | PASS؛ بدونANR/crash | `ui-cycles-result.json` |
| تماس103→101، پاسخ، Bridge مشترک و RTP دوطرفه | PASS در دامنه سیگنالینگ/انتقال | `call-to8-stages.json` و media/images |
| پایداری در13نمونه طی{s['observedSeconds']}s، میوت{c['controls']['muteIntervalSeconds']}s و کلید بلندگو | PASS در دامنه UI/پایداری | `soak-result.json`، stages، تصاویر muted/speaker/controls |
| تماس101→103 و قطع | PASS؛ RTP و صفرکانال | `call-to15-stages.json` |
| رد تماس و لغو پیش از پاسخ | PASS؛ هر دو بهidle و صفرکانال | `decline-result.json`، `cancel-result.json` |
| پایان بدون پاسخ | PASS؛ عمر سرور{t['serverPendingLifetimeSeconds']}s | `timeout-result.json` |
| دو شروع سرد runtime15 و حساب ذخیره‌شده | PASS؛ SIP تازه{cold[0]['registeredSecondsFromStart']}/{cold[1]['registeredSecondsFromStart']}s، صفرANR/crash | `cold1/2-result.json` و تصاویر |
| تماس پس از شروع سرد15 و قطع | PASS؛ RTP و صفرکانال | `call-postcold-stages.json` |
| خطای قبلی روی تماس ورودی جدید باقی نماند؛ پایان عادی خطا نسازد | PASS در بازبینی تصاویر همین باینری | `visual-review.json` و تصاویر connected/idle |

زمان‌ها مربوط به procedure شامل فرمان/انتظار/UI dump هستند؛ زمان لمس خالص یا reboot کلPC نیستند. تغییر بعضی شمارنده‌های RTP هنگام میوت متوقف و پس از unmute دوباره شروع شد. این مشاهده و رنگ کلیدها، اثر فیزیکی میکروفون/بلندگو را اثبات نمی‌کنند. تصاویر کنترل‌ها با1.5s مکث پس از لمس ثبت و بازبینی شدند. سه تماس پاسخ‌داده‌شده و سه سناریوی رد/لغو/بی‌پاسخ این باینری، جای100چرخه پذیرش یا ظرفیت‌سنجی عمومی را نمی‌گیرند.

## تاریخچه شکست و محدودیت

نامزد2 به‌علت پیام کاذب خطا پس از پایان عادی و نامزد3 به‌علت باقی‌ماندن پیام قبلی روی تماس ورودی کنار گذاشته شدند. [گزارش2](REPORT-candidate2.fa.md)، [گزارش3](REPORT-candidate3.fa.md) و شواهدشان حفظ شده‌اند؛ نتایج آن‌ها به این باینری نسبت داده نمی‌شوند. رگرسیون‌های قبل از اصلاح FAIL و آزمون‌های پس از اصلاح PASS هستند. علاوه بر آن، outer command اجرای طولانی نامزد4 exit143 داد (`final/outer-wrapper.json`)؛ این شکست اتوماسیون پنهان/به PASS تبدیل نشده است. چهارده child-step نتیجه و exit0 خود را مستقل ذخیره کردند؛ بررسی کوتاه مستقل باینری نصب‌شده، Ready، سلامت سرور و صفرکانال با exit0 تکرار شد. علت exit143 اثبات نشده و ادعای رفع خود ابزار اجرای ترمینال وجود ندارد. ادامه runner نامزد3 بعد از اتمام امن تماس عمداً متوقف شد؛ مراحل باقی‌مانده آن NOT_RUN هستند.

گوشی واقعی، صوت شنیداری، Push/قفل/پس‌زمینه، iOS، Android9–14، امضای سازمانی و انتشار تأیید نشده‌اند. خاموش‌روشن‌کردن کامل میزبان با این APK NOT_RUN است؛ شروع سرد کانتینر با rebootPC یکی نیست. نبود Binder بعد از boot می‌تواند نیازمند پنجره احراز هویت محلی باشد. همه60 ردیف پذیرش حفظ شده‌اند و وضعیت آن‌ها برای سبزشدن این گزارش تغییر نکرده است.

**نامزد foreground محلی: PASS؛ Deployed محلی: PASS؛ CodeReady کل F01–F09: BLOCKED؛ DeviceValidated: BLOCKED؛ Published: BLOCKED.**

## تحویل و مرحله بعد

پوشه **Mini VoIP Manual Test** روی دسکتاپ شامل APK نهایی، SHA256SUMS و لینک راهنما/گزارش است. میانبر Android8 با101 و Android15 با103 باز گذاشته شدند. هویت APK واقعاً نصب‌شده روی هر دو با SHA256 یکسان بررسی شد (`final/installed-apk-identity.json`). سلامتDB/AMI، contactهای101/103، صفر کانال و نبودANR/crash پایان اجرا در `final/final-*` ثبت‌اند. اسکن محدود secretهای محلی شناخته‌شده و base64 آن‌ها روی worktree و APK در `final/known-secret-scan.json` است؛ جای audit جامع نیست.

فایل‌های اصلی تغییرکرده: کنترل‌کننده/آداپتور SIP/صفحه تماس و نسخه، دو فایل تست Flutter، دو راه‌انداز QA، تست قفل و runner واحد، تصمیم‌های0010/0011، README/راهنمای دستی/AGENTS، ارجاع‌های پذیرش و این گزارش. مرحله بعد تست دستی شما طبق `docs/MANUAL_TEST.fa.md` است. تکمیل پذیرش محصول به ورودی‌های Push، امضای کارفرما، دستگاه واقعی و دروازه‌های باقی‌مانده سند نیاز دارد.
'''
(root/'REPORT.fa.md').write_text(text)
print('PASS final report generated from final artifact evidence')
