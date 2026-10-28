# Third-Party Notices

> وضعیت: پیش‌نویس P0/P1. این فهرست باید **قبل از هر توزیع** (image، APK، IPA) کامل و با
> نسخه‌های نهایی `pubspec.lock`/NuGet lock تطبیق داده شود. نتیجه حقوقی خودکار درباره
> ترکیب مجوزها گرفته نمی‌شود؛ تعهدات متن واقعی هر مجوز رعایت شود و خروجی source/notice
> لازم هنگام توزیع فراهم گردد (الزام بخش ۱۱.۴ سند پروژه).

## Server / Infra

| Component | Version | License | Source |
|---|---|---|---|
| Asterisk | 22.11.0 LTS | GPL-2.0 | https://downloads.asterisk.org/pub/telephony/asterisk/ |
| Caddy | 2.11.7 | Apache-2.0 | https://github.com/caddyserver/caddy |
| .NET Runtime/SDK | 10.0 (lock: 10.0.403) | MIT | https://dotnet.microsoft.com/ |
| Microsoft.Data.Sqlite | 10.0.14 | MIT | https://www.nuget.org/packages/Microsoft.Data.Sqlite |
| SQLite | bundled with Microsoft.Data.Sqlite | Public Domain | https://sqlite.org/ |

نکته توزیع: توزیع image شامل Asterisk (GPL-2.0) تعهدات متناظر (از جمله فراهم‌سازی
source متناظر با باینری توزیع‌شده) دارد؛ هنگام انتشار image، متن این تعهد بررسی شود.

## Flutter / Mobile

| Component | Version | License | Source |
|---|---|---|---|
| Flutter | 3.47.8 | BSD-3-Clause | https://github.com/flutter/flutter |
| sip_ua | 1.1.0 | MIT | https://github.com/flutter-webrtc/dart-sip-ua |
| flutter_webrtc | 1.6.3 | MIT | https://github.com/flutter-webrtc/flutter-webrtc |
| http (Dart) | 1.6.0 | BSD-3-Clause | https://pub.dev/packages/http |
| Firebase Android SDK | per lockfile | Apache-2.0 | https://github.com/firebase/firebase-android-sdk |
| WebRTC native (libwebrtc) | bundled by flutter_webrtc | BSD-3-Clause | https://webrtc.googlesource.com/src |

## Client SDKs (runtime services, not bundled server-side)

| Component | Usage | Notes |
|---|---|---|
| Firebase Cloud Messaging | Android push | Terms of service apply; no Analytics/Auth added (spec section 9.4) |
| Apple Push Notification service | iOS VoIP push | Apple developer terms apply |

## To verify before distribution

- [ ] Generate final dependency list from committed `pubspec.lock`, NuGet `packages.lock.json`, Gradle/Aerlock outputs.
- [ ] Add licenses of all transitive dependencies that require attribution.
- [ ] Record image digests of caddy/base images used in the released build.
- [ ] Provide corresponding source (or written offer) for GPL-2.0 components in distributed images.
