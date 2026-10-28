# mini-voip-free

تلفن داخلی ساده برای Android و iOS: **تماس صوتی دونفره** بین کارکنان با شماره داخلی، از طریق سرور شرکت با IP ثابت.

> این مخزن مطابق قرارداد پیاده‌سازی `docs/PROJECT_SPEC.fa.md` ساخته می‌شود.
> معماری ثابت: **Flutter + sip_ua/flutter_webrtc** (اپ) + **Asterisk 22 LTS** (مرکز تلفن) + **.NET 10 Minimal API** (کنترل) + **SQLite** + **Caddy** (ورودی TLS/WSS).

## وضعیت فعلی (شفاف)

| مؤلفه | وضعیت |
|---|---|
| ساختار مخزن + قراردادها + اسناد | ✔ آماده |
| سرویس Control (API، ماشین حالت، slot اتمیک، احراز هویت) | کد اولیه + تست unit سبز (جزئیات: `qa/`) |
| قالب‌های Asterisk / Caddy / Compose | نوشته‌شده، **آزمون زنده روی PBX واقعی باقی است (P2)** |
| اپ Flutter + آداپتورهای بومی (PushKit/CallKit، FCM/Core-Telecom) | کد اولیه؛ **build Release و تست دستگاه انجام نشده (P0/P3)** |
| Push واقعی APNs/FCM | نیازمند ورودی‌های کارفرما — `BLOCKED` (بخش ۱۹ سند) |
| انتشار (APK امضاشده / TestFlight / Unlisted) | `BLOCKED` تا فراهم‌شدن signing و حساب‌ها |

هیچ‌کدام از موارد بالا «آماده تولید» اعلام نمی‌شود؛ معیار تحویل نهایی در بخش ۱۸ سند است.

## نصب سرور (خلاصه؛ کامل: `docs/USAGE.fa.md` و `docs/RUNBOOK.fa.md`)

پیش‌نیاز: Ubuntu Server 24.04 LTS (amd64)، Docker + Compose، دامنه واقعی با DNS صحیح رو به این سرور، TCP 80/443 و UDP 10000–10199 باز.

**مسیر سریع (یک‌دستوری):**

```bash
unzip mini-voip-free-server-bundle-r*.zip -d mini-voip-free && cd mini-voip-free
curl -fsSL https://get.docker.com | sh        # اگر docker ندارید
sudo bash scripts/deploy/install-server.sh    # تعاملی: دامنه + ایمیل را می‌پرسد،
                                              # secret می‌سازد، stack را بالا می‌آورد،
                                              # داخلی‌ها را با رمز تولیدشده می‌سازد
```

**مسیر دستی (همان مراحل، کنترل کامل):**

```bash
git clone <repo-url> mini-voip-free && cd mini-voip-free
cp deploy/site.env.example deploy/site.env      # ویرایش: SMI_DOMAIN و SMI_ACME_EMAIL
./smi doctor                                    # بررسی پیش‌نیازها (اختیاری)
./smi server init --config deploy/site.env      # اعتبارسنجی config + آماده‌سازی فایل‌ها
./smi server up                                 # بالا آمدن edge/pbx/control
./smi extension add 101 --credential-file /path/to/passfile   # رمز از فایل خوانده می‌شود، نه CLI
./smi extension add 102 --credential-file /path/to/passfile2
```

## گرفتن APK اندروید با IP/دامنه سرور خودتان

Workflow ‏`.github/workflows/android-build.yml`‏ یک فرم اجرای دستی (Run workflow) دارد:
فیلد **`server_ip`** (IP یا دامنه سرور) و **`server_port`** (پیش‌فرض 443) را وارد کنید؛
APK با همان آدرس پخته می‌شود (dart-define ‏`SMI_SERVER_HOST/PORT`)‏ و آرتیفکت‌های
**APK** و **باندل کد سرور** (git archive — شامل هرگز secrets نیست) در همان صفحه‌ی اجرا
برای دانلود ظاهر می‌شوند. قدم‌به‌قدم: `docs/USAGE.fa.md` §۴.

وضعیت صادقانه‌ی این بیلد: APK با کلید debug امضا شده (B6) و در حالت بدون-Push ساخته
می‌شود چون پروژه‌ی Firebase هنوز موجود نیست (B3) — تماس ورودی در حالت اپِ باز/ریسنت
کار می‌کند؛ push پس از باز شدن B3 فعال می‌شود.

سپس اپ را نصب کنید و در صفحه ورود: دامنه سرور، شماره داخلی (مثلاً `101`) و رمز همان داخلی را وارد کنید. تماس خروجی: وارد کردن ۳ رقم مقصد (مثلاً `102`) و زدن تماس.

## توسعه

```bash
./smi doctor          # وضعیت SDKها و پیش‌نیازها
./smi test unit       # تست‌های unit موجود (Control + Flutter)
```

حداقل نسخه‌های هدف: Android 10 (API 29) / iOS 16. Codec نسخه ۱: PCMU (ulaw)، audio-only. جزئیات و محدودیت‌ها: `docs/ARCHITECTURE.md` و سند پروژه.

## امنیت در یک نگاه

- هویت تماس‌گیرنده فقط از endpoint احرازشده PBX؛ هدرهای SIP قابل‌جعل مبنای اعتماد نیستند.
- رمزها با PBKDF2-HMAC-SHA256 (۶۰۰ هزار تکرار) ذخیره می‌شوند؛ توکن نشست تصادفی ۲۵۶ بیتی با hash نگهداری می‌شود.
- صوت مسیر DTLS-SRTP دارد (رمزنگاری در مسیر، نه E2EE) و از Asterisk عبور می‌کند.
- فقط `/api/v1`، `/health` و `/ws` از اینترنت سرو می‌شوند؛ AMI/HTTP داخلی/5060 عمومی نیستند.
- سیاست کامل: `docs/SECURITY.md`.

## مجوزها و منابع ثالث

`THIRD_PARTY_NOTICES.md` فهرست وابستگی‌ها و مجوزهای آن‌هاست؛ قبل از توزیع نهایی باید کامل شود.
