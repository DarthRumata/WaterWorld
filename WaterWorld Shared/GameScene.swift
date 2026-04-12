//
//  GameScene.swift
//  WaterWorld Shared
//
//  Created by Stas Kirichok on 11/11/24.
//

import Combine
import Foundation
import SpriteKit
import CoreGraphics

#if os(OSX)
import SwiftUI
import AppKit
#endif

class GameScene: SKScene {
    // MARK: Callbacks
    
    var onTapOrganism: ((OrganismSelection?) -> Void)?
    
    // Global state
    
    @Published private var lightLevel: Double = 0 // Ranges from 0 to 10
    @Published private var dayCount: Int = 0
    @Published private var simulationSpeed: TimeInterval = 1.0 // Default speed
    @Published private var totalTime: TimeInterval = 0.0 // Keeps track of elapsed time
    @Published private var lastUpdateTime: TimeInterval?
    private var timeSinceLastTick: TimeInterval = 0
    /// 0 - sunrise, 0.25 - noon, 0.5 - sunset, 0.5 - 1 - night
    @Published private var dayProgress: Double = 0
    @Published private var gameState: GameState = .stopped
    
    @Published private var simulationMode: SimulationMode = .normal
    @Published private var predatorsIntensity: PredatorsIntensity = .medium
    @Published private var costFunctionType: CostFunctionType = .mse
    
    // UI
    let hudModel = GameHUDModel()
    private var container: WaterContainer!
    private var deathMarkerManager: DeathMarkerManager?
    private var infoPopover: NSPopover?
    private weak var reportWindow: NSWindow?
    private weak var metricsWindow: NSWindow?
    private var popoverNode: CustomPopoverNode?
    
    // Combine
    
    private var cancellables = Set<AnyCancellable>()
    
    // Models
    
    @Published private var organisms = [UUID: Organism]()
    private var organismModels = [UUID: OrganismModel]()
    
    // Utils
    
    private let nameGenerator = UniqueNameGenerator(syllables: ["ka", "bar", "ma", "lo", "ni", "mek", "ta", "pon", "ger", "du"])
    private let environment = EnvironmentService()
    private var predationManager: PredationManager!
    private var qLearner: QLearner!
    
    // Tasks
    
    private var notificationTask: Task<Void, Error>?
    
    private var isTickRunning = false
    private var isResettingEpisode = false
    private var episodeNumber: Int = 0
    private var episodeStartDay: Int = 0
    class func newGameScene() -> GameScene {
        // Load 'GameScene.sks' as an SKScene.
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            print("Failed to load GameScene.sks")
            abort()
        }
        
        // Set the scale mode to scale to fit the window
        scene.scaleMode = .resizeFill
        scene.physicsWorld.gravity = .zero // Keep gravity neutral
        scene.physicsWorld.speed = 1.0 // Default speed for consistent resolution
        
        return scene
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        view.window?.acceptsMouseMovedEvents = true
        backgroundColor = .cyan
        
        setUpScene()
        didChangeSize(size)
        
        self.qLearner = QLearner(
            epsilonGreedy: 1.0,
            gamma: 0.99,
            batchSize: 128,
            learningRate: 0.01,
            deltaWeight: 0.05,
            costFunction: costFunctionType.make(),
            networkUpdateHandler: { [weak self] network, epsilon in
                await self?.propagateNetwork(network, epsilon: epsilon)
            },
            sustainedWarningHandler: { [weak self] _ in
                await self?.pauseSimulation()
            }
        )
    }

    @MainActor
    private func propagateNetwork(_ network: NeuralNetwork, epsilon: Double) async {
        let models = Array(organismModels.values)
        await withTaskGroup(of: Void.self) { group in
            for model in models {
                group.addTask { await model.updateBrainNetwork(network, epsilon: epsilon) }
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        let rawDelta = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime
        clampOrganismPositions()

        guard gameState == .active else { return }

        // If the previous tick is still processing — don't accumulate time.
        // The simulation naturally throttles to what the system can actually handle.
        guard !isTickRunning else { return }

        // Clamp delta to prevent a large spike after a pause or debugger break.
        let deltaTime = min(rawDelta, 0.1)
        let scaledDeltaTime = deltaTime * simulationSpeed
        timeSinceLastTick += scaledDeltaTime
        totalTime += scaledDeltaTime

        if timeSinceLastTick >= GlobalConstants.gameTickDuration {
            timeSinceLastTick = 0
            gameTick()
        }
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        print("Scene size changed from \(oldSize) to \(size)")
        
        container?.update(sceneSize: size)
        
        // Re-apply bounds constraints to organisms after size change
        for organism in organisms.values {
            applyBoundsConstraint(to: organism)
        }
    }
    
    // Create UI
    
    private func setUpScene() {
        backgroundColor = SKColor.white

        // Create UI
        setupHUDModel()
        addContainer()
        
        predationManager = PredationManager(intensity: predatorsIntensity)
        
        // Init managers
        deathMarkerManager = DeathMarkerManager(container: container, dayDuration: GlobalConstants.dayDuration)
        
        addPopoverNode()
        
        $dayProgress
            .sink { [weak self] progress in
                guard let self else { return }
                self.hudModel.dayProgress = progress
                guard self.simulationMode != .learning else { return }
                self.backgroundColor = DayNightStyler.skyColor(for: progress)
                self.container.color = DayNightStyler.waterColor(for: progress)
            }
            .store(in: &cancellables)

        $dayCount.sink { [weak self] in
            guard let self else { return }
            self.hudModel.dayCount = $0
            self.hudModel.episodeDayCount = $0 - self.episodeStartDay
            self.hudModel.episodeNumber = self.episodeNumber
        }.store(in: &cancellables)
        $simulationSpeed.sink { [weak self] in self?.hudModel.simulationSpeed = $0 }.store(in: &cancellables)
        $lightLevel.sink { [weak self] in self?.hudModel.lightLevel = $0 }.store(in: &cancellables)
        $gameState.sink { [weak self] in self?.hudModel.gameState = $0 }.store(in: &cancellables)
        $simulationMode.sink { [weak self] in self?.hudModel.simulationMode = $0 }.store(in: &cancellables)
        $predatorsIntensity.sink { [weak self] in self?.hudModel.predatorsIntensity = $0 }.store(in: &cancellables)
        $costFunctionType.sink { [weak self] in self?.hudModel.costFunctionType = $0 }.store(in: &cancellables)
        $organisms.sink { [weak self] in self?.hudModel.organismsCount = $0.count }.store(in: &cancellables)
    }
    
    private func setupHUDModel() {
        hudModel.onRestart = { [weak self] in self?.restartSimulation() }
        hudModel.onIncreaseSpeed = { [weak self] in
            guard let self else { return }
            let newSpeed = self.simulationSpeed <= 1 ? self.simulationSpeed * 2 : self.simulationSpeed + 1
            self.simulationSpeed = min(newSpeed, 100)
        }
        hudModel.onDecreaseSpeed = { [weak self] in
            guard let self else { return }
            let newSpeed = self.simulationSpeed <= 1 ? self.simulationSpeed / 2 : self.simulationSpeed - 1
            self.simulationSpeed = max(newSpeed, 0.25)
        }
        hudModel.onPause = { [weak self] in
            guard let self, self.gameState != .stopped else { return }
            Task {
                if self.gameState == .active {
                    await self.pauseSimulation()
                } else if self.gameState == .paused {
                    await self.resumeSimulation()
                }
            }
        }
        hudModel.onReport = { [weak self] in self?.presentQLearningReport() }
        hudModel.onToggleMode = { [weak self] in self?.toggleSimulationMode() }
        hudModel.onSelectPredatorsIntensity = { [weak self] intensity in self?.setPredatorsIntensity(intensity) }
        hudModel.onSelectCostFunction = { [weak self] type in self?.setCostFunctionType(type) }
        hudModel.onSetGamma = { [weak self] value in
            guard let self else { return }
            Task { await self.qLearner.setGamma(value) }
            self.hudModel.gamma = value
        }
        hudModel.onSetTau = { [weak self] value in
            guard let self else { return }
            Task { await self.qLearner.setTau(value) }
            self.hudModel.tau = value
        }
        hudModel.onSetDeltaWeight = { [weak self] value in
            guard let self else { return }
            Task { await self.qLearner.setDeltaWeight(value) }
            self.hudModel.deltaWeight = value
        }
        hudModel.onTapMetric = { [weak self] tab in self?.presentMetricsChart(tab: tab) }
        hudModel.onSaveNetwork = { [weak self] in
            guard let self else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = NeuralNetworkSnapshot.defaultFileName
            guard panel.runModal() == .OK, let url = panel.url else { return }
            Task {
                let snapshot = await self.qLearner.mainNetwork.makeSnapshot()
                try? NeuralNetworkSnapshot.save(snapshot, to: url)
            }
        }
        hudModel.onLoadNetwork = { [weak self] in
            guard let self else { return }
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            Task {
                guard let snapshot = try? NeuralNetworkSnapshot.load(from: url) else { return }
                try? await self.qLearner.applySnapshot(snapshot)
                let network = await self.qLearner.mainNetwork
                let epsilon = await self.qLearner.currentEpsilon
                await self.propagateNetwork(network, epsilon: epsilon)
            }
        }
    }
    
    private func addContainer() {
        container = WaterContainer(
            color: NSColor(red: 116.0 / 255, green: 204.0 / 255, blue: 244.0 / 255, alpha: 0.7),
            size: CGSize(width: size.width, height: size.height)
        )
        container.anchorPoint = CGPoint(x: 0, y: 0)
        container.position = .zero
        addChild(container)
    }
    
    private func addOrganisms() async {
        let initialNetwork = await qLearner.mainNetwork
        let initialEpsilon = await qLearner.currentEpsilon
        spawnOrganisms(network: initialNetwork, epsilon: initialEpsilon)
    }

    @MainActor
    private func spawnOrganisms(network: NeuralNetwork, epsilon: Double) {
        for i in 0 ..< GlobalConstants.initialPopulation {
            let xPosition = CGFloat.random(in: 10...container.size.width - 10)
            let yPosition = CGFloat.random(in: 10...container.size.height - 10)
            let position = CGPoint(x: xPosition, y: yPosition)

            let baseColor = SKColor.green
            let logger: Logger = i == 0 ? ConsoleLogger() : EmptyLogger()
            let tracker = OrganismTracker(logger: logger)

            let model = OrganismModel(
                brain: QBrain(
                    reportExperience: { [weak self] state, next, action in
                        await self?.qLearner.reportExperience(currentState: state, nextState: next, actionIndex: action)
                    },
                    agentPolicy: AgentPolicy(network: network, epsilon: epsilon)
                ),
                name: nameGenerator.generateName() ?? "\(i)",
                logger: logger,
                tracker: tracker
            ) { @MainActor [weak self] (model: OrganismModel, cause: CauseOfDeath) in
                guard let self else { return }
                let id = model.id
                if let organism = self.organisms[id] {
                    let deathPosition = organism.position
                    self.deathMarkerManager?.addMarker(at: deathPosition, cause: cause)
                    organism.removeFromParent()
                }
                self.organismModels.removeValue(forKey: id)
                self.organisms.removeValue(forKey: id)
                QLearningStore.shared.recordDeath(cause: cause)

                if self.simulationMode == .learning, self.organismModels.isEmpty {
                    self.startNewLearningEpisode()
                }
            }

            let organism = Organism(
                model: model,
                position: position,
                color: baseColor,
                radius: 10
            ) { [weak self] organism in
                guard let self else { return }
                Task {
                    let network = await self.qLearner.mainNetwork
                    self.onTapOrganism?(OrganismSelection(model: model, network: network))
                }
            }
            organisms[model.id] = organism
            organismModels[model.id] = model
            container.addChild(organism)
            applyBoundsConstraint(to: organism)
        }
    }
    
    private func addPopoverNode() {
        // Initialize the popover
        popoverNode = CustomPopoverNode(title: "Title", details: "Details", size: CGSize(width: 200, height: 100))
        if let popover = popoverNode {
            addChild(popover)
        }
    }
    
    private func resetOrganismsPopulation() async {
        for (_, organism) in organisms {
            organism.removeFromParent()
        }
        organismModels.removeAll()
        organisms.removeAll()
        nameGenerator.regenerate()
        await addOrganisms()
    }

    private func resetPopulationForLearningCycle() async {
        cancelCurrentUpdate()
        await resetOrganismsPopulation()
    }
    
    // MARK: Control state
    
    private func restartSimulation() {
        gameState = .stopped
        cancelCurrentUpdate()

        if simulationMode == .normal {
            totalTime = 0
            dayCount = 0
            dayProgress = 0
            lightLevel = environment.baseLightLevel(maxLight: GlobalConstants.maxLightLevel, dayProgress: dayProgress)
            deathMarkerManager?.clearAll()
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.resetOrganismsPopulation()
            self.gameState = .active
        }
    }
    
    private func toggleSimulationMode() {
        switch simulationMode {
        case .normal:
            simulationMode = .learning
        case .learning:
            simulationMode = .normal
        }
    }
    
    private func setCostFunctionType(_ type: CostFunctionType) {
        costFunctionType = type
        Task { await qLearner.setCostFunction(type) }
    }

    private func setPredatorsIntensity(_ intensity: PredatorsIntensity) {
        predatorsIntensity = intensity
        predationManager.updateIntensity(intensity)
        // Re-plan if currently night
        if dayProgress >= 0.5 {
            predationManager.ensurePlanIfNight(dayProgress: dayProgress)
        }
    }
    
    // MARK: State updates
    
    private func gameTick() {
        let timeInDay = totalTime.truncatingRemainder(dividingBy: GlobalConstants.dayDuration)
        dayProgress = CGFloat(timeInDay / GlobalConstants.dayDuration)
        lightLevel = environment.baseLightLevel(maxLight: GlobalConstants.maxLightLevel, dayProgress: dayProgress)

        predationManager.advanceDayProgress(dayProgress: dayProgress, tickDuration: GlobalConstants.gameTickDuration)

        speed = simulationSpeed
        physicsWorld.speed = simulationSpeed
        let newDayCount = Int(totalTime) / Int(GlobalConstants.dayDuration)
        if newDayCount != dayCount {
            QLearningStore.shared.advanceDay(to: newDayCount)
        }
        dayCount = newDayCount

        predationManager.ensurePlanIfNight(dayProgress: dayProgress)

        isTickRunning = true
        notificationTask = Task { [weak self] in
            guard let self else { return }
            await self.runTickPass()
            await MainActor.run { self.isTickRunning = false }
        }
    }
    
    private func startNewLearningEpisode() {
        guard !isResettingEpisode else { return }
        isResettingEpisode = true
        episodeNumber += 1
        episodeStartDay = dayCount
        QLearningStore.shared.recordEpisodeBoundary(episode: episodeNumber)
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.resetPopulationForLearningCycle()
            self.isResettingEpisode = false
        }
    }
    
    @MainActor
    private func runTickPass() async {
        // Snapshot stable (model, view, depth) pairs up front
        let pairs: [(model: OrganismModel, view: Organism, depth: CGFloat)] = organismModels.compactMap { (id, model) in
            guard let view = organisms[id] else { return nil }
            let depth = normalizedDepth(for: view)
            return (model, view, depth)
        }

        // Process due night attacks via PredationManager
        let events = await predationManager.processDueAttacks(pairs: pairs.map { ($0.view.id, $0.depth) })

        // Apply events
        for event in events {
            switch event {
            case let .damage(id, amount):
                await organismModels[id]?.applyDamage(amount)
            case let .kill(id, _):
                await organismModels[id]?.kill()
            }
        }

        // Notify organisms using the original pairs snapshot
        for (model, view, depth) in pairs {
            guard !Task.isCancelled else { return }
            guard organismModels[model.id] != nil, organisms[view.id] != nil else { continue }

            view.speed = simulationSpeed
            let lightLevel = lightLevel(atDepth: depth)
            await model.handleChanges(lightLevel: lightLevel, depth: depth, dayProgress: dayProgress)
        }
    }
    
    private func cancelCurrentUpdate() {
        notificationTask?.cancel()
        notificationTask = nil
        isTickRunning = false
        timeSinceLastTick = 0
    }
    
    // MARK: Update overlay
    
    private func showOrganismPopover(sceneLocation: CGPoint, model: OrganismModel) {
        Task {
            let organismEnergy = await model.energy
            
            popoverNode?.show(
                at: sceneLocation,
                in: self,
                title: model.name,
                details: "Energy: \(organismEnergy)"
            )
        }
    }
    
    // MARK: Utils
    
    // Normalized from 0 to 100
    private func normalizedDepth(for organism: Organism) -> CGFloat {
        normalizedDepth(atPositionY: organism.position.y)
    }
    
    private func lightLevel(atDepth depth: CGFloat) -> CGFloat {
        environment.attenuatedLight(surfaceLight: lightLevel, depth: depth)
    }
    
    private func normalizedDepth(atPositionY positionY: CGFloat) -> CGFloat {
        let maxDepth = container.size.height
        let currentDepth = maxDepth - positionY
        return currentDepth / maxDepth * GlobalConstants.maxDepth
    }
    
    private func clampOrganismPositions() {
        for organism in organisms.values {
            let organismRadius = organism.frame.width / 2
            let clampedX = max(organismRadius, min(organism.position.x, container.size.width - organismRadius))
            let clampedY = max(organismRadius, min(organism.position.y, container.size.height - organismRadius))
            organism.position = CGPoint(x: clampedX, y: clampedY)
        }
    }

    private func applyBoundsConstraint(to organism: Organism) {
        // Ensure constraints match the current container size and organism radius
        let radius = organism.frame.width / 2
        let minX = radius
        let maxX = max(radius, container.size.width - radius)
        let minY = radius
        let maxY = max(radius, container.size.height - radius)

        let xRange = SKRange(lowerLimit: minX, upperLimit: maxX)
        let yRange = SKRange(lowerLimit: minY, upperLimit: maxY)

        let xConstraint = SKConstraint.positionX(xRange)
        let yConstraint = SKConstraint.positionY(yRange)
        organism.constraints = [xConstraint, yConstraint]
    }
    
    #if os(OSX)
    private func presentQLearningReport() {
        if let existing = reportWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: QLearningReportView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Q-Learning Report"
        window.setContentSize(NSSize(width: 700, height: 420))
        window.makeKeyAndOrderFront(nil)
        reportWindow = window
    }

    private func presentMetricsChart(tab: MetricTab) {
        if let existing = metricsWindow {
            existing.makeKeyAndOrderFront(nil)
            // Switch tab in existing window
            if let hosting = existing.contentViewController as? NSHostingController<MetricsChartView> {
                hosting.rootView.selectedTab = tab
            }
            return
        }
        let view = MetricsChartView(selectedTab: tab)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Metrics"
        window.setContentSize(NSSize(width: 700, height: 450))
        window.makeKeyAndOrderFront(nil)
        metricsWindow = window
    }
    #endif
}

extension GameScene: SimulationControlling {
    func pauseSimulation() async {
        await MainActor.run {
            guard gameState != .stopped else { return }
            if gameState == .active {
                gameState = .paused
                cancelCurrentUpdate()
            }
            // Optionally hard-pause SpriteKit:
            // self.isPaused = true
            // self.view?.isPaused = true
            // self.physicsWorld.speed = 0
        }
    }

    func resumeSimulation() async {
        await MainActor.run {
            guard gameState == .paused else { return }
            gameState = .active
            // Optionally resume SpriteKit:
            // self.isPaused = false
            // self.view?.isPaused = false
            // self.physicsWorld.speed = simulationSpeed
        }
    }

}

#if os(OSX)
// Mouse-based event handling
extension GameScene {
    override func mouseDown(with event: NSEvent) {}
    
    override func mouseDragged(with event: NSEvent) {
        let locationInView = event.locationInWindow

        // Convert the mouse location from view coordinates to scene coordinates
        let sceneLocation = convertPoint(fromView: locationInView)
        
        // Find nodes at the mouse location
        let nodesAtPoint = nodes(at: sceneLocation)
        
        if let organismNode = nodesAtPoint.first(where: { $0 is Organism }) as? Organism,
           let model = organismModels[organismNode.id] {
            // Show the popover
            showOrganismPopover(sceneLocation: sceneLocation, model: model)
        } else {
            let depth = normalizedDepth(atPositionY: sceneLocation.y)
            let light = lightLevel(atDepth: depth)
            let energyCalculator = EnergyCalculator()
            let gain = energyCalculator.energyGain(fromLightLevel: light)
            
            popoverNode?.show(
                at: sceneLocation,
                in: self,
                title: "Depth: \(depth.formatted())",
                details: "Light: \(light.formatted()), gain: \(gain)"
            )
            onTapOrganism?(nil)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        popoverNode?.hide()
    }
}
#endif

