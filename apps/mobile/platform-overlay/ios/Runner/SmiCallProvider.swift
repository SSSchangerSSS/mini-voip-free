import Foundation
import PushKit
import CallKit
import Flutter

/// PushKit + CallKit adapter (spec 9.3, [S09][S10]).
/// - exactly ONE CXProvider and ONE call slot;
/// - no video/group/hold in the raw configuration;
/// - incoming native UUID == server callId; outgoing native UUID == attemptId,
///   fixed for the whole call lifetime;
/// - completion callback runs exactly once per push, per Apple contract;
/// - answering never starts audio before the user action, and a fulfilled answer
///   action is NOT treated as server Connected.
final class SmiCallProvider: NSObject, CXProviderDelegate, PKPushRegistryDelegate {

    static let shared = SmiCallProvider()

    private let provider: CXProvider
    private let callController = CXCallController()
    private let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)

    private var flutterChannel: FlutterMethodChannel?
    private var answeredCallIds = Set<UUID>()

    private override init() {
        let configuration = CXProviderConfiguration(localizedName: "Mini VoIP Free")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = false
        configuration.includesCallsInRecents = false
        configuration.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: DispatchQueue.main)
    }

    func attach(flutterEngine: FlutterEngine) {
        flutterChannel = FlutterMethodChannel(
            name: "smi.phone/native/v1",
            binaryMessenger: flutterEngine.binaryMessenger
        )
        flutterChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    // MARK: - PushKit

    func registerForVoIPPushes() {
        voipRegistry.delegate = self
        voipRegistry.setDesiredPushTypes([.voIP])
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials,
                      for type: PKPushType) {
        guard type == .voIP else { return }
        let token = credentials.token.map { String(format: "%02x", $0) }.joined()
        notifyDart(type: "pushTokenChanged", payload: ["pushToken": token])
        pendingToken = token
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        pendingToken = nil
        notifyDart(type: "pushTokenChanged", payload: ["pushToken": NSNull()])
    }

    private var pendingToken: String?

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }
        defer { completion() } // exactly once, immediately (spec 9.3)

        let info = payload.dictionaryPayload
        guard
            let callIdString = info["callId"] as? String,
            let callId = UUID(uuidString: callIdString),
            let caller = info["callerExtension"] as? String
        else { return } // malformed push: never crash, never report a fake call

        let expiresAt = (info["expiresAt"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        if let expiresAt, expiresAt < Date() {
            return // expired payload — MUST NOT surface as an incoming call (spec 5.4)
        }

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.hasVideo = false
        update.supportsGrouping = false
        update.supportsHolding = false

        // Report FIRST, everything else later (spec 9.3).
        provider.reportNewIncomingCall(with: callId, update: update) { [weak self] error in
            if error == nil {
                self?.enqueuePending(eventId: "inc-\(callId.uuidString)", type: "incomingReported",
                                     payload: ["callId": callIdString, "callerExtension": caller])
            }
        }
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        answeredCallIds.removeAll()
        notifyDart(type: "nativeCallReset", payload: [:])
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let uuid = action.callUUID, !answeredCallIds.contains(uuid) else {
            action.fail()
            return
        }
        answeredCallIds.insert(uuid)
        enqueuePending(eventId: "ans-\(uuid.uuidString)", type: "answerRequested",
                       payload: ["callId": uuid.uuidString])
        // The answer INTENT is registered; SIP answering + audio start happen in Dart
        // after the intent reaches the controller (spec 5.2 step 14).
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if let uuid = action.callUUID {
            enqueuePending(eventId: "end-\(uuid.uuidString)", type: "endRequested",
                           payload: ["callId": uuid.uuidString, "reason": "declined"])
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        notifyDart(type: "audioActivated", payload: [:])
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        notifyDart(type: "audioDeactivated", payload: [:])
    }

    // MARK: - Flutter bridge (smi.phone/native/v1)

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure", "updateCallState", "setMuted", "setSpeaker", "reportOutgoing":
            result(nil)
        case "getCapabilities":
            result(["platform": "ios", "microphone": true, "voipPush": true,
                    "callstyle": false, "notifications": true])
        case "getPushToken":
            result(pendingToken)
        case "getPendingEvents":
            result(Self.pendingQueue.map { $0.1 })
        case "ackEvent":
            if let args = call.arguments as? [String: Any],
               let eventId = args["eventId"] as? String {
                Self.pendingQueue.removeAll { $0.0 == eventId }
            }
            result(nil)
        case "endCall":
            if let args = call.arguments as? [String: Any],
               let id = args["nativeCallUuid"] as? String,
               let uuid = UUID(uuidString: id) {
                callController.requestTransaction(CXEndCallAction(call: uuid)) { _ in }
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - native pending queue (spec 10.1: bounded, ack-driven, no secrets)

    static var pendingQueue: [(String, [String: Any])] = []

    private func enqueuePending(eventId: String, type: String, payload: [String: Any]) {
        var event = payload
        event["eventId"] = eventId
        event["type"] = type
        if Self.pendingQueue.contains(where: { $0.0 == eventId }) { return }
        Self.pendingQueue.append((eventId, event))
        if Self.pendingQueue.count > 64 { Self.pendingQueue.removeFirst() }
        notifyDart(type: type, payload: event)
    }

    private func notifyDart(type: String, payload: [String: Any]) {
        var event = payload
        event["eventId"] = event["eventId"] ?? "evt-\(UUID().uuidString)"
        event["type"] = type
        flutterChannel?.invokeMethod("nativeEvent", arguments: event)
    }
}

import AVFoundation
