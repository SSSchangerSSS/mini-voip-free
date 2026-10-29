# Reduce Android15 QA emulator scheduling pressure

Date: 2026-10-29

Scope is the existing Ubuntu/VMware QA environment, Android8/API26 and Android15/API35 only. No Android image, SDK, library, application protocol or APK upgrade. Physical-device/push gates remain blocked.

Observed baseline: no KVM/vmx/svm, four host vCPUs and7.2GiB RAM. API35 physically rendered720x1280 despite a480x800 guest override. While scrcpy was open, guest media.swcodec dominated CPU; a12second A/B sample measured API35 host process107.91% CPU with the mirror versus34.08% without it. Native Qt/XCB avoids guest video encoding. Host EGL reports VMware SVGA3D; explicit host GLES rendered the guest but the emulator logs a GPU compatibility warning, so it requires actual visual/call/boot validation. Vulkan is disabled in this QA profile; guest watchdogs and ANR dialogs stay enabled.

The first native-display/480x800 cold boot still produced SystemUI/Quickstep and other startup ANRs. It is retained as FAIL. Historical SystemUI/Quickstep main-thread traces showed substantial runnable/scheduling waits. Both packages used ART verify-only artifacts. Prepare only these two packages with cmd package compile -m speed, serially; verify actual pm art dump status=speed. Do not trust command exit0 alone: a cancelled compile printed Failure with exit0 in the draft worker. Retain that failed experiment; the validated helper checks both Success and actual compiled artifacts and rejects another active compiler.

Use actual480x800/density160 in the AVD profile, native Qt/XCB, explicit2560MB for API35, no audio/snapshots and the existing version. Serialise cold startups with a host-local flock; release it after launch, so both resident emulators can make a call. Each engine owns a process group. After that engine exits, reap only leftover QEMU processes in its group, since a shutdown helper was observed using~100% CPU with one thread and no open guest handles. Never kill another AVD or disable SystemUI/Quickstep/ANR detection to obtain green results.

AOT cache and AVD settings are environment tuning, not evidence that the application works on physical devices. Final renderer choice and repeated cold-boot/UI/call outcomes are recorded in qa/reports/2026-10-29-emulator-stability/REPORT.fa.md, including unsuccessful trials and rollback instructions.

References: https://developer.android.com/studio/run/emulator-acceleration ; https://source.android.com/docs/core/runtime/configure ; https://source.android.com/docs/core/runtime/configure/art-service ; https://android.googlesource.com/platform/art/+/main/libartservice/service/README.md .

Experimental host GPU was rejected: it still produced startup ANRs and incomplete application rendering. The next profile uses supported swiftshader (not deprecated swiftshader_indirect), Vulkan off and one guest CPU core, since emulator -help-cores states additional guest cores benefit accelerated CPU emulation; repeated real tests decide whether this profile is retained.
