# 0014 — بررسی سازگاری SDK و دروازه لاگ، 2026-10-31

در SDK بومی150.7871.04 لاگ INFO شامل اطلاعات موقت ICE مشاهده شد؛ raw log در evidence/Git صادر نشده است. سطحnone، حذفLogSink، خاموش‌کردنtracer و gate پیش ازSDP در آزمون اولیه به‌تنهایی این مورد را پاس نکردند. این یافته FAIL است و رفع‌شده معرفی نمی‌شود.

آزمون کنترل‌شده نسخه منتشرشده144.7559.15 (شاخه144؛ انتشار رسمی2026-09-05) با همان Flutter1.6.3 فقط به‌عنوان trial مجاز است؛ هیچ پذیرش یا checksum ساختگی وجود ندارد. نسخه و نتیجه resolve/build/سازگاری/تماس و لاگ باید ثبت شوند. در صورت FAIL، override برگردانده و نسخه150 قفل‌شده قبلی حفظ می‌شود؛ در صورت PASS واقعی، pin و شواهد تصمیم باید به‌روزرسانی شود. هیچ ریشه/صدا/پروتکل جدید جایگزین نمی‌شود.

مرجع ناشر: https://github.com/webrtc-sdk/android/releases/tag/v144.7559.15 ؛ mirror دانلود Maven: https://maven.aliyun.com/repository/central/io/github/webrtc-sdk/android/144.7559.15/ .

نتیجه trial: FAIL در build به‌علت ناسازگاری API جاوا با flutter_webrtc1.6.3؛ evidence `.tool-results/phase2/release14-sdk144-build.log`، exit1. overrideهای Gradle به150.7871.04 برگشتند. SDK144 پذیرفته یا در lock جایگزین نشد. تغییر نسخه بدون عبور دروازه مجاز نیست.
