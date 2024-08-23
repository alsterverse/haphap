import Flutter
import UIKit
import AVFoundation
import CoreHaptics

public class HaphapPlugin: NSObject, FlutterPlugin {

    private let hapticManager: HapticManager

    init(hapticManager: HapticManager = HapticManager()) {
        self.hapticManager = hapticManager

        do {
            try hapticManager.createEngine()
            hapticManager.addObservers()
        } catch let error {
            print("[haphap] Engine Creation Error: \(error)")
        }
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
            break
        case "stop":
            try? hapticManager.stopAllPlayers()
            break
        case "goToIdle":
            hapticManager.goToIdle()
            break
        case "runRampUp":
            if (hapticManager.engineNeedsStart) {
                hapticManager.resetAndStart()
            }
            hapticManager.rampUp()
            break
        case "updateSettings":
            if let args = call.arguments as? Dictionary<String, Any>,
               let releaseDuration = args["releaseDurationInMilliseconds"] as? Double,
               let revolutions = args["revolutions"] as? Double,
               let useExponentialCurve = args["useExponentialCurve"] as? Bool
            {
                hapticManager.updateSettings(
                    releaseDuration: releaseDuration / 1000.0,
                    revolutions: revolutions,
                    useExponentialCurve: useExponentialCurve
                )
            } else {
                result(FlutterError.init(code: "bad args", message: nil, details: nil))
            }
            break
        case "runRelease":
            if let args = call.arguments as? Dictionary<String, Any>,
               let power = args["power"] as? Double {
                if (hapticManager.engineNeedsStart) {
                    hapticManager.resetAndStart()
                }
                hapticManager.release(power: power)
            } else {
                result(FlutterError.init(code: "bad args", message: nil, details: nil))
            }
            break
        case "runPattern":
            if let args = call.arguments as? Dictionary<String, Any>,
               let data = args["data"] as? String {
                if (hapticManager.engineNeedsStart) {
                    hapticManager.resetAndStart()
                }
                hapticManager.playHapticsData(named: data)
            } else {
                result(FlutterError.init(code: "bad args", message: nil, details: nil))
            }
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class HapticManager: NSObject {

    // A haptic engine manages the connection to the haptic server.
    private var engine: CHHapticEngine!
    private var rampUpPlayer: CHHapticAdvancedPatternPlayer?
    private var releasePlayer: CHHapticAdvancedPatternPlayer?

    // Tokens to track whether app is in the foreground or the background:
    private var foregroundToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?

    private var hapticDispatchWorkItem: DispatchWorkItem?

    var engineNeedsStart = true
    var manuallyPrepared = false

    // Maintain a variable to check for Core Haptics compatibility on device.
    lazy var supportsHaptics: Bool = {
        let hapticCapability = CHHapticEngine.capabilitiesForHardware()
        return hapticCapability.supportsHaptics
    }()

    private var releaseDuration: TimeInterval = 4.0
    private var revolutions: Double = 4.0
    private var useExponentialCurve: Bool = false
    private let rampDuration: TimeInterval = 4.0
    private let steadyDuration: TimeInterval = 30.0

    enum HaphapError: Error {
        case noEngine
    }

    /// - Tag: CreateEngine
    func createEngine() throws {
        guard engineNeedsStart else { return }

        engine = try CHHapticEngine()

        guard let engine = engine else {
            throw HaphapError.noEngine
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

    func updateSettings(
        releaseDuration: TimeInterval,
        revolutions: Double,
        useExponentialCurve: Bool
    ) {
        self.releaseDuration = releaseDuration
        self.revolutions = revolutions
        self.useExponentialCurve = useExponentialCurve
        engineNeedsStart = true
    }

    func prepare() {
        manuallyPrepared = true
        resetAndStart()
    }

    func goToIdle() {
        guard supportsHaptics else { return }
        try? stopAllPlayers()
        engineNeedsStart = true
        manuallyPrepared = false
        engine?.stop()
    }

    func resetAndStart() {
        guard supportsHaptics else { return }
        print("[haphap] The engine reset --> Restarting now!")
        do {
            // Try restarting the engine.
            try engine.start()

            // Indicate that the next time the app requires a haptic, the app doesn't need to call engine.start().
            engineNeedsStart = false

            // Recreate the players.
            createRampUpHapticPlayer()
            createReleaseHapticPlayer()
        } catch {
            print("[haphap] Failed to restart the engine: \(error)")
        }
    }

    func stopAllPlayers() throws {
        hapticDispatchWorkItem?.cancel()
        try rampUpPlayer?.stop(atTime: CHHapticTimeImmediate)
        try releasePlayer?.stop(atTime: CHHapticTimeImmediate)
    }

    func rampUp() {
        guard supportsHaptics else { return }
        print("[haphap] try run ramp up")
        if engineNeedsStart { prepare() }

        do {
            try stopAllPlayers()
            rampUpPlayer?.isMuted = false
            releasePlayer?.isMuted = true

            hapticDispatchWorkItem?.cancel()
            hapticDispatchWorkItem = DispatchWorkItem(block: { [weak self] in
                do {
                    try self?.rampUpPlayer?.start(atTime: CHHapticTimeImmediate)
                } catch {
                    print("[haphap] Failed to start \(#function): \(error)")
                }
            })

            DispatchQueue.main.asyncAfter(
                deadline: DispatchTime.now().advanced(by: DispatchTimeInterval.milliseconds(50)),
                execute: hapticDispatchWorkItem!
            )
        } catch {
            print("[haphap] Failed to stop \(#function): \(error)")
        }
    }

    func release(power: Double) {
        guard supportsHaptics else { return }
        print("[haphap] try run release at \(power)")
        if engineNeedsStart { prepare() }
        do {
            try stopAllPlayers()
            rampUpPlayer?.isMuted = true
            releasePlayer?.isMuted = false

            hapticDispatchWorkItem?.cancel()
            hapticDispatchWorkItem = DispatchWorkItem(block: { [weak self] in
                do {
                    let offset = (1.0 - power) * (self?.releaseDuration ?? 0.0)
                    try self?.releasePlayer?.seek(toOffset: offset)
                    try self?.releasePlayer?.start(atTime: CHHapticTimeImmediate)
                } catch {
                    print("[haphap] Failed to start \(#function): \(error)")
                }
            })

            DispatchQueue.main.asyncAfter(
                deadline: DispatchTime.now().advanced(by: DispatchTimeInterval.milliseconds(50)),
                execute: hapticDispatchWorkItem!
            )
        } catch {
            print("[haphap] Failed to \(#function): \(error)")
        }
    }

    private func createReleaseCurveControlPoints(duration: TimeInterval, revolutions: Double) -> [CHHapticParameterCurve.ControlPoint] {
        var controlpoints = [CHHapticParameterCurve.ControlPoint]()

        let pointsPerSecond = 6.0
        let pointCount: Int = Int(pointsPerSecond * duration)
        let delta: Double = 1 / pointsPerSecond
        var currentValue: Double = 0.0
        let targetValue: Double = 1.0
        (0...pointCount - 1).enumerated().forEach { index, _ in
            let percent: Double = Double(index) / Double(pointCount)
            currentValue += (targetValue - currentValue) * delta
            let x: Float = Float((useExponentialCurve ? currentValue : percent) * Double.pi * 2 * revolutions)
            let y: Float = cos(x) * 0.5 + 0.5
            let falloffY: Float = y * Float(1 - percent)
            // print("cosCurve \(String(format: "%.3f", y)) \t\t falloff \(falloffY) \t \(currentValue) \t \(Float(percent))")
            controlpoints.append(.init(relativeTime: percent * duration, value: falloffY))
        }

        return controlpoints
    }

    private func createEscalatingTaps(_ startTime: Double, parameters: [CHHapticEventParameter]) -> [CHHapticEvent] {

        let durationPerEvent = 0.0
        let eventsCount = 60
        var events = [CHHapticEvent]()
        var accumulatedDelay = 0.0
        (0...eventsCount - 1).enumerated().forEach { index, _ in
            let relativeTime = startTime + durationPerEvent * Double(index) + accumulatedDelay
            let delay: Double = 0.07 * (1 - (Double(index) / Double(eventsCount))) + 0.05
            accumulatedDelay += delay
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: relativeTime, duration: durationPerEvent))
        }
        return events
    }

    let maxParameters = [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
    ]

    let sharpParameters = [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
    ]

    /// - Tag: CreateContinuousPattern
    func createRampUpHapticPlayer() {
        var events = [CHHapticEvent]()

        events.append(contentsOf: createEscalatingTaps(0.0, parameters: maxParameters))

        let initialIntensity: Float = 0.5
        let initialSharpness: Float = 0.0
        // Create an intensity parameter:
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity,
                                               value: initialIntensity)

        // Create a sharpness parameter:
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness,
                                               value: initialSharpness)

        // Create a continuous event with a long duration from the parameters.
        let continuousRampEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: rampDuration
        )


        events.append(continuousRampEvent)

        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: rampDuration,
            duration: steadyDuration
        )

        events.append(continuousEvent)

        do {
            // Create a pattern from the continuous haptic event.
            let curves = [CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [.init(relativeTime: 0.0, value: 0.2), .init(relativeTime: rampDuration, value: 1.0)], relativeTime: 0)]
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)

            rampUpPlayer = try engine.makeAdvancedPlayer(with: pattern)

        } catch let error {
            print("[haphap] Pattern Player Creation Error: \(error)")
        }
    }

    /// - Tag: CreateContinuousPattern
    func createReleaseHapticPlayer() {
        let sharpHit = CHHapticEvent(eventType: .hapticTransient, parameters: sharpParameters, relativeTime: 0.0)

        let continuousEvent = CHHapticEvent(eventType: .hapticContinuous,
                                            parameters: maxParameters,
                                            relativeTime: 0,
                                            duration: releaseDuration)

        do {
            let sineCurve = CHHapticParameterCurve.init(
                parameterID: .hapticIntensityControl,
                controlPoints: createReleaseCurveControlPoints(duration: releaseDuration, revolutions: revolutions),
                relativeTime: 0.0
            )

            let pattern = try CHHapticPattern(events: [sharpHit, continuousEvent], parameterCurves: [sineCurve])

            // Create a player from the continuous haptic pattern.
            releasePlayer = try engine.makeAdvancedPlayer(with: pattern)
        } catch let error {
            print("Pattern Player Creation Error: \(error)")
        }
    }

    func playHapticsData(named data: String) {

        // If the device doesn't support Core Haptics, abort.
        guard supportsHaptics else { return }

        do {
            // Start the engine in case it's idle.
            if (engineNeedsStart) {
                resetAndStart()
            }

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
            guard self.supportsHaptics && self.manuallyPrepared else {
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
