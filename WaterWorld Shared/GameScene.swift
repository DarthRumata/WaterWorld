//
//  GameScene.swift
//  WaterWorld Shared
//
//  Created by Stas Kirichok on 11/11/24.
//

import Combine
import Foundation
import SpriteKit

class GameScene: SKScene {
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
    
    // UI
    
    private var uiPanel: UIPanel?
    private var container: WaterContainer!
    private var infoPopover: NSPopover?
    private var popoverNode: CustomPopoverNode?
    
    // Combine
    
    private var cancellables = Set<AnyCancellable>()
    
    // Models
    
    @Published private var organisms = [UUID: Organism]()
    private var organismModels = [UUID: OrganismModel]()
    
    // Utils
    
    private let nameGenerator = UniqueNameGenerator(syllables: ["ka", "bar", "ma", "lo", "ni", "mek", "ta", "pon", "ger", "du"])
    
    // Tasks
    
    private var notificationTask: Task<Void, Error>?

    class func newGameScene() -> GameScene {
        // Load 'GameScene.sks' as an SKScene.
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            print("Failed to load GameScene.sks")
            abort()
        }
        
        // Set the scale mode to scale to fit the window
        scene.scaleMode = .aspectFit
        
        return scene
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        view.window?.acceptsMouseMovedEvents = true
        
        setUpScene()
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime
        
        guard gameState == .active else {
            return
        }
        
        let scaledDeltaTime = deltaTime * simulationSpeed
        timeSinceLastTick += scaledDeltaTime
        // Update total time considering simulation speed
        totalTime += scaledDeltaTime
        
        if timeSinceLastTick >= GlobalConstants.gameTickDuration {
            gameTick()
            timeSinceLastTick -= GlobalConstants.gameTickDuration
        }
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        print("Scene size changed from \(oldSize) to \(size)")
        
        // Update positions of UI elements if necessary
        uiPanel?.update(withSceneSize: size)
        container?.update(sceneSize: size)
    }
    
    // Create UI
    
    private func setUpScene() {
        backgroundColor = SKColor.white
        
        // Create UI
        addUIPanel()
        addContainer()
        addPopoverNode()
        
        $lightLevel
            .map { lightLevel in
                if lightLevel == 0 {
                    return SKColor(white: 0, alpha: 1)
                }
                let brightness = 0.1 + (lightLevel / GlobalConstants.maxLightLevel) * 0.9 // Brightness from 0.2 to 1.0
                let color = SKColor(hue: 0.1667, saturation: 1, brightness: brightness, alpha: 1.0)
                
                return color
            }
            .assign(to: \.backgroundColor, on: self)
            .store(in: &cancellables)
    }
    
    private func addUIPanel() {
        let uiPanel = UIPanel(
            daysCount: $dayCount.eraseToAnyPublisher(),
            organismsCount: $organisms.map { $0.count }.eraseToAnyPublisher(),
            speed: $simulationSpeed.eraseToAnyPublisher(),
            lightLevel: $lightLevel.eraseToAnyPublisher(),
            dayProgress: $dayProgress.eraseToAnyPublisher(),
            gameState: $gameState.eraseToAnyPublisher(),
            onTapRestartButton: { [weak self] in
                self?.restartSimulation()
            },
            onTapIncreaseSpeed: { [weak self] in
                guard let self else { return }
                
                let newSpeed = self.simulationSpeed + 1
                self.simulationSpeed = min(newSpeed, 100)
            },
            onTapDecreaseSpeed: { [weak self] in
                guard let self else { return }
                
                let newSpeed = self.simulationSpeed - 1
                self.simulationSpeed = max(newSpeed, 0)
            },
            onTapPause: { [weak self] in
                guard let self, self.gameState != .stopped else {
                    return
                }
                
                self.gameState = self.gameState == .active ? .paused : .active
                
                if self.gameState == .paused {
                    cancelCurrentUpdate()
                }
            }
        )
        
        addChild(uiPanel)
        
        self.uiPanel = uiPanel
    }
    
    private func addContainer() {
        container = WaterContainer(
            color: NSColor(red: 116.0 / 255, green: 204.0 / 255, blue: 244.0 / 255, alpha: 0.7),
            size: CGSize(width: size.width, height: size.height - 200)
        )
        container.anchorPoint = CGPoint(x: 0, y: 0)
        container.position = .zero
        addChild(container)
    }
    
    private func addOrganisms() {
        for i in 0 ..< GlobalConstants.initialPopulation {
            let xPosition = CGFloat.random(in: 10...container.size.width - 10)
            let yPosition = CGFloat.random(in: 10...container.size.height - 10)
            let position = CGPoint(x: xPosition, y: yPosition)

            let baseColor = SKColor.green
            let logger: Logger = i == 0 ? ConsoleLogger() : EmptyLogger()
            let tracker = OrganismTracker(logger: logger)
            
            let model = OrganismModel(
                brain: NeuralBrain(),
                name: nameGenerator.generateName() ?? "\(i)",
                logger: logger,
                tracker: tracker
            ) { [weak self] model in
                let id = model.id
                
                self?.organismModels.removeValue(forKey: id)
                let organism = self?.organisms[id]
                organism?.removeFromParent()
                self?.organisms.removeValue(forKey: id)
            }

            let organism = Organism(
                model: model,
                position: position,
                color: baseColor,
                radius: 10
            ) { [weak self] organism in
                self?.showOrganismPopover(sceneLocation: organism.position, model: model)
            }
            organisms[model.id] = organism
            organismModels[model.id] = model
            container.addChild(organism)
        }
    }
    
    private func addPopoverNode() {
        // Initialize the popover
        popoverNode = CustomPopoverNode(title: "Title", details: "Details", size: CGSize(width: 200, height: 100))
        if let popover = popoverNode {
            addChild(popover)
        }
    }
    
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

    private func hidePopover() {
        infoPopover?.close()
    }
    
    // MARK: Control state
    
    private func restartSimulation() {
        // Stop updates
        gameState = .stopped

        cancelCurrentUpdate()
        
        // Reset variables
        totalTime = 0.0
        dayCount = 0
        lightLevel = 0
        
        // Remove existing organisms
        for (_, organism) in organisms {
            organism.removeFromParent()
        }
        organismModels.removeAll()
        organisms.removeAll()
        
        nameGenerator.regenerate()
        
        // Add new organisms
        addOrganisms()
        
        gameState = .active
    }
    
    // MARK: State updates
    
    private func gameTick() {
        // Calculate the current time in the day cycle
        let timeInDay = totalTime.truncatingRemainder(dividingBy: GlobalConstants.dayDuration)
        
        // Update light level (0 to 10 and back to 0)
        dayProgress = CGFloat(timeInDay / GlobalConstants.dayDuration)
        if dayProgress <= 0.25 {
            // Morning to noon (lightLevel increases from 0 to 10)
            lightLevel = GlobalConstants.maxLightLevel * (dayProgress * 4)
        } else if dayProgress <= 0.5 {
            // Noon to night (lightLevel decreases from 10 to 0)
            lightLevel = GlobalConstants.maxLightLevel * (1 - ((dayProgress - 0.25) * 4))
        } else {
            lightLevel = 0
        }
        
        speed = simulationSpeed
        dayCount = Int(totalTime) / Int(GlobalConstants.dayDuration)
        
        notifyOrganisms()
    }
    
    private func notifyOrganisms() {
        notificationTask = Task {
            try Task.checkCancellation()
            
            for (i, model) in organismModels.values.enumerated() {
                try Task.checkCancellation()
                
                guard let view = organisms[model.id] else {
                    print("\(i):Model \(model.id) should always pair with view")
                    return
                }
                view.speed = simulationSpeed
                let depth = normalizedDepth(for: view)
                let lightLevel = lightLevel(atDepth: depth)
                let input = await SensorInput(
                    lightLevel: lightLevel,
                    depth: depth,
                    dayProgress: dayProgress,
                    energy: model.energy
                )
                await model.handleChanges(input)
            }
        }
    }
    
    private func cancelCurrentUpdate() {
        notificationTask?.cancel()
        notificationTask = nil
        print("Update canceld")
    }
    
    // MARK: Utils
    
    // Normalized from 0 to 100
    private func normalizedDepth(for organism: Organism) -> CGFloat {
        normalizedDepth(atPositionY: organism.position.y)
    }
    
    // ln(depthLightLevel / surfaceLightLevel) / depth
    private let lightDecayRate = -0.0693147180559945
    
    // Inverse square law
    private func lightLevel(atDepth depth: CGFloat) -> CGFloat {
        return lightLevel * exp(depth * lightDecayRate)
    }
    
    private func normalizedDepth(atPositionY positionY: CGFloat) -> CGFloat {
        let maxDepth = container.size.height
        let currentDepth = maxDepth - positionY
        return currentDepth / maxDepth * GlobalConstants.maxDepth
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
        
        if let organismNode = nodesAtPoint.first(where: { $0 is Organism }) as? Organism {
            let model = organismModels[organismNode.id]!
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
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        popoverNode?.hide()
    }
}
#endif
