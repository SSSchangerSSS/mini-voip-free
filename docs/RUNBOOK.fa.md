# RUNBOOK — عملیات mini-voip-free

> بخش‌های قابل‌اجرا امروز فقط دستورهای تأییدشده‌اند؛ هر فرمانی که هنوز اجرا نشده
> صریحاً مشخص است. معیار: «هر دستور README واقعاً کار کند» (بخش ۱۲ سند).

## وضعیت پوشش فرمان‌ها (به‌روزرسانی با هر مرحله)

| فرمان | وضعیت | توضیح |
|---|---|---|
| `./smi doctor` | ✔ اجرا/آزمون | بررسی SDK، پورت، secretها (بدون نمایش مقدار) |
| `./smi check` | ✔ اجرا/آزمون | syntax اسکریپت‌ها + قراردادها + YAML |
| `./smi test unit` | ✔ اجرا/آزمون | dotnet test (42/42) + قرارداد؛ flutter test فقط با SDK |
| `./smi extension add/disable` | ✔ اجرا/آزمون | CLI واقعی + render اتمیک accounts.conf (smoke test انجام شد) |
| `./smi device reset` | کد واقعی، smoke آغاز نشده | نیازمند PBX زنده برای reload |
| `./smi server init/up/status/logs` | کد واقعی | نیازمند سرور واقعی (PREFLIGHT B1) — BLOCKED |
| `./smi build android/ios` | کد واقعی | نیازمند flutter/xcode (B4) — BLOCKED |
| `./smi backup/restore` | کد واقعی | روی سرور واقعی آزمون شود (T48) |
| `./smi upgrade/rollback/verify-release` | کد واقعی | پس از اولین release معنادار است |

## نصب اولیه (خلاصه عملیاتی)

1. پیش‌نیاز سرور: Ubuntu 24.04 LTS، Docker + Compose، DNS دامنه → این سرور،
   فایروال: TCP 80/443 + UDP 10000–10199 باز، SSH محدود.
2. `git clone` و `cp deploy/site.env.example deploy/site.env` و پرکردن `SMI_DOMAIN`/`SMI_ACME_EMAIL`.
3. ساخت AMI secret: `openssl rand -base64 32 | tr -d '\n' > deploy/secrets/ami && chmod 600 deploy/secrets/ami`.
4. `./smi doctor` — همه چیز باید PASS/معلوم باشد.
5. `./smi server init --config deploy/site.env` — اعتبارسنجی، دایرکتوری‌ها، manager.conf، Caddyfile validate.
6. `./smi server up` — سه سرویس.
7. `./smi server status` — `/health/ready` باید 200 شود (پس از reconcile AMI).
8. `./smi extension add 101 --credential-file /path/secure` و همان برای `102`.
9. نصب اپ (وقتی build شد) و ورود با دامنه/داخلی/رمز.

## سلامت و عیب‌یابی سریع

- `/health/live` پاسخ نمی‌دهد: container control را ببینید: `./smi server logs control`.
- `/health/ready` = 503: AMI وصل نیست → `./smi server logs pbx` + بررسی `manager.d/smi-control.conf`.
- تماس زنگ نمی‌خورد: لاگ کنترل با callId: `./smi server logs control --call-id <UUID>`.
- ری‌استارت Control نباید تماس متصل را قطع کند (طراحی: بخش ۵.۵ سند) — در P2 با T35 اثبات می‌شود.

## پشتیبان و بازیابی

- `BACKUP_PASSPHRASE=... ./smi backup --output /secure/backup.enc` (کلید خارج از سرور).
- بازیابی: `BACKUP_PASSPHRASE=... ./smi restore --input /secure/backup.enc --confirm` و سپس **تماس آزمایشی واقعی**.

## چرخه انتشار

`./smi verify-release --manifest release-manifest.json` پس از هر release. جزئیات انتشار اپ:
`docs/ANDROID-RELEASE.fa.md` و `docs/IOS-RELEASE.fa.md`.
