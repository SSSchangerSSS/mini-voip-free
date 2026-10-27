# tests/system — سناریوهای خودکار سطح سیستم (P2)

ابزار هدف (بخش ۱۵.۱ سند): دو client آزمایشی WebRTC با همان WSS/DTLS-SRTP، دو حساب
واقعی و broker واقعی به PBX متصل. fixture توسعه با **Playwright + SIP.js** مجاز است؛
این ابزارها فقط test dependency هستند و نسخه وب محصول محسوب نمی‌شوند. اعتبارسنجی TLS
production خاموش نمی‌شود؛ مرورگر آزمایش از CA تستِ نصب‌شده استفاده می‌کند.

وضعیت: در P0/P1 اجرا نمی‌شود. اسکلت سناریوها همین‌جا ثبت شده تا پوشش ادعایی شکل نگیرد.

## سناریوهای حداقلی (ترتیب اجرا)

1. `call-101-102` — ثبت دو حساب، تماس 101→102، اتصال، ۱۰ ثانیه صوت دوطرفه با tone،
   قطع از سمت 101، بررسی نتیجه `Completed` و آزاد شدن هر دو slot.
2. `cancel-during-admission` — INVITE، cancel پیش از admission؛ بررسی `CallerCancelled` و slot آزاد.
3. `cancel-during-ring` — cancel پس از زنگ؛ CANCEL سمت SIP و پاک‌سازی UI مقصد.
4. `busy-second-caller` — دو تماس هم‌زمان به 102؛ دقیقاً یکی `Busy`.
5. `timeout-40s` — بدون پاسخ؛ پایان در deadline با `Expired`؛ UI هر دو سمت پاک.
6. `decline-before-invite` — decline پیش از INVITE؛ INVITE دیررس با همان نتیجه رد شود.

## قرارداد خروجی هر اجرا

- فایل گزارش JSON با: scenario، شروع/پایان UTC، نتیجه هر گام، codec/ICE/byte counters،
  commit و build.
- هر شکست (حتی «شبکه‌ای») ثبت می‌شود؛ اجرای مجدد، رکورد شکست را حذف نمی‌کند.
