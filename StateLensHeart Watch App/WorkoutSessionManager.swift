import Combine
import Foundation
import SwiftUI
#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class WorkoutSessionManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatusText = "Not requested"
    @Published private(set) var isRunning = false
    @Published private(set) var currentHeartRate: Double?
    @Published private(set) var currentEstimation: StateEstimation?
    @Published private(set) var latestMotionScore: Double = 0
    @Published private(set) var latestErrorMessage: String?
    @Published private(set) var inputModeText = "Live"
    @Published private(set) var latestSignalConfidence: Double?
    @Published private(set) var latestSampleCount = 0
    @Published private(set) var latestAutonomicScores: AutonomicScores?
    @Published private(set) var latestEmotionEstimate: EmotionEstimate?
    @Published private(set) var latestAnomalyEvent: AnomalyEvent?

#if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
#endif

    private let motionProvider = MotionSignalProvider()
    private let estimator = StateEstimator()
    private let logStore = SessionLogStore()
    private var window = SlidingHeartWindow(duration: 45)
    private var latestMotionSnapshot = MotionSnapshot(timestamp: Date(), motionScore: 0, isStationary: true)
    private var mockTimer: Timer?
    private var mockTick = 0
    private var lastAnomalyTimestamps: [AnomalyEventType: Date] = [:]

    override init() {
        super.init()

        motionProvider.onUpdate = { [weak self] snapshot in
            Task { @MainActor in
                self?.latestMotionSnapshot = snapshot
                self?.latestMotionScore = snapshot.motionScore
            }
        }
    }

    func requestAuthorizationIfNeeded() async {
#if os(watchOS) && !targetEnvironment(simulator) && canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatusText = "Health data unavailable"
            return
        }

        let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let workout = HKObjectType.workoutType()

        do {
            try await healthStore.requestAuthorization(
                toShare: [workout],
                read: [heartRate, hrv, workout]
            )
            authorizationStatusText = "Authorized"
            inputModeText = "Live"
        } catch {
            authorizationStatusText = "Authorization failed"
            latestErrorMessage = error.localizedDescription
        }
#else
        authorizationStatusText = "Simulator mock mode"
        inputModeText = "Mock"
#endif
    }

    func toggleSession() {
        if isRunning {
            stopSession()
        } else {
            Task {
                await requestAuthorizationIfNeeded()
                startSession()
            }
        }
    }

    private func startSession() {
#if os(watchOS) && !targetEnvironment(simulator) && canImport(HealthKit)
        do {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .mindAndBody
            configuration.locationType = .indoor

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()

            session.delegate = self
            builder.delegate = self
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            let startDate = Date()
            workoutSession = session
            workoutBuilder = builder
            resetForNewSession(inputMode: "Live")

            logStore.startSession()
            motionProvider.start()
            publishLiveStatus(isSessionRunning: true, at: startDate)

            session.startActivity(with: startDate)
            builder.beginCollection(withStart: startDate) { [weak self] success, error in
                Task { @MainActor in
                    guard let self else { return }
                    if !success {
                        self.latestErrorMessage = error?.localizedDescription ?? "Collection failed"
                    }
                }
            }

            isRunning = true
        } catch {
            latestErrorMessage = error.localizedDescription
        }
#else
        startMockSession()
#endif
    }

    private func stopSession() {
#if os(watchOS) && !targetEnvironment(simulator) && canImport(HealthKit)
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        isRunning = false
        motionProvider.stop()
        publishLiveStatus(isSessionRunning: false, at: Date())
        session.end()

        let endDate = Date()
        builder.endCollection(withEnd: endDate) { [weak self] _, error in
            guard let self else { return }

            builder.finishWorkout { _, finishError in
                Task { @MainActor in
                    self.latestErrorMessage = finishError?.localizedDescription ?? error?.localizedDescription
                }
            }
        }

        do {
            if let fileURL = try logStore.finishSession() {
                ConnectivityBridge.shared.transferSessionLog(fileURL: fileURL)
            }
        } catch {
            latestErrorMessage = error.localizedDescription
        }

        workoutSession = nil
        workoutBuilder = nil
#else
        stopMockSession()
#endif
    }

    private func resetForNewSession(inputMode: String) {
        window.reset()
        currentHeartRate = nil
        currentEstimation = nil
        latestErrorMessage = nil
        latestMotionScore = 0
        latestSignalConfidence = nil
        latestSampleCount = 0
        latestAutonomicScores = nil
        latestEmotionEstimate = nil
        latestAnomalyEvent = nil
        lastAnomalyTimestamps.removeAll()
        mockTick = 0
        inputModeText = inputMode
    }

    private func handleHeartRate(_ bpm: Double, at date: Date) {
        currentHeartRate = bpm

        let confidence = baseConfidence(for: latestMotionSnapshot)
        let sample = HeartSample(
            timestamp: date,
            bpm: bpm,
            confidence: confidence,
            motionScore: latestMotionSnapshot.motionScore,
            isStationary: latestMotionSnapshot.isStationary
        )

        window.append(sample)
        latestSignalConfidence = confidence
        latestSampleCount = window.samples.count

        var detectedEvents: [AnomalyEvent] = []
        if let features = window.features(referenceDate: date) {
            currentEstimation = estimator.estimate(from: features, now: date)
            latestAutonomicScores = estimator.autonomicScores(from: features, now: date)
            if let latestAutonomicScores {
                latestEmotionEstimate = estimator.emotionEstimate(
                    from: currentEstimation?.state ?? .unknown,
                    autonomic: latestAutonomicScores,
                    features: features,
                    now: date
                )
            }
            detectedEvents = detectAnomalies(
                bpm: bpm,
                at: date,
                signalConfidence: confidence,
                features: features
            )
        } else {
            currentEstimation = nil
            latestAutonomicScores = nil
            latestEmotionEstimate = nil
        }
        latestAnomalyEvent = detectedEvents.last

        publishLiveStatus(isSessionRunning: isRunning, at: date)

        let timelinePoint = TimelinePoint(
            timestamp: date,
            bpm: bpm,
            signalConfidence: confidence,
            motionScore: latestMotionSnapshot.motionScore,
            state: currentEstimation?.state ?? .unknown,
            stateConfidence: currentEstimation?.confidence,
            autonomicScores: latestAutonomicScores,
            emotionEstimate: latestEmotionEstimate
        )
        logStore.append(
            sample: sample,
            estimation: currentEstimation,
            timelinePoint: timelinePoint,
            newEvents: detectedEvents
        )
    }

    private func baseConfidence(for motion: MotionSnapshot) -> Double {
        let motionPenalty = min(0.25, motion.motionScore * 2.0)
        let stationaryBonus = motion.isStationary ? 0.1 : 0
        return min(max(0.6 - motionPenalty + stationaryBonus, 0.2), 0.9)
    }

    private func startMockSession() {
        resetForNewSession(inputMode: "Mock")
        isRunning = true
        logStore.startSession()
        publishLiveStatus(isSessionRunning: true, at: Date())
        emitMockSample()

        mockTimer?.invalidate()
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleMockTimerTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        mockTimer = timer
    }

    private func stopMockSession() {
        guard mockTimer != nil || isRunning else { return }
        mockTimer?.invalidate()
        mockTimer = nil
        isRunning = false
        publishLiveStatus(isSessionRunning: false, at: Date())

        do {
            if let fileURL = try logStore.finishSession() {
                ConnectivityBridge.shared.transferSessionLog(fileURL: fileURL)
            }
        } catch {
            latestErrorMessage = error.localizedDescription
        }
    }

    @objc
    private func handleMockTimerTick() {
        emitMockSample()
    }

    private func publishLiveStatus(isSessionRunning: Bool, at date: Date) {
        let status = LiveWatchStatus(
            timestamp: date,
            isSessionRunning: isSessionRunning,
            inputMode: inputModeText,
            heartRate: currentHeartRate,
            state: currentEstimation?.state ?? .unknown,
            stateConfidence: currentEstimation?.confidence,
            signalConfidence: latestSignalConfidence,
            motionScore: latestMotionScore,
            sampleCount: latestSampleCount,
            autonomicScores: latestAutonomicScores,
            emotionEstimate: latestEmotionEstimate,
            latestEvent: latestAnomalyEvent
        )
        ConnectivityBridge.shared.sendLiveStatus(status)
    }

    private func detectAnomalies(
        bpm: Double,
        at date: Date,
        signalConfidence: Double,
        features: WindowFeatures
    ) -> [AnomalyEvent] {
        var events: [AnomalyEvent] = []
        let previousBPM = window.samples.dropLast().last?.bpm
        let delta = previousBPM.map { bpm - $0 }

        if let delta, delta >= 15,
           shouldEmitEvent(type: .suddenRise, at: date, cooldown: 45) {
            events.append(
                AnomalyEvent(
                    timestamp: date,
                    type: .suddenRise,
                    severity: delta >= 22 ? .high : .warn,
                    summary: "Rapid heart-rate rise detected",
                    heartRate: bpm,
                    deltaFromPrevious: delta,
                    motionScore: latestMotionSnapshot.motionScore,
                    signalConfidence: signalConfidence
                )
            )
        }

        if let delta, delta <= -15,
           shouldEmitEvent(type: .suddenDrop, at: date, cooldown: 45) {
            events.append(
                AnomalyEvent(
                    timestamp: date,
                    type: .suddenDrop,
                    severity: delta <= -22 ? .high : .warn,
                    summary: "Rapid heart-rate drop detected",
                    heartRate: bpm,
                    deltaFromPrevious: delta,
                    motionScore: latestMotionSnapshot.motionScore,
                    signalConfidence: signalConfidence
                )
            )
        }

        if features.shortTermVariation >= 12, features.motionMean <= 0.06,
           shouldEmitEvent(type: .irregularPattern, at: date, cooldown: 90) {
            events.append(
                AnomalyEvent(
                    timestamp: date,
                    type: .irregularPattern,
                    severity: features.shortTermVariation >= 16 ? .high : .warn,
                    summary: "Irregular low-motion pattern detected",
                    heartRate: bpm,
                    deltaFromPrevious: delta,
                    motionScore: latestMotionSnapshot.motionScore,
                    signalConfidence: signalConfidence
                )
            )
        }

        if signalConfidence < 0.35,
           shouldEmitEvent(type: .lowSignal, at: date, cooldown: 60) {
            events.append(
                AnomalyEvent(
                    timestamp: date,
                    type: .lowSignal,
                    severity: .info,
                    summary: "Signal quality is low, interpretation may be unstable",
                    heartRate: bpm,
                    deltaFromPrevious: delta,
                    motionScore: latestMotionSnapshot.motionScore,
                    signalConfidence: signalConfidence
                )
            )
        }

        return events
    }

    private func shouldEmitEvent(type: AnomalyEventType, at date: Date, cooldown: TimeInterval) -> Bool {
        guard let last = lastAnomalyTimestamps[type] else {
            lastAnomalyTimestamps[type] = date
            return true
        }
        guard date.timeIntervalSince(last) >= cooldown else { return false }
        lastAnomalyTimestamps[type] = date
        return true
    }

    private func emitMockSample() {
        let sample = makeMockSample(for: mockTick, at: Date())
        latestMotionSnapshot = MotionSnapshot(
            timestamp: sample.timestamp,
            motionScore: sample.motionScore,
            isStationary: sample.isStationary
        )
        latestMotionScore = sample.motionScore
        handleHeartRate(sample.bpm, at: sample.timestamp)
        mockTick += 1
    }

    private func makeMockSample(for tick: Int, at date: Date) -> HeartSample {
        let seconds = Double(tick)
        let phase = (tick / 20) % 4

        let bpm: Double
        let motion: Double
        let stationary: Bool

        switch phase {
        case 0:
            bpm = 68 + sin(seconds / 5.0) * 2.2
            motion = 0.012 + abs(sin(seconds / 8.0)) * 0.01
            stationary = true
        case 1:
            bpm = 81 + sin(seconds / 4.0) * 2.5
            motion = 0.025 + abs(cos(seconds / 6.0)) * 0.015
            stationary = motion < 0.04
        case 2:
            bpm = 101 + sin(seconds / 2.2) * 6.0
            motion = 0.09 + abs(sin(seconds / 3.0)) * 0.04
            stationary = false
        default:
            bpm = 97 + sin(seconds / 6.5) * 1.2
            motion = 0.018 + abs(cos(seconds / 7.0)) * 0.01
            stationary = true
        }

        let confidence = phase == 2 ? 0.62 : 0.84
        return HeartSample(
            timestamp: date,
            bpm: bpm,
            confidence: confidence,
            motionScore: motion,
            isStationary: stationary
        )
    }
}

#if os(watchOS) && canImport(HealthKit)
extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.latestErrorMessage = error.localizedDescription
            self.isRunning = false
        }
    }
}

extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(quantityType),
              let statistics = workoutBuilder.statistics(for: quantityType),
              let quantity = statistics.mostRecentQuantity()
        else {
            return
        }

        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let bpm = quantity.doubleValue(for: bpmUnit)

        Task { @MainActor in
            self.handleHeartRate(bpm, at: Date())
        }
    }
}
#endif
