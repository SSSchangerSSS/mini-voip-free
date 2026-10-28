import Flutter
import UIKit
import PushKit
import CallKit

/// iOS app entry (spec 9.3): PushKit registration happens in the native start
/// path; the VoIP push handler reports the call to CallKit IMMEDIATELY — network
/// requests, REGISTER or Dart startup are never preconditions for reportNewIncomingCall.
@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let provider = SmiCallProvider.shared
        provider.attach(flutterEngine: (self as FlutterAppLifeCycleProvider).flutterEngine)
        provider.registerForVoIPPushes()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
