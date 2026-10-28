# platform-overlay — بومی‌سازی پس از flutter create

فایل‌های `apps/mobile` پلتفرمی (android/، ios/) به‌دلیل نیاز به `flutter create`
با نسخه قفل‌شده (3.47.8) اینجا به‌صورت overlay نگهداری می‌شوند تا ساختار پروژه
تکرارپذیر بماند و هیچ فایل دستی خارج از Git شکل نگیرد.

## روش اعمال (پس از اولین `flutter create`)

```bash
flutter create --org app --project-name smi_phone apps/mobile   # فقط بار اول
./scripts/build/apply-platform-overlay.sh                        # همیشه بعد از آن
flutter pub get && flutter analyze
```

اسکریپت overlay فایل‌ها را روی خروجی flutter create کپی می‌کند و مسیرهای کپی را
گزارش می‌دهد. هر فایل overlay محتوای واقعی دارد؛ فایل تزئینی ساخته نمی‌شود.

## محتوا

- `android/` — Kotlin: FirebaseMessagingService بومی، سرویس تماس با CallStyle،
  MainActivity، Manifest با مجوزهای دقیق (بدون مجوزهای اضافی: دوربین/مخاطبین/موقعیت هرگز).
- `ios/` — Swift: PushKit + CallKit provider، AppDelegate، Info.plist و entitlements.

## یادآوری‌های سند

- فقط **یک** FirebaseMessagingService در کد native وجود دارد؛ handler دوم در Dart
  برای همان پیام ممنوع است (بخش ۹.۴).
- کانال bridge فقط `smi.phone/native/v1` است و یک مالک دارد (بخش ۱۰.۲).
- bundle id کاندید `app.minivoipfree` است تا تأیید کارفرما (PREFLIGHT B7)؛ پس از
  تأیید، `--org` و فایل‌های build یکی می‌شوند.
