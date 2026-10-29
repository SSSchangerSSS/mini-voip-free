# Foreground SIP hint and explicit LAN CA

Date: 2026-10-28

Fix foreground incoming-call discovery without adding an idle HTTP poll, a service or an API endpoint. On admission send a fixed `MessageSend` action to `pjsip:<validated callee>` with body `smi-call` and From `sip:smi@localhost`. The out-of-dialog SIP MESSAGE contains no credential, caller identity or call state. A client receiving the hint fetches its authenticated current call and still must pass the original ready gate. APNs/FCM remain required for suspended/background clients and are not replaced by this hint. This adds exactly MessageSend to the AMI action allowlist for this fixed purpose; it requires the message write class. No URI/Variable/command action is exposed to public API inputs. Existing SMI variables/events and call admission rules stay fixed.

Correct WaitForCondition to its documented replacement-character syntax, verified from the actual installed Asterisk 22.11.0 help/source. Use the authenticated CHANNEL(endpoint) identity, preserve the server ready/deadline gate, and re-evaluate the remaining deadline before Dial.

For this employer-owned private-IP LAN installation, opt-in `--trusted-ca-file` installs a specific public CA in Dart's default security context before HTTPS/WSS is created. Default builds add no CA. Neither invalid chain nor hostname/IP verification is bypassed, and allowBadCertificate stays false. This is a deliberate local trust anchor, not a trust-all exception. Public deployment still requires the specified public-domain/certificate setup. Record actual certificate, build and negative TLS checks; keep private keys outside source/logs.

Live investigation: sip_ua 1.1.0 emits unsolicited NOTIFY as internal EventSipEvent but exposes onNewNotify only for subscribed dialogs. Therefore the original NOTIFY attempt did not reach the public helper callback (third-call evidence); the supported public onNewMessage callback handles the fixed control hint. This is not a chat feature. AMI Login and account read privileges must also include user, otherwise SMICallRequested is filtered.
