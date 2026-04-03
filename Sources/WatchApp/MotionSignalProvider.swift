import CoreMotion
import Foundation

struct MotionSnapshot {
    let timestamp: Date
    let motionScore: Double
    let isStationary: Bool
}

final class MotionSignalProvider {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    var onUpdate: ((MotionSnapshot) -> Void)?

    func start() {
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

            let snapshot = MotionSnapshot(
                timestamp: Date(),
                motionScore: magnitude,
                isStationary: magnitude < 0.03
            )

            self.onUpdate?(snapshot)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
