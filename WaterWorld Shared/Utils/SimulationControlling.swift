import Foundation

/// A protocol to control the simulation lifecycle by pausing and resuming it.
public protocol SimulationControlling: Sendable {
    /// Asynchronously pause the simulation.
    func pauseSimulation() async

    /// Asynchronously resume the simulation.
    func resumeSimulation() async
}
