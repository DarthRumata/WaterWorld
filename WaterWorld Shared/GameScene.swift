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
    static let dayDuration: TimeInterval = 20.0 // Total duration of one day cycle in seconds
}

class GameScene: SKScene {
    // Global state
    @Published var lightLevel: CGFloat = 0 // Ranges from 0 to 10
    @Published var dayCount: Int = 0
    @Published var simulationSpeed: TimeInterval = 1.0 // Default speed
    @Published var totalTime: TimeInterval = 0.0 // Keeps track of elapsed time
    @Published var lastUpdateTime: TimeInterval?
    @Published var lastTimeInDay: TimeInterval = 0.0
    
    // UI
    private var uiPanel: UIPanel?
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    @Published private var organisms = [Organism]()

    class func newGameScene() -> GameScene {
        // Load 'GameScene.sks' as an SKScene.
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
            print("Failed to load GameScene.sks")
            abort()
        }
        
        // Set the scale mode to scale to fit the window
        scene.scaleMode = .resizeFill
        
        return scene
    }
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        setUpScene()
        
        print("Scene size: \(size)")
        print("View size: \(view.bounds.size)")
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Calculate delta time
        let deltaTime = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime
        
        // Update total time considering simulation speed
        totalTime += deltaTime * TimeInterval(simulationSpeed)
        
        // Calculate the current time in the day cycle
        let timeInDay = totalTime.truncatingRemainder(dividingBy: Constants.dayDuration)
        
        // Update light level (0 to 10 and back to 0)
        let progress = CGFloat(timeInDay / Constants.dayDuration)
        if progress <= 0.5 {
            // Morning to noon (lightLevel increases from 0 to 10)
            lightLevel = Constants.maxLightLevel * (progress * 2)
        } else {
            // Noon to night (lightLevel decreases from 10 to 0)
            lightLevel = Constants.maxLightLevel * (1 - ((progress - 0.5) * 2))
        }
        
        // Check if a new day has started
        if timeInDay < lastTimeInDay {
            dayCount += 1
        }
        lastTimeInDay = timeInDay
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        print("Scene size changed from \(oldSize) to \(size)")
        
        // Update positions of UI elements if necessary
        uiPanel?.update(withSceneSize: size)
    }
    
    // Create UI
    
    func setUpScene() {
        backgroundColor = SKColor.cyan
        
        // Create UI
        addUIPanel()
       
        addOrganisms()
    }
    
    private func addUIPanel() {
        let uiPanel = UIPanel(
            daysCount: $dayCount.eraseToAnyPublisher(),
            organismsCount: $organisms.map { $0.count }.eraseToAnyPublisher(),
            speed: $simulationSpeed.eraseToAnyPublisher(),
            lightLevel: $lightLevel.eraseToAnyPublisher(),
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
            }
        )
        
        addChild(uiPanel)
        
        self.uiPanel = uiPanel
    }
    
    private func addOrganisms() {
        for _ in 0 ..< 10 {
            let xPosition = CGFloat.random(in: 0...size.width)
            let yPosition = CGFloat.random(in: size.height * 0.2...size.height * 0.8)
            let position = CGPoint(x: xPosition, y: yPosition)
            
            print("pos: \(position)")

            let randomColor = SKColor(hue: CGFloat.random(in: 0...1),
                                      saturation: 0.8,
                                      brightness: 0.9,
                                      alpha: 1.0)
            let sizeVariation = CGFloat.random(in: 0.8...1.2) * 20.0

            let organism = Organism(position: position, color: randomColor, radius: sizeVariation)
            organisms.append(organism)
            addChild(organism)
           // organism.startMovement()
        }
    }
    
    // Update UI
    func updateBackgroundColor() {
        // Calculate color based on light level
        let brightness = 0.2 + (lightLevel / Constants.maxLightLevel) * 0.8 // Brightness from 0.2 to 1.0
        let color = SKColor(hue: 0.6, saturation: 0.5, brightness: brightness, alpha: 1.0)
        
        backgroundColor = color
    }
    
    // Control state
    func restartSimulation() {
        // Reset variables
        totalTime = 0.0
        dayCount = 0
        lastTimeInDay = 0.0
        lightLevel = 0
        
        // Remove existing organisms
        for node in children {
            if node is Organism {
                node.removeFromParent()
            }
        }
        
        // Add new organisms
        addOrganisms()
    }
}

#if os(OSX)
// Mouse-based event handling
extension GameScene {
    override func mouseDown(with event: NSEvent) {
       
    }
    
    override func mouseDragged(with event: NSEvent) {}
    
    override func mouseUp(with event: NSEvent) {}
}
#endif
