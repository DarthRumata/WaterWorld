//
//  GameScene.swift
//  WaterWorld Shared
//
//  Created by Stas Kirichok on 11/11/24.
//

import Combine
import SpriteKit

private enum Constants {
    static let maxLightLevel: CGFloat = 10
    static let dayDuration: TimeInterval = 24.0 // Total duration of one day cycle in seconds
    static let initialPopulation = 100
}

class GameScene: SKScene {
    // Global state
    @Published var lightLevel: CGFloat = 0 // Ranges from 0 to 10
    @Published var dayCount: Int = 0
    @Published var simulationSpeed: TimeInterval = 1.0 // Default speed
    @Published var totalTime: TimeInterval = 0.0 // Keeps track of elapsed time
    @Published var lastUpdateTime: TimeInterval?
    @Published var dayProgress: CGFloat = 0
    @Published var gameState: GameState = .stopped
    
    // UI
    private var uiPanel: UIPanel?
    private var container: WaterContainer!
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    @Published private var organisms = [UUID: Organism]()
    private var organismModels = [UUID: OrganismModel]()

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
        
        //print("Scene size: \(size)")
        //print("View size: \(view.bounds.size)")
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime
        
        guard gameState == .active else {
            return
        }
        // Update total time considering simulation speed
        totalTime += deltaTime * TimeInterval(simulationSpeed)
        
        // Calculate the current time in the day cycle
        let timeInDay = totalTime.truncatingRemainder(dividingBy: Constants.dayDuration)
        
        // Update light level (0 to 10 and back to 0)
        dayProgress = CGFloat(timeInDay / Constants.dayDuration)
        if dayProgress <= 0.25 {
            // Morning to noon (lightLevel increases from 0 to 10)
            lightLevel = Constants.maxLightLevel * (dayProgress * 4)
        } else if dayProgress <= 0.5 {
            // Noon to night (lightLevel decreases from 10 to 0)
            lightLevel = Constants.maxLightLevel * (1 - ((dayProgress - 0.25) * 4))
        } else {
            lightLevel = 0
        }
        
        speed = simulationSpeed
        dayCount = Int(totalTime) / Int(Constants.dayDuration)
        
        notifyOrganisms()
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
        
        $lightLevel
            .map { lightLevel in
                if lightLevel == 0 {
                    return SKColor(white: 0, alpha: 1)
                }
                let brightness = 0.1 + (lightLevel / Constants.maxLightLevel) * 0.9 // Brightness from 0.2 to 1.0
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
        for i in 0 ..< Constants.initialPopulation {
            let xPosition = CGFloat.random(in: 10...container.size.width - 10)
            let yPosition = CGFloat.random(in: 10...container.size.height - 10)
            let position = CGPoint(x: xPosition, y: yPosition)
            
            print("pos: \(position)")

            let baseColor = SKColor.green
            
            let model = OrganismModel(brain: RandomBrain()) { [weak self] id in
                self?.organismModels.removeValue(forKey: id)
                let organism = self?.organisms[id]
                organism?.removeFromParent()
                self?.organisms.removeValue(forKey: id)
            }

            let organism = Organism(model: model, position: position, color: baseColor, radius: 10) {
                print("Organism index: \(i)")
                $0.moveDown()
            }
            organisms[model.id] = organism
            organismModels[model.id] = model
            container.addChild(organism)
        }
    }
    
    // Control state
    private func restartSimulation() {
        // Reset variables
        totalTime = 0.0
        dayCount = 0
        lightLevel = 0
        
        // Remove existing organisms
        organisms.forEach { (_, organism) in
            organism.removeFromParent()
        }
        organismModels.removeAll()
        organisms.removeAll()
        
        // Add new organisms
        addOrganisms()
        
        gameState = .active
    }
    
    // State updates
    
    private func notifyOrganisms() {
        for model in organismModels.values {
            Task {
                guard let view = organisms[model.id] else { fatalError("Model should always pair with view") }
                let depth = normalizedDepth(for: view)
                let lightLevel = lightLevel(atDepth: depth)
                let input = SensorInput(lightLevel: lightLevel, depth: depth, totalTimeElapsed: totalTime)
                await model.handleChanges(input)
            }
        }
    }
    
    // Normalized from 0 to 100
    private func normalizedDepth(for organism: Organism) -> CGFloat {
        let maxDepth = container.size.height
        let currentDepth = maxDepth - organism.position.y
        return currentDepth / maxDepth * 100
    }
    
    // ln(depthLightLevel / surfaceLightLevel) / depth
    private let lightDecayRate = -0.0693147180559945
    
    // Inverse square law
    private func lightLevel(atDepth depth: CGFloat) -> CGFloat {
        return lightLevel * exp(depth * lightDecayRate)
    }
}

#if os(OSX)
// Mouse-based event handling
extension GameScene {
    override func mouseDown(with event: NSEvent) {}
    
    override func mouseDragged(with event: NSEvent) {}
    
    override func mouseUp(with event: NSEvent) {}
}
#endif
