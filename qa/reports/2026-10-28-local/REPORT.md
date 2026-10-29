# Local installation and Android validation — 2026-10-28

This is evidence of actual checks, not a claim that the application has no defects.

## Requested scope

The employer requested Chinese mirrors, a server on this Ubuntu PC and an Android APK using its LAN address. The initial address .244 was occupied; the employer changed the request to **192.168.1.151**. Only Android 8 (API 26) and Android 15 (API 35) emulator images were requested. API 27–34 have not been runtime-tested. Physical phones were explicitly unavailable.

## Current evidence

| Check | Status | Evidence |
|---|---|---|
| Static shell/contract/YAML validation | PASS | check-final.log |
| Control tests, including AMI login/fragmented TCP regression | PASS, 43 tests | unit-delivery.log |
| Flutter unit tests | PASS, 16 tests | mobile-tests-final.log; unit-delivery.log |
| Command-wrapper regression tests | PASS, 8 tests | build-wrapper-tests-final.log |
| Flutter analyzer | PASS | flutter-analyze-final.log |
| PC static .151/24 and gateway reachability | PASS | network-after.txt |
| Docker/Compose, .NET SDK, Flutter/Dart, Java, Android CLI/emulator installation | PASS (availability only) | doctor-installed-final.log; flutter-bootstrap.log; jdk-install.json |
| Control, Caddy and Asterisk 22.11.0 running; AMI reconciled | PASS | server-status-final.log; server-status-ready.log |
| HTTPS readiness with explicit local CA | PASS, HTTP 200 | https-ready.log |
| HTTPS/WSS subprotocol and local bind checks | PASS | tls-wss-network.json |
| Default trust rejects the uninstalled private CA | PASS, curl exit 60 | tls-wss-network.json |
| Existing r5 APK ZIP and signature verification | PASS, DEBUG certificate | apk-badging.log; apk-signature.log |
| Existing r5 APK Android 8 install/launch | PASS (UI smoke only) | api26-install.log; api26-launch.log; api26-login.png |
| Android 8 empty-form validation and large text inspection | PASS for tested screen only | api26-empty-form.xml; api26-large-font.png |
| Android 15 software emulator boot | PASS | api35-boot.json |
| New universal .151 APK release build | PASS (debug signing) | android-build-ndk-links-fixed.log; apk-151-inspection.json |
| New .151 APK on Android 15 | PASS for install/eventual login rendering/empty form only; initial launcher/System UI ANRs and launch wait timeout retained | api35-151-result.json; api35-151-login.png; api35-151-empty.png |
| New .151 APK on Android 8 | PASS for install/launch/baked host/empty form | api26-151-result.json; api26-151-login.png; api26-151-empty.png |
| End-to-end SIP credential consistency | FAIL | sip-auth-mismatch.json |
| Real devices, real audio, locked/cold-start push, mobile network changes | BLOCKED | No physical phones; no FCM/APNs credentials |
| Production signing and publication | BLOCKED | No employer release keystore; no publication performed |

## Actual defects fixed

- `smi` consumed the wrong number of arguments; server/extension dispatch failed. Single-level command options and `--json` forwarding are preserved.
- Build/deploy/release wrappers attempted to `cd` into common.sh and resolved the repository one directory too high.
- Android wrapper accepts a server host/port, validates input, builds a universal APK and verifies the output exists before reporting success.
- The Android call service now creates its required notification channel before posting a foreground notification (Android 8+). Native runtime validation remains separate.
- Server init reported success after Docker/Caddy validation failed. Server status reported PASS for unreachable health checks. Both now fail closed.
- The login expiration field was serialized as idleExpiresAtUtc, while the contract/client requires idleExpiresAt. The wire name is now explicit and tested.
- Flutter JSON requests lacked the JSON content type. Network requests now have a deadline; network/native-store failures end the login progress state without exposing raw exceptions.
- Android's JSON backlog did not match Dart's typed list; legacy nested events and expiry are replayed. Live Android events now use the EventChannel listened to by Dart.
- Asterisk Dockerfile had an invalid COPY, a nonexistent module path and called menuselect before building it. Runtime bind mounts hid required documentation; runtime directories/master config were missing. Packaged data is seeded without overwriting existing files.
- Container UID/GID mismatch prevented secret access. Runtime group IDs are explicit. Data and secret access were provisioned for the actual service account.
- Extension provisioning prefers the deployed container to avoid host/service SQLite ownership conflicts. Credential files are passed via private stdin rather than world-readable temporary copies.
- AMI Login was prohibited by the pre-login guard and the reader started after awaiting its response. The read loop now runs during authentication; the regression test uses a real loopback TCP listener and fragmented replies. The deployed service subsequently reached readiness 200 against real Asterisk.

## Important remaining defects and gates

**SIP credential mismatch is confirmed against the real PBX.** Provisioning generates an independent SipSecret, but the app configures SIP using the entered account password. A diagnostic REGISTER using the account password received 401; using the provisioned SIP credential received 200. No secret values were printed or saved in this report. Login API/model/secure-store credential handoff requires a coherent fix before claiming calls work. Do not resolve this by returning plaintext secrets in logs or disabling authentication.

Additional source review finds missing outgoing attemptId SIP headers, incomplete incoming INVITE/callId correlation, native call/audio operations that still return success without full implementation, and no Firebase push configuration. These are existing P2/P3 gaps, not validated features. Foreground calls, mute/speaker behavior and background/lock-screen calling are not accepted on the basis of opening the login screen.

The first Android 15 run was interrupted after boot. The final run completed the limited UI checks; startup timeout and emulator ANR limitations are explicitly preserved in api35-151-result.json. Existing r5 APK SHA-256 is `90837cd36eac97b7c0cb4046f85c05577ed7493708166c9e49024438c367e9c6` and it still contains .244. It must not be distributed as the new .151 build.

## Local configuration and operation

- NetworkManager profile: `mini-voip-lan`, static `192.168.1.151/24`, gateway `192.168.1.1`. The original `netplan-ens33` DHCP profile is retained. Rollback: `nmcli connection up netplan-ens33`; disable the new profile's autoconnect if reverting permanently. Router DHCP reservation/exclusion is not configured by this task.
- Toolchain environment: `/home/changer/.config/mini-voip-free/env.sh`, sourced from the user's `.bashrc`. Tools live under `/home/changer/.local/share/mini-voip-free/`.
- Docker access was added to the user's docker group; existing shells can run commands via `sg docker -c '...command...'` until a fresh login.
- Local config: `deploy/site.env`, `SMI_DOMAIN=192.168.1.151`, `SMI_TLS_MODE=internal`. `./smi server up` uses the LAN Compose override. The public TLS profile remains the default for public deployment.
- Public LAN root certificate: `lan-root-ca.crt` in this report directory. Its private key remains in Caddy's protected runtime storage. A test client must trust this CA; all hostname/IP and chain checks remain enabled. A user-installed Android CA is not automatically trusted by every native/Dart network stack; verify the actual app path before claiming connectivity.
- Extensions 101 and 102 were provisioned. Their account credential files are `deploy/secrets/local-101.credential` and `deploy/secrets/local-102.credential` (not in Git or logs). These account passwords currently do not authenticate SIP because of the confirmed defect above.
- Services bind AMI/API/PBX HTTP and ordinary SIP to loopback. Edge uses 80/443. This is a local LAN installation, not evidence of internet deployment or firewall acceptance.

## Sources, checksums and reproducibility

CFUG was used for Flutter/Dart artifacts and pub packages, TUNA for Java, Tencent for Android/Gradle, and Aliyun for Maven and configured Ubuntu packages. Some mirror probes failed and are retained in mirror-probes.json. Flutter source revision matches the locked release; the installed Flutter SDK's included Gradle build received local Aliyun repository declarations. Docker images and .NET used their original registries/downloads when available.

Gradle's distribution checksum was verified against the publisher. Android packages were checked against repository checksums. The JDK archive checksum was calculated and tar integrity checked; independent publisher checksum retrieval was HTTP 403, retained in jdk-install.json. NDK symlinks were initially extracted as files by the local installer; they were restored from the verified archive and clang execution was checked before retrying the build. No dependency downgrade/override was used to hide a conflict. `toolchain.lock.json` records newly discovered tool versions; this does not prove the complete combination is device-validated.

Failed, canceled and interrupted attempts are retained. The initial full test command was edited while running and had to be rerun; only completed passing runs are counted. Earlier build failures identify missing SDK components and mirror resolution failures, and do not count as release validation.

## Delivery labels

CodeReady: false for the complete product (individual suites pass).
DeviceValidated: false.
Deployed: local services running with readiness 200; end-to-end telephony acceptance is incomplete.
Published: false.

Next step: repair and test the SIP credential/correlation path; obtain real devices, push credentials and production signing for the remaining acceptance gates.

Resource note: Android 15 and Gradle running together approached the VM RAM/swap limit. The emulator was stopped to let the release build finish, and must be retried after compilation. Early install failures saying package/activity services were absent occurred before that boot completed and are not recorded as application crashes.


## Completed release artifact inspection

New local artifact: `artifacts/android/mini-voip-free-192.168.1.151-local.apk`.
SHA-256: `c3f923e63d8e5177b3c4e39f5860548b0f563f8ae89287c4e47533e61970e0a0`.
`apksigner verify` and ZIP integrity passed. Signer is Android Debug; this is not the employer production key. Min SDK 26, target/compile SDK 36. All three libapp.so variants contain .151 and do not contain .244. ARM32, ARM64 and x86_64 are included. Zipalign's 16 KiB check passed; all ARM64/x86_64 ELF LOAD segments have alignment at least 16 KiB. The ARM32 WebRTC binary has 4 KiB segments; that does not establish runtime support on hypothetical 16 KiB ARM32 systems. No 16 KiB device execution is claimed.

Live HTTPS API authentication was exercised with a temporary extension 199: wrong/unknown credentials 401 with identical generic code, valid credentials 200 with required fields, second installation 409, authenticated /me 200, logout 204, revoked token 401. The temporary account was disabled afterwards and PBX reloaded. See live-api-auth.json, qa-account-create.log and qa-account-disable.log; tokens/passwords were not recorded.


Android 15 UI follow-up: after the emulator's Quickstep/System UI dialogs were dismissed/waited, the .151 login screen rendered and empty credentials were rejected. The smoke driver's completed result was PASS for those limited checks, after 474 seconds including software boot and UI recovery. The initial Activity wait still timed out; see api35-151-result.json limitations and retained diagnostic screenshots. No startup-time acceptance is claimed.

Desktop launchers for Android 8 and 15 were installed in the user's Desktop; they run `/home/changer/.local/bin/mini-voip-emulator` using the installed AVDs. The Android 8 emulator is opened with a visible window for the final run. Only one emulator at a time is advisable on this VM. The helper does not remove or reset app data.


## Final emulator and service state

The **same final .151 APK** passed install and limited login-form smoke on API 26 and API 35. Android 8's final Activity start returned Status: ok (2.626 seconds); the complete software-boot/install/UI smoke took 113 seconds. The older r5 debug-signed fixture was uninstalled only after Android rejected the different debug signer; this was a disposable emulator install with no real account data. Android 15's eventual UI passed with its explicitly documented system-dialog/startup limitations. The Android 8 emulator window is left open. Neither result proves real audio, successful SIP registration/calls, notification delivery, cold start or OS-lock behavior.

The final server remains running at .151 with live/ready 200. Only extensions 101/102 remain enabled; temporary QA extension 199 was disabled. Actual base-image digests used during successful Docker builds were subsequently pinned in the source; Compose configuration validation passed. See changed-tracked-files.txt for modified tracked files, generated Android platform/lockfiles and new tests in the repository, plus the environment/desktop installation paths described above.
