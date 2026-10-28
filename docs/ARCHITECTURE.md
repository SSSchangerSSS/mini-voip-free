# معماری — mini-voip-free

> خلاصه اجرایی بخش‌های ۲، ۴، ۵ و ۶ سند پروژه. مرجع: `docs/PROJECT_SPEC.fa.md`.

## اجزا و مرز مسئولیت

| جزء | انتخاب | مسئولیت محدود |
|---|---|---|
| اپ | Flutter / Dart | صفحات ساده + کنترل وضعیت مکالمه |
| موتور تلفنی اپ | `sip_ua` + `flutter_webrtc` | SIP، SDP، ICE و صوت |
| پل بومی iOS | Swift + PushKit + CallKit | اعلان VoIP، رابط سیستم، هماهنگی صوت |
| پل بومی Android | Kotlin + FCM native + Core-Telecom + CallStyle | اعلان، تماس بومی، سرویس حین تماس |
| مرکز تلفن | Asterisk 22 LTS / PJSIP | احراز هویت SIP، Dialplan، عبور صوت |
| کنترل | ASP.NET Core Minimal API (.NET 10) | نشست دستگاه، Push، وضعیت محدود تماس، AMI |
| ذخیره‌سازی | SQLite (WAL) | حساب‌ها، دستگاه‌ها، نشست‌ها، تماس‌ها |
| ورودی TLS | Caddy 2 | HTTPS، WSS، تمدید گواهی — بدون منطق تجاری |

FreePBX و ARI استفاده نمی‌شوند. کنترل Asterisk فقط از AMI روی loopback.

## مسیر داده

```text
Android / iPhone
    ├── HTTPS /api/v1/... ───┐
    └── SIP over WSS /ws ────┤
                             ▼
                        Caddy :443
                    ┌───────┴────────┐
                    ▼                ▼
              Control API       Asterisk HTTP/WS
              127.0.0.1:5080    127.0.0.1:8088/ws
                    │                │
                    └─ AMI 127.0.0.1:5038 ─┘
                    ├── APNs VoIP → iPhone
                    └── FCM → Android

Audio: App A ⇄ DTLS-SRTP ⇄ Asterisk ⇄ DTLS-SRTP ⇄ App B
```

- صوت از .NET / Caddy / Push عبور نمی‌کند؛ `direct_media=no`.
- رمزنگاری «در مسیر» است، نه E2EE؛ عبارت «رمزنگاری سرتاسری» برای این محصول استفاده نشود.
- فقط TCP 80/443 و UDP 10000–10199 از اینترنت؛ 5038/5080/8088/5060 عمومی نیستند.
- IPv4 مسیر پایه؛ AAAA/IPv6 تا آزمون کامل اضافه نمی‌شود. TURN پیش‌فرض خاموش (`TURN_ENABLED=false`) و فقط با شواهد شبکه اضافه می‌شود.

## شناسه‌ها (خلاصه — جزئیات: بخش ۴.۱ سند)

`extension` (CLI مدیر) — `installationId` (CSPRNG UUID اپ) — `deviceGeneration` (سرور، افزایشی) — `attemptId` (UUID v4 اپ تماس‌گیرنده، در هدر `X-SMI-Attempt-ID`) — `pbxUniqueId` (Asterisk) — `callId` (Control، UUID v4) — `sipCallId` (فقط پروتکل) — `nativeCallUuid` (adapter بومی).

قاعده کلیدی: Asterisk B2BUA است؛ SIP Call-ID دو سمت برابر نیست. هویت تماس‌گیرنده فقط از endpoint احرازشده (`CHANNEL(endpoint)`)، نه از From/Caller-ID.

## زمان‌های پیش‌فرض (تعریف مرکزی در سرویس Control)

`SETUP_TIMEOUT_SECONDS=40` — `AMI_ADMISSION_TIMEOUT_SECONDS=3` — `PENDING_STATUS_POLL_MS=1000` — `RECONNECT_GRACE_SECONDS=15` — `SESSION_IDLE_DAYS=90` — `DIAGNOSTIC_RETENTION_DAYS=7`

همه timestampها UTC/RFC 3339 با `Z`. timerهای درون‌پردازش از clock یکنواخت.

## ماشین حالت سرور

`Pending → Connecting → Connected → Ended`
- از `Pending` و `Connecting` مستقیم به `Ended`. `Connected` فقط با شواهد bridge PBX. downgrade ممنوع. `Ended` نهایی.
- دلایل پایان ثابت: `Completed, Declined, CallerCancelled, NoAnswer, Busy, Unavailable, Expired, NetworkLost, ServerRestart, SetupFailed, AccountDisabled`.

invariantها (بخش ۴.۳ سند): حداکثر یک slot فعال per داخلی؛ رزرو هر دو داخلی در یک transaction؛ صوت قبل از اقدام کاربر شروع نمی‌شود؛ ورود به `Connected` فقط با شواهد PBX؛ هیچ ورودی کلاینت نام کانال AMI/متغیر PBX را تعیین نمی‌کند.

## مسیر تماس 101 → 102 (خلاصه handshake)

1. INVITE با `X-SMI-Attempt-ID` فقط به `sip:102@<domain>`.
2. PBX هویت را از endpoint احرازشده می‌گیرد، `UserEvent(SMICallRequested)` می‌فرستد (بدون Answer).
3. Control اعتبارسنجی می‌کند، هر دو slot را اتمیک رزرو می‌کند، `callId`/deadline می‌سازد.
4. Control با AMI **اول** `__SMI_CALL_ID`/`SMI_DEADLINE_EPOCH` را روی همان کانال ذخیره‌شده می‌نویسد (پاسخ هر action بررسی می‌شود)، **سپس** `SMI_ADMITTED=1`.
5. Push ارسال می‌شود؛ اپ مقصد runtime بومی را فوری نشان می‌دهد، SIP را متصل و `ready` می‌فرستد.
6. Control پس از احراز، `SMI_DIAL_ALLOWED=1` می‌گذارد؛ Dialplan فقط **یک** `Dial` با زمان باقی‌مانده deadline اجرا می‌کند؛ pre-dial handler روی کانال خروجی `X-SMI-Call-ID` می‌گذارد.
7. اپ پاسخ می‌دهد؛ bridge دو leg = `Connected`. قطع: CANCEL/BYE؛ `end` API مسیر پشتیبان است. پایان نهایی، slotها را آزاد می‌کند.

جزئیات رد/لغو/race: بخش ۵.۳ سند. اعلان دیررس/تکراری: بخش ۵.۴ (cancel با VoIP Push جدید ممنوع).
