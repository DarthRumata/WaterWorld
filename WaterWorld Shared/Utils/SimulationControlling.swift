import Foundation

/// A protocol to control the simulation lifecycle by pausing and resuming it.
/// 
/// Types conforming to this protocol are typically scenes or controllers that own
/// the tick or update loop of the simulation, allowing external coordination to
/// temporarily halt or continue simulation updates.
public protocol SimulationControlling: Sendable {
    /// Asynchronously pause the simulation.
    func pauseSimulation() async
    
    /// Asynchronously resume the simulation.
    func resumeSimulation() async
}
