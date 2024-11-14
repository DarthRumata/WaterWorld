//
//  UIPanel.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/12/24.
//

import Combine
import SpriteKit

class UIPanel: SKNode {
    private let panelHeight: CGFloat = 200
    
    private var border: SKShapeNode
    
    // Indicators
    private var lightLevelLabel: SKLabelNode!
    private var dayCountLabel: SKLabelNode!
    private var organismCountLabel: SKLabelNode!
    
    // Controls
    private var restartButton: SKLabelNode!
    private var speedLabel: SKLabelNode!
    private var increaseSpeedButton: SKLabelNode!
    private var decreaseSpeedButton: SKLabelNode!
    
    // Actions
    let onTapRestartButton: () -> Void
    let onTapIncreaseSpeed: () -> Void
    let onTapDecreaseSpeed: () -> Void
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    init(
        daysCount: AnyPublisher<Int, Never>,
        organismsCount: AnyPublisher<Int, Never>,
        speed: AnyPublisher<TimeInterval, Never>,
        lightLevel: AnyPublisher<CGFloat, Never>,
        onTapRestartButton: @escaping () -> Void,
        onTapIncreaseSpeed: @escaping () -> Void,
        onTapDecreaseSpeed: @escaping () -> Void
    ) {
        let border = SKShapeNode()
        border.position = CGPoint(x: 0, y: 0)
        border.fillColor = .clear
        border.strokeColor = .red
        border.lineWidth = 2
        
        self.border = border
        self.onTapRestartButton = onTapRestartButton
        self.onTapIncreaseSpeed = onTapIncreaseSpeed
        self.onTapDecreaseSpeed = onTapDecreaseSpeed
        
        super.init()
        
        isUserInteractionEnabled = true
        
        addChild(border)
        addDayCountLabel()
        addOrganismCountLabel()
        addLightLevelLabel()
        addRestartLabel()
        addSpeedLabel()
        
        organismsCount
            .map {
                "Organisms: \($0)"
            }
            .assign(to: \.text, on: organismCountLabel)
            .store(in: &cancellables)
        
        daysCount
            .map {
                "Days: \($0)"
            }
            .assign(to: \.text, on: dayCountLabel)
            .store(in: &cancellables)
        
        speed
            .map {
                "Speed: \($0)"
            }
            .assign(to: \.text, on: speedLabel)
            .store(in: &cancellables)
        
        lightLevel
            .map {
                "Light Level: \($0)"
            }
            .assign(to: \.text, on: lightLevelLabel)
            .store(in: &cancellables)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(withSceneSize size: CGSize) {
        position = CGPoint(x: 0, y: size.height - panelHeight)
        border.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: panelHeight), transform: nil)
        lightLevelLabel.position = CGPoint(x: size.width / 2 , y: panelHeight - 40)
        restartButton.position = CGPoint(x: size.width - 150, y: panelHeight - 90)
        speedLabel.position = CGPoint(x: size.width - 150, y: panelHeight - 40)
        increaseSpeedButton.position = CGPoint(x: speedLabel.position.x + 70, y: panelHeight - 40)
        decreaseSpeedButton.position = CGPoint(x: speedLabel.position.x - 70, y: panelHeight - 40)
    }
    
    // Left
    
    private func addDayCountLabel() {
        dayCountLabel = SKLabelNode(fontNamed: "Helvetica")
        dayCountLabel.fontSize = 18
        dayCountLabel.fontColor = .white
        dayCountLabel.horizontalAlignmentMode = .left
        dayCountLabel.verticalAlignmentMode = .bottom
        dayCountLabel.position = CGPoint(x: 20, y: panelHeight - 40)
        dayCountLabel.zPosition = 100
        addChild(dayCountLabel)
    }
    
    func addOrganismCountLabel() {
        organismCountLabel = SKLabelNode(fontNamed: "Helvetica")
        organismCountLabel.fontSize = 18
        organismCountLabel.horizontalAlignmentMode = .left
        organismCountLabel.verticalAlignmentMode = .bottom
        organismCountLabel.fontColor = .white
        organismCountLabel.position = CGPoint(x: 20, y: panelHeight - 90)
        organismCountLabel.zPosition = 100
        organismCountLabel.text = "Organisms"
        addChild(organismCountLabel)
    }
    
    // Center
    
    private func addLightLevelLabel() {
        lightLevelLabel = SKLabelNode(fontNamed: "Helvetica")
        lightLevelLabel.fontSize = 18
        lightLevelLabel.fontColor = .white
        lightLevelLabel.position = CGPoint(x: 400, y: panelHeight - 20)
        lightLevelLabel.zPosition = 100
        addChild(lightLevelLabel)
    }
    
    // Right
    
    private func addRestartLabel() {
        restartButton = SKLabelNode(fontNamed: "Helvetica")
        restartButton.fontSize = 18
        restartButton.fontColor = .yellow
        restartButton.position = CGPoint(x: 1000, y: panelHeight - 20)
        restartButton.zPosition = 100
        restartButton.text = "Restart"
        addChild(restartButton)
    }

    private func addSpeedLabel() {
        speedLabel = SKLabelNode(fontNamed: "Helvetica")
        speedLabel.fontSize = 18
        speedLabel.fontColor = .yellow
        speedLabel.position = CGPoint(x: 1100, y: panelHeight - 50)
        speedLabel.zPosition = 100
        addChild(speedLabel)
        
        increaseSpeedButton = SKLabelNode(fontNamed: "Helvetica")
        increaseSpeedButton.fontSize = 18
        increaseSpeedButton.fontColor = .yellow
        increaseSpeedButton.position = CGPoint(x: 1200, y: panelHeight - 50)
        increaseSpeedButton.zPosition = 100
        increaseSpeedButton.text = "=>"
        addChild(increaseSpeedButton)
        
        decreaseSpeedButton = SKLabelNode(fontNamed: "Helvetica")
        decreaseSpeedButton.fontSize = 18
        decreaseSpeedButton.fontColor = .yellow
        decreaseSpeedButton.position = CGPoint(x: 1000, y: panelHeight - 50)
        decreaseSpeedButton.zPosition = 100
        decreaseSpeedButton.text = "<="
        addChild(decreaseSpeedButton)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let nodesAtPoint = nodes(at: location)

        if nodesAtPoint.contains(restartButton) {
            onTapRestartButton()
        } else if nodesAtPoint.contains(increaseSpeedButton) {
            onTapIncreaseSpeed()
        } else if nodesAtPoint.contains(decreaseSpeedButton) {
            onTapDecreaseSpeed()
        }
    }
}
