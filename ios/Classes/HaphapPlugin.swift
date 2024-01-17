import Flutter
import UIKit
import AVFoundation
import CoreHaptics

public class HaphapPlugin: NSObject, FlutterPlugin {

    var hapticManager = HapticManager()

    init(hapticManager: HapticManager = HapticManager()) {
        self.hapticManager = hapticManager

        hapticManager.createEngine()
        hapticManager.addObservers()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "haphap", binaryMessenger: registrar.messenger())
        let instance = HaphapPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "prepare":
            hapticManager.resetAndStart()
        case "runRampUp":
            hapticManager.rampUp()
        case "runContinuous":
            hapticManager.continuous()
        case "runRelease":
            if let args = call.arguments as? Dictionary<String, Any>,
               let power = args["power"] as? Double {
                hapticManager.release(power: power)
            } else {
                result(FlutterError.init(code: "bad args", message: nil, details: nil))
            }
        case "runPattern":
            if let args = call.arguments as? Dictionary<String, Any>,
               let data = args["data"] as? String {

                if (hapticManager.engineNeedsStart) {
                    hapticManager.resetAndStart()
                }

                hapticManager.playHapticsFile(named: data)
            } else {
                result(FlutterError.init(code: "bad args", message: nil, details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class HapticManager: NSObject {

    // A haptic engine manages the connection to the haptic server.
    private var engine: CHHapticEngine!
    var engineNeedsStart = true
    private var rampUpPlayer: CHHapticAdvancedPatternPlayer!
    private var continuousPlayer: CHHapticAdvancedPatternPlayer!
    private var releasePlayer: CHHapticAdvancedPatternPlayer!

    // Tokens to track whether app is in the foreground or the background:
    private var foregroundToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?

    // Maintain a variable to check for Core Haptics compatibility on device.
    lazy var supportsHaptics: Bool = {
        let hapticCapability = CHHapticEngine.capabilitiesForHardware()
        return hapticCapability.supportsHaptics
    }()

    let fullReleaseDuration: TimeInterval = 4.0

    /// - Tag: CreateEngine
    func createEngine() {
        // Create and configure a haptic engine.
        do {
            // Associate the haptic engine with the default audio session
            // to ensure the correct behavior when playing audio-based haptics.
            engine = try CHHapticEngine()
        } catch let error {
            print("[haphap] Engine Creation Error: \(error)")
        }

        guard let engine = engine else {
            print("[haphap] Failed to create engine!")
            return
        }

        // Mute audio to reduce latency for collision haptics.
        engine.playsHapticsOnly = true

        // The stopped handler alerts you of engine stoppage due to external causes.
        engine.stoppedHandler = { reason in
            print("[haphap] The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt:
                print("[haphap] Audio session interrupt")
            case .applicationSuspended:
                print("[haphap] Application suspended")
            case .idleTimeout:
                print("[haphap] Idle timeout")
            case .systemError:
                print("[haphap] System error")
            case .notifyWhenFinished:
                print("[haphap] Playback finished")
            case .gameControllerDisconnect:
                print("[haphap] Controller disconnected.")
            case .engineDestroyed:
                print("[haphap] Engine destroyed.")
            @unknown default:
                print("[haphap] Unknown error")
            }
        }

        // The reset handler provides an opportunity for your app to restart the engine in case of failure.
        engine.resetHandler = resetAndStart
    }

    func resetAndStart() {
        print("[haphap] The engine reset --> Restarting now!")
        do {
            // Try restarting the engine.
            try self.engine.start()

            // Indicate that the next time the app requires a haptic, the app doesn't need to call engine.start().
            self.engineNeedsStart = false

            // Recreate the continuous player.
            self.createContinuousHapticPlayer()
            self.createRampUpHapticPlayer()
            self.createReleaseHapticPlayer()
        } catch {
            print("[haphap] Failed to restart the engine: \(error)")
        }
    }

    func stopAllPlayers() throws {
        try rampUpPlayer.stop(atTime: CHHapticTimeImmediate)
        try continuousPlayer.stop(atTime: CHHapticTimeImmediate)
        try releasePlayer.stop(atTime: CHHapticTimeImmediate)
    }

    func rampUp() {
        print("[haphap] try run ramp up")
        guard !engineNeedsStart else { return }

        do {

            try stopAllPlayers()
            try rampUpPlayer.seek(toOffset: 0.0)
            try rampUpPlayer.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[haphap] Failed to \(#function): \(error)")
        }
    }

    func continuous() {
        print("[haphap] try run contin")
        guard !engineNeedsStart else { return }
        do {
            //try stopAllPlayers()
            try continuousPlayer.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[haphap] Failed to \(#function): \(error)")
        }
    }

    func release(power: Double) {
        print("[haphap] try run release at \(power)")
        guard !engineNeedsStart else { return }
        do {
            try stopAllPlayers()

//            let intensityParameter = CHHapticDynamicParameter(parameterID: .hapticIntensityControl,
//                                                              value: Float(power),
//                                                              relativeTime: 0)

//            try releasePlayer.sendParameters([intensityParameter],
//                                                atTime: 0)

//            try releasePlayer.scheduleParameterCurve(.init(parameterID: .hapticIntensityControl, controlPoints: createSineCurveControlPoints(duration: 3.0), relativeTime: 0.0), atTime: 0.0)
            //try releasePlayer.cancel()
            let ba = (1.0 - power) * fullReleaseDuration
            print("start at \(ba)")
            try releasePlayer.seek(toOffset: ba)
            try releasePlayer.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[haphap] Failed to \(#function): \(error)")
        }
    }

    private func createSineCurveControlPoints(duration: TimeInterval) -> [CHHapticParameterCurve.ControlPoint] {
//        var controlpoints = [CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0.0, value: 0.0), .init(relativeTime: 10.0, value: 1.0)], relativeTime: 0)]
        var controlpoints = [CHHapticParameterCurve.ControlPoint]()

        // Could also be called resolution or pointDensity
        let frameRate = 6.0
        let resolution: Int = Int(frameRate * duration)
        let frameDelta: Double = 1 / frameRate
        var uForce: Double = 1.0
        let target: Double = 0.0
        (0...resolution - 1).enumerated().forEach { index, _ in
            let normalizedPct: Double = Double(index) / Double(resolution)
            let floatedX = Float(normalizedPct)
            uForce += (target - uForce) * frameDelta
            let x: Float = 0.5 * 5.0 + Float(uForce * Double.pi * 2 * 4.0)
            let y: Float = (sin(x) * 0.4 + 0.6) * (1.0 - floatedX)
            print("power \(y) \t \(uForce) \t \( 1.0 - floatedX)")
//
//            // Invertera "avståndet" så den börjar snabbt och avtar
//
            //let relativeTime = startTime + ((duration + delay) * Double(index))
            controlpoints.append(.init(relativeTime: normalizedPct * duration, value: y))
        }

        return controlpoints
    }

    private func createSection(_ startTime: Double, parameters: [CHHapticEventParameter]) -> [CHHapticEvent] {
        let delay = 0.05
        let duration = 0.1
        let eventsCount = 28
        var events = [CHHapticEvent]()
        (0...eventsCount - 1).enumerated().forEach { index, _ in
            let relativeTime = startTime + ((duration + delay) * Double(index))
            events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: relativeTime, duration: duration))
        }
        return events
    }

    private func createEscalatingTaps(_ startTime: Double, parameters: [CHHapticEventParameter]) -> [CHHapticEvent] {

        let duration = 0.0
        let eventsCount = 60
        var events = [CHHapticEvent]()
        var accDelay = 0.0
        (0...eventsCount - 1).enumerated().forEach { index, _ in
            let delay: Double = 0.07 * (1 - (Double(index) / Double(eventsCount))) + 0.01
            accDelay += delay
            let relativeTime = startTime + duration * Double(index) + accDelay
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: relativeTime, duration: duration))
        }
        return events
    }

    let kickParams = [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
    ]
    let rhythmParams = [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
    ]
    let maxParams = [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
    ]

    /// - Tag: CreateContinuousPattern
    func createRampUpHapticPlayer() {
        var events = [CHHapticEvent]()

//        events.append(contentsOf: createSection(0.2, parameters: rhythmParams))
//        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: kickParams, relativeTime: 4.4, duration: 0.3))
//        events.append(contentsOf: createSection(4.4, parameters: rhythmParams))
//        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: kickParams, relativeTime: 8.8, duration: 0.3))

        events.append(contentsOf: createEscalatingTaps(0.0, parameters: maxParams))


        let initialIntensity: Float = 0.5
        let initialSharpness: Float = 0.0
        // Create an intensity parameter:
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: initialIntensity)

        // Create a sharpness parameter:
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: initialSharpness)
        let rampDur: TimeInterval = 4.0
        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent(eventType: .hapticContinuous,
                                            parameters: [intensity, sharpness],
                                            relativeTime: 0,
                                            duration: rampDur)


        events.append(continuousEvent)

        do {
            // Create a pattern from the continuous haptic event.
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let curves = [CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0.0, value: 0.2), .init(relativeTime: rampDur, value: 1.0)], relativeTime: 0)]
            let patt2 = try CHHapticPattern(events: events, parameterCurves: curves)

            // Create a player from the continuous haptic pattern.
            rampUpPlayer = try engine.makeAdvancedPlayer(with: patt2)
            rampUpPlayer.completionHandler = {  [weak self] _ in self?.continuous() }

        } catch let error {
            print("Pattern Player Creation Error: \(error)")
        }
    }

    /// - Tag: CreateContinuousPattern
    func createContinuousHapticPlayer() {
        let initialIntensity: Float = 0.75
        let initialSharpness: Float = 0.25
        // Create an intensity parameter:
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: initialIntensity)

        // Create a sharpness parameter:
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: initialSharpness)

        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent(eventType: .hapticContinuous,
                                            parameters: [intensity, sharpness],
                                            relativeTime: 0,
                                            duration: 3)

        do {
            // Create a pattern from the continuous haptic event.
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])

            // Create a player from the continuous haptic pattern.
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            continuousPlayer.loopEnabled = true
            continuousPlayer.completionHandler = { _ in }

        } catch let error {
            print("Pattern Player Creation Error: \(error)")
        }


    }

    /// - Tag: CreateContinuousPattern
    func createReleaseHapticPlayer() {
        let initialIntensity: Float = 1.0
        let initialSharpness: Float = 0.5
        // Create an intensity parameter:
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: initialIntensity)

        // Create a sharpness parameter:
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: initialSharpness)

        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent(eventType: .hapticContinuous,
                                            parameters: [intensity, sharpness],
                                            relativeTime: 0,
                                            duration: fullReleaseDuration)

        do {
            // Create a pattern from the continuous haptic event.
            
//            let curves = [CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0.0, value: 1.0), .init(relativeTime: 3.0, value: 0.0)], relativeTime: 0)]

            let sineCurve = CHHapticParameterCurve.init(parameterID: .hapticIntensityControl, controlPoints: createSineCurveControlPoints(duration: fullReleaseDuration), relativeTime: 0.0)


            let pattern = try CHHapticPattern(events: [continuousEvent], parameterCurves: [sineCurve])

            // Create a player from the continuous haptic pattern.
            releasePlayer = try engine.makeAdvancedPlayer(with: pattern)
            releasePlayer.completionHandler = { _ in }

        } catch let error {
            print("Pattern Player Creation Error: \(error)")
        }


    }

    enum HapError: Error {
        case noSupport
        case noFile
        case notiOS16
        case noEngine
    }

    /// - Tag: CreateContinuousPattern
    func createContinuousHapticPlayer2(named filename: String) throws -> CHHapticAdvancedPatternPlayer {
        // TODO: Create 2 (3? continuous) advanced players: 1 for ramp up and 1 for release. Use 2 patterns. Use sendParameters on releasePlayer to set intensity.

        // If the device doesn't support Core Haptics, abort.
        if !supportsHaptics {
            throw HapError.noSupport
        }

        // Express the path to the AHAP file before attempting to load it.
        guard let path = Bundle.main.path(forResource: filename, ofType: "ahap") else {
            throw HapError.noFile
        }

        guard let engine else {
            throw HapError.noEngine
        }

        if #available(iOS 16.0, *) {
            //CHHapticPattern(dictionary: <#T##[CHHapticPattern.Key : Any]#>)
            let pattern = try CHHapticPattern(contentsOf: URL(fileURLWithPath: path))
            // Create a player from the continuous haptic pattern.
            let continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            continuousPlayer.completionHandler = { _ in }

            return continuousPlayer
        } else {
            throw HapError.notiOS16
            // Fallback on earlier versions
        }
    }

    /// - Tag: PlayAHAP
    func playHapticsFile(named data: String) {

        // If the device doesn't support Core Haptics, abort.
        if !supportsHaptics {
            return
        }

        // Express the path to the AHAP file before attempting to load it.
        //        guard let path = Bundle.main.path(forResource: filename, ofType: "ahap") else {
        //            return
        //        }

        do {
            // Start the engine in case it's idle.
            try engine.start()

            // Tell the engine to play a pattern.
            try engine.playPattern(from: Data(data.utf8))

        } catch { // Engine startup errors
            print("An error occured playing \(data): \(error).")
        }
    }

    func addObservers() {
        backgroundToken = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                                 object: nil,
                                                                 queue: nil)
        { _ in
            guard self.supportsHaptics else {
                return
            }
            // Stop the haptic engine.
            self.engine.stop(completionHandler: { error in
                if let error = error {
                    print("Haptic Engine Shutdown Error: \(error)")
                    return
                }
                self.engineNeedsStart = true
            })
        }
        foregroundToken = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                                                 object: nil,
                                                                 queue: nil)
        { _ in
            guard self.supportsHaptics else {
                return
            }
            // Restart the haptic engine.
            self.engine.start(completionHandler: { error in
                if let error = error {
                    print("Haptic Engine Startup Error: \(error)")
                    return
                }
                self.engineNeedsStart = false
            })
        }
    }

}
