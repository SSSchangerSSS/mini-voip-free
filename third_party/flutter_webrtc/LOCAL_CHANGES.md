# Local compatibility changes

Upstream flutter_webrtc 1.6.3, downloaded from pub.flutter-io.cn. LICENSE and NOTICE preserved. Public package version remains 1.6.3; this is an explicit path override, not an unmodified hosted package.

Only android/build.gradle and MethodCallHandlerImpl.java differ from the copied upstream source. Android SDK pin: 144.7559.15. Reject unsupported enableWARP/enableSctpSnap=true instead of accessing the absent SDK field. Defaults/false remain supported. Disable internal tracing. See patches/webrtc/flutter-webrtc-1.6.3-sdk144.patch and upstream file hashes; decision0015 contains runtime acceptance results. No data channel/SNAP feature is used by the product.
