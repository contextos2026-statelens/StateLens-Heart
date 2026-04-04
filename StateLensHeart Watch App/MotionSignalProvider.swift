import Foundation
#if canImport(CoreMotion)
import CoreMotion
#endif

struct MotionSnapshot {
    let timestamp: Date
    let motionScore: Double
    let isStationary: Bool
}

final class MotionSignalProvider {
#if canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
#endif

    var onUpdate: ((MotionSnapshot) -> Void)?

    func start() {
#if canImport(CoreMotion)
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0
        queue.name = "MotionSignalProvider"

        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let acceleration = motion.userAcceleration
            let magnitude = sqrt(
                pow(acceleration.x, 2) +
                pow(acceleration.y, 2) +
                pow(acceleration.z, 2)
            )

            self.onUpdate?(
                MotionSnapshot(
                    timestamp: Date(),
                    motionScore: magnitude,
                    isStationary: magnitude < 0.03
                )
            )
        }
#endif
    }

    func stop() {
#if canImport(CoreMotion)
        motionManager.stopDeviceMotionUpdates()
#endif
    }
}
