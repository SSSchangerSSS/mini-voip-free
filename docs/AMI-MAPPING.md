# AMI-MAPPING — قرارداد رخدادهای AMI و نگاشت آن‌ها به وضعیت تماس

> وضعیت: **CANDIDATE — UNTESTED**. طبق بخش ۸.۳ سند، تشخیص انتخابی `Connected` باید با trace واقعی
> PBX ثابت شود و همین فایل به‌روزرسانی گردد. تا آن زمان این جدول فقط قرارداد کد است.

## متغیرهای handshake روی کانال (نویسنده/معنا)

| متغیر | نویسنده | مقدار/معنا |
|---|---|---|
| `SMI_ADMITTED` | Dialplan سپس Control | `0` منتظر، `1` پذیرفته، `-1` رد؛ شرط انتظار `!=0` |
| `__SMI_CALL_ID` | Control (قبل از admission) | UUID سرور؛ با inheritance به leg مقصد |
| `__SMI_CALLEE` | Dialplan | داخلی اعتبارسنجی‌شده |
| `SMI_DEADLINE_EPOCH` | Control | Unix seconds؛ همان deadline پاسخ API |
| `SMI_DIAL_ALLOWED` | Dialplan سپس Control | `0` تا ready معتبر، `1` پس از آن؛ فقط یک Dial |
| `SMI_REJECT_CAUSE` | Control/Dialplan | whitelist: `busy=17, rejected=21, unallocated=1, unavailable=20` |

## رویدادهای AMI → تصمیم Control

| رخداد/منبع | فیلدها | اثر در Control |
|---|---|---|
| `UserEvent: SMICallRequested` | SchemaVersion=1, PbxUniqueId, Channel, CallerEndpoint, Callee, AttemptId | اعتبارسنجی + رزرو اتمیک slot + ایجاد `callId`/deadline + Setvar(`__SMI_CALL_ID`,`SMI_DEADLINE_EPOCH`) با بررسی پاسخ، سپس `SMI_ADMITTED=1` |
| `UserEvent: SMICallDialing` | PbxUniqueId, CallId | ثبت `sipDialStartedAt` |
| `UserEvent: SMICallFinished` | PbxUniqueId, CallId, HangupCause, DialStatus | نهایی‌سازی پایان (در کنار `Hangup` استاندارد) |
| `Hangup` استاندارد | CallerIDNum/ConnectedLineNum, Cause, UniqueID | نگاشت cause → EndReason؛ آزادسازی slot |
| `DialBegin`/`DialEnd` | DestUniqueID, DialStatus | ثبت مرحله؛ `DIALSTATUS=ANSWER` به‌تنهایی `Connected` نیست |
| `BridgeEnter`/`BridgeLeave` | BridgeUniqueid, ChannelUniqueID | **تشخیص `Connected`: ورود هر دو leg همان تماس به یک bridge** (شواهد PBX) |
| `VarSet` (فیلتر `Variable: SMI_*`) | Value | trace/persist پارامترهای handshake |

## نگاشت HangupCause → EndReason (کاندید آزمون)

| Q.850 | معنا | EndReason |
|---|---|---|
| 16 | Normal Clearing | Completed (یا CallerCancelled بسته به سمت/زمان) |
| 17 | User Busy | Busy |
| 18/19 | No Answer / Call Rejected | NoAnswer |
| 20 | Subscriber Absent | Unavailable |
| 21 | Call Rejected | Declined |
| 1 | Unallocated | Unavailable |
| سایر | — | SetupFailed (ثبت cause خام در لاگ ساختاریافته) |

⚠️ از یکسان‌بودن cause عددی با SIP status code نتیجه‌گیری نشود؛ خروجی واقعی با trace تأیید شود.

## اثبات لازم در P2 (قبل از حذف برچسب UNTESTED)

- [ ] trace کامل یک تماس موفق 101→102: ترتیب `SMICallRequested → Setvar responses → SMICallDialing → DialBegin/End → BridgeEnter (هر دو) → BYE → Hangup`.
- [ ] آزمون cancel حین انتظار admission و حین زنگ (جزئیات بخش ۵.۳).
- [ ] ثبت خروجی واقعی causeهای 17/21/1/20 از PBX نسخه 22.11.0 و تطبیق mapping.
- [ ] ثبت رفتار واقعی `WaitForCondition` با `${VAR}` (ارزیابی مجدد یا expansion یک‌بار).
