import Combine
import Foundation
import HealthKit

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

    private let healthStore = HKHealthStore()
    private let motionProvider = MotionSignalProvider()
    private let estimator = StateEstimator()
    private let logStore = SessionLogStore()

    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var window = SlidingHeartWindow(duration: 45)
    private var latestMotionSnapshot = MotionSnapshot(timestamp: Date(), motionScore: 0, isStationary: true)
    private var mockTimer: Timer?
    private var mockTick: Int = 0

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
#if targetEnvironment(simulator)
        authorizationStatusText = "Simulator mock mode"
        inputModeText = "Mock"
        return
#else
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
        } catch {
            authorizationStatusText = "Authorization failed"
            latestErrorMessage = error.localizedDescription
        }
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
#if targetEnvironment(simulator)
        startMockSession()
        return
#else
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
            window.reset()
            currentHeartRate = nil
            currentEstimation = nil
            latestErrorMessage = nil
            latestSignalConfidence = nil
            latestSampleCount = 0

            logStore.startSession()
            motionProvider.start()

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
#endif
    }

    private func stopSession() {
#if targetEnvironment(simulator)
        stopMockSession()
        return
#else
        guard let session = workoutSession, let builder = workoutBuilder else { return }

        isRunning = false
        motionProvider.stop()
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
#endif
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

        if let features = window.features(referenceDate: date) {
            currentEstimation = estimator.estimate(from: features, now: date)
        }

        logStore.append(sample: sample, estimation: currentEstimation)
    }

    private func baseConfidence(for motion: MotionSnapshot) -> Double {
        let motionPenalty = min(0.25, motion.motionScore * 2.0)
        let stationaryBonus = motion.isStationary ? 0.1 : 0
        return min(max(0.6 - motionPenalty + stationaryBonus, 0.2), 0.9)
    }

    private func startMockSession() {
        window.reset()
        currentHeartRate = nil
        currentEstimation = nil
        latestErrorMessage = nil
        latestMotionScore = 0
        latestSignalConfidence = nil
        latestSampleCount = 0
        mockTick = 0
        inputModeText = "Mock"
        isRunning = true

        logStore.startSession()
        emitMockSample()

        mockTimer?.invalidate()
        mockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.emitMockSample()
            }
        }
    }

    private func stopMockSession() {
        guard mockTimer != nil || isRunning else { return }

        mockTimer?.invalidate()
        mockTimer = nil
        isRunning = false

        do {
            if let fileURL = try logStore.finishSession() {
                ConnectivityBridge.shared.transferSessionLog(fileURL: fileURL)
            }
        } catch {
            latestErrorMessage = error.localizedDescription
        }
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

        let confidence = min(max(phase == 2 ? 0.62 : 0.84, 0.2), 0.95)

        return HeartSample(
            timestamp: date,
            bpm: bpm,
            confidence: confidence,
            motionScore: motion,
            isStationary: stationary
        )
    }
}

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
