# نامزد کنارگذاشته‌شده0.1.1+3

APK با SHA256 ac0b7230a69e357891ace70e3c083d2a20e91af39bee582ff7c1ded26d06f14f نصب شد؛ unit/build/analyze PASS بود. بازیابی حساب، UI15، تماس103→101 و پایداری124.36s/میوت70.51s و قطع پاس شدند؛ شواهد در candidate3/ است.

بازبینی تصویر candidate3/call-to8-callee-connected.png پیام خطای شماره‌گیری قبلی را روی تماس ورودی متصل نشان داد: UX این حالت FAIL است. دو assertion مربوط به پاک‌شدن خطای قبلی و retry موفق نیز پیش از اصلاح FAIL شدند؛ stale-message-before.log شاهد است. runner بعد از اتمام امن همان تماس متوقف شد؛ تست‌های بعدی این نامزد NOT_RUN هستند. هیچ تماس فعالی برای توقف runner قطع نشد و شواهد نامزد حذف نشدند. نامزد نهایی0.1.1+4 شواهد مستقل در final/ دارد. release-manifest-candidate3.json hash/سورس همان نامزد را نگه می‌دارد.
