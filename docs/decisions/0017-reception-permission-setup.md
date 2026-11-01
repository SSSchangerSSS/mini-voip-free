# 0017 — راه‌اندازی مرحله‌ای مجوز دریافت تماس

2026-11-01. مالک درخواست کرد مجوزها ازداخل اپ درخواست شوند تا پیدا کردن منوهای Poco دردسر نداشته باشد. این اصلاح در دامنه دریافت پس‌زمینه موجود است؛ انتقال پیام، SDK و شناسه کانال عوض نمی‌شوند.

صفحه مرحله‌ای با دکمه ادامه، میکروفن/اعلان را از runtime Android درخواست می‌کند؛ باتری و full-screen با Intent رسمی سیستم باز می‌شوند. رد دائمی به اطلاعات برنامه می‌رود. پس ازبازگشت، وضعیت واقعی مجدداً ازnativeخوانده می‌شود؛ صرف بازشدن صفحه، grant نیست. صفحه هنگام تماس ورودی کنار می‌رود. ازengineبدونActivity درbootهیچپنجره مجوزی خودکار بازنمی‌شود.

HyperOS autostart پنجره runtime استاندارد ندارد. مسیراختیاری SecurityCenter فقط در صورتresolveشدنActivityفعال/exported ونداشتنpermissionغیرمجاز اجرا می‌شود؛ ActivityNotFound/SecurityException بهAppInfoعمومی با پیام صریح می‌رود. این مسیرvendor یک best-effort تأییدنشده رویرامواقعی است؛ هیچ checkmark یاادعایautostartفعال ازآن نتیجه نمی‌شود. Queryفقطبرایcom.miui.securitycenterاست؛ QUERY_ALL_PACKAGESاضافه نمی‌شود. این تصمیم استفاده guardedازrouteاختیاری را نسبت به مرحله قبلی کههیچrouteای پیاده نبود، ثبت می‌کند.

APKجدید صرفاً UXمجوز را بهتر می‌کند؛ رفعkillدرPocoAndroid16/HyperOS3تا تستمالک BLOCKEDاست. هیچ مجوزی بی‌اجازه فعال نمی‌شود. nativeoverlayبایدهمانکدساخت باشد. نسخه‌های dependencyقفل‌شده ثابت‌اند.

نتیجه: APK0.2.3+24،126تستPASS؛runtimeمیکروفن/باتریAPI35PASS؛مسیرPocoواقعیBLOCKED. شواهد: qa/reports/2026-11-01-reception-setup/REPORT.fa.md.
