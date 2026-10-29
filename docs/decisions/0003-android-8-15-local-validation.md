# Android 8–15 and local server validation

Date: 2026-10-28

The employer explicitly requested Android 8 through Android 15 support and emulator testing, with this Ubuntu PC hosting the server at 192.168.1.244. This changes the candidate minimum from API 29 to API 26. The existing Android CI configuration already sets minSdk 26; it is not proof of compatibility. The target support range is API 26–35. The employer subsequently limited emulator downloads and runtime testing to API 26 and API 35. API 27–34 receive source/configuration review only and are not claimed runtime-validated. Each runtime remains NOT_RUN or BLOCKED until evidence exists. Emulator checks do not satisfy the physical-device, audio, push or lock-screen acceptance gates.

Keep HTTPS/WSS certificate validation enabled. A private IP requires a deliberately provisioned trusted certificate with the IP SAN. No TLS bypass is authorized.

Network inspection found another device answering at 192.168.1.244 (MAC 04:d4:c4:53:5e:8d); this Ubuntu VM is 192.168.1.229 (MAC 00:0c:29:24:b5:85). The requested IP reassignment is BLOCKED until the address is free. Do not create a duplicate address.

Versions in toolchain.lock.json remain unchanged. Installation and test evidence is recorded under qa/reports/2026-10-28-local/.

The employer changed the requested server address to **192.168.1.151** after the .244 conflict was explained. ARP probing did not find a responder at .151; NetworkManager profile `mini-voip-lan` now assigns .151/24, gateway 192.168.1.1, preserving the original DHCP profile for rollback. The local app build uses .151. The pre-existing r5 APK tested initially still contains .244 and must not be confused with the new build.

Flutter platform scaffolding generated Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0, compile/target SDK 36 and NDK 28.2.13676358. These previously unrecorded candidates are now locked; minSdk is explicitly 26 as requested. Java 17.0.21+9 and emulator 37.3.5 are recorded with actual download hashes. Build status remains separate from installed-tool availability. Gradle distribution checksum was obtained from the publisher; the JDK publisher checksum lookup was blocked and that limitation is retained in evidence.

Chinese mirrors: Flutter artifacts/pub via CFUG, JDK via TUNA, Android packages and Gradle via Tencent, Maven via Aliyun. The installed Flutter SDK's included Gradle project also requires Aliyun repository declarations; that local mirror-only patch is recorded in the setup report. Docker images use their original registries when available. No dependency versions were overridden to force resolution.

The explicit LAN Compose/Caddy profile uses `tls internal`. Clients must trust its CA through the OS trust store; HTTPS/WSS verification remains enabled. This LAN profile is not evidence of public deployment or physical-device validation.

First local deployment also records/pins the actual Caddy, Debian build-base and .NET image digests from successful pulls/builds. These references select the same bytes already used; they are not version upgrades.
