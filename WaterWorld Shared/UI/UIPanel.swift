//
//  UIPanel.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 11/12/24.
//

import Combine
import SpriteKit

private enum Constants {
    static let panelHeight: CGFloat = 200
    static let backgroundColor = SKColor(white: 0.9, alpha: 0.7)
    static let textColor = SKColor(white: 0.1, alpha: 1)
}

class UIPanel: SKNode {
    private var border: SKShapeNode
    
    // Indicators
    private var lightLevelLabel: SKLabelNode!
    private var dayCountLabel: SKLabelNode!
    private var organismCountLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    
    // Controls
    private var restartButton: SKLabelNode!
    private var speedLabel: SKLabelNode!
    private var increaseSpeedButton: SKLabelNode!
    private var decreaseSpeedButton: SKLabelNode!
    private var pauseButton: SKLabelNode!
    
    // Actions
    let onTapRestartButton: () -> Void
    let onTapIncreaseSpeed: () -> Void
    let onTapDecreaseSpeed: () -> Void
    let onTapPause: () -> Void
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    init(
        daysCount: AnyPublisher<Int, Never>,
        organismsCount: AnyPublisher<Int, Never>,
        speed: AnyPublisher<TimeInterval, Never>,
        lightLevel: AnyPublisher<Double, Never>,
        dayProgress: AnyPublisher<Double, Never>,
        gameState: AnyPublisher<GameState, Never>,
        onTapRestartButton: @escaping () -> Void,
        onTapIncreaseSpeed: @escaping () -> Void,
        onTapDecreaseSpeed: @escaping () -> Void,
        onTapPause: @escaping () -> Void
    ) {
        let border = SKShapeNode()
        border.position = CGPoint(x: 0, y: 0)
        border.fillColor = Constants.backgroundColor
        border.strokeColor = .white
        border.lineWidth = 3
        
        self.border = border
        self.onTapRestartButton = onTapRestartButton
        self.onTapIncreaseSpeed = onTapIncreaseSpeed
        self.onTapDecreaseSpeed = onTapDecreaseSpeed
        self.onTapPause = onTapPause
        
        super.init()
        
        isUserInteractionEnabled = true
        
        addChild(border)
        addDayCountLabel()
        addOrganismCountLabel()
        addLightLevelLabel()
        addTimeLabel()
        addRestartLabel()
        addSpeedLabel()
        addPauseButton()
        
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
                "Light Level: \(String(format: "%.2f", $0))"
            }
            .assign(to: \.text, on: lightLevelLabel)
            .store(in: &cancellables)
        
        dayProgress
            .map { progress in
                let hours = 24 * progress
                let wholeHours: CGFloat = floor(hours)
                // Sunrise at 7.00 Sunset 19.00
                let correctedHours = Int((wholeHours + 7).truncatingRemainder(dividingBy: 24))
                let reminder = hours - wholeHours
                let minutes = Int(60 * reminder)
                
                
                return "Time: \(String(format: "%02d", correctedHours)):\(String(format: "%02d", minutes))"
            }
            .assign(to: \.text, on: timeLabel)
            .store(in: &cancellables)
        
        gameState
            .sink { [pauseButton] state in
                pauseButton?.fontColor = state == .stopped ? .gray : Constants.textColor
                pauseButton?.text = state == .active ? "Pause" : "Resume"
            }
            .store(in: &cancellables)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(withSceneSize size: CGSize) {
        position = CGPoint(x: 0, y: size.height - Constants.panelHeight)
        border.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: Constants.panelHeight), transform: nil)
        dayCountLabel.position = CGPoint(x: 10 , y: Constants.panelHeight - 40)
        organismCountLabel.position = CGPoint(x: 10 , y: Constants.panelHeight - 90)
        lightLevelLabel.position = CGPoint(x: size.width / 2 , y: Constants.panelHeight - 40)
        timeLabel.position = CGPoint(x: size.width / 2 , y: Constants.panelHeight - 90)
        restartButton.position = CGPoint(x: size.width - 150, y: Constants.panelHeight - 90)
        speedLabel.position = CGPoint(x: size.width - 150, y: Constants.panelHeight - 40)
        increaseSpeedButton.position = CGPoint(x: speedLabel.position.x + 70, y: Constants.panelHeight - 40)
        decreaseSpeedButton.position = CGPoint(x: speedLabel.position.x - 70, y: Constants.panelHeight - 40)
        pauseButton.position = CGPoint(x: speedLabel.position.x, y: Constants.panelHeight - 140)
    }
    
    // Left
    
    private func addDayCountLabel() {
        dayCountLabel = SKLabelNode(fontNamed: "Helvetica")
        dayCountLabel.fontSize = 18
        dayCountLabel.fontColor = Constants.textColor
        dayCountLabel.horizontalAlignmentMode = .left
        dayCountLabel.verticalAlignmentMode = .bottom
        dayCountLabel.zPosition = 100
        addChild(dayCountLabel)
    }
    
    func addOrganismCountLabel() {
        organismCountLabel = SKLabelNode(fontNamed: "Helvetica")
        organismCountLabel.fontSize = 18
        organismCountLabel.horizontalAlignmentMode = .left
        organismCountLabel.verticalAlignmentMode = .bottom
        organismCountLabel.fontColor = Constants.textColor
        organismCountLabel.zPosition = 100
        organismCountLabel.text = "Organisms"
        addChild(organismCountLabel)
    }
    
    // Center
    
    private func addLightLevelLabel() {
        lightLevelLabel = SKLabelNode(fontNamed: "Helvetica")
        lightLevelLabel.fontSize = 18
        lightLevelLabel.fontColor = Constants.textColor
        lightLevelLabel.zPosition = 100
        addChild(lightLevelLabel)
    }
    
    private func addTimeLabel() {
        timeLabel = SKLabelNode(fontNamed: "Helvetica")
        timeLabel.fontSize = 18
        timeLabel.fontColor = Constants.textColor
        timeLabel.zPosition = 100
        addChild(timeLabel)
    }
    
    // Right
    
    private func addRestartLabel() {
        restartButton = SKLabelNode(fontNamed: "Helvetica")
        restartButton.fontSize = 18
        restartButton.fontColor = Constants.textColor
        restartButton.position = CGPoint(x: 1000, y: Constants.panelHeight - 20)
        restartButton.zPosition = 100
        restartButton.text = "Restart"
        addChild(restartButton)
    }

    private func addSpeedLabel() {
        speedLabel = SKLabelNode(fontNamed: "Helvetica")
        speedLabel.fontSize = 18
        speedLabel.fontColor = Constants.textColor
        speedLabel.zPosition = 100
        addChild(speedLabel)
        
        increaseSpeedButton = SKLabelNode(fontNamed: "Helvetica")
        increaseSpeedButton.fontSize = 18
        increaseSpeedButton.fontColor = Constants.textColor
        increaseSpeedButton.zPosition = 100
        increaseSpeedButton.text = "=>"
        addChild(increaseSpeedButton)
        
        decreaseSpeedButton = SKLabelNode(fontNamed: "Helvetica")
        decreaseSpeedButton.fontSize = 18
        decreaseSpeedButton.fontColor = Constants.textColor
        decreaseSpeedButton.zPosition = 100
        decreaseSpeedButton.text = "<="
        addChild(decreaseSpeedButton)
    }
    
    private func addPauseButton() {
        pauseButton = SKLabelNode(fontNamed: "Helvetica")
        pauseButton.fontSize = 18
        pauseButton.fontColor = Constants.textColor
        pauseButton.zPosition = 100
        pauseButton.text = "Pause"
        addChild(pauseButton)
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
        } else if nodesAtPoint.contains(pauseButton) {
            onTapPause()
        }
    }
}
