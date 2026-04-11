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
    static let timelineHeight: CGFloat = 6
    static let timelineWidth: CGFloat = 360
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
    private var reportButton: SKLabelNode!
    
    // Mode selector (segmented) and Predators intensity selector
    private var modeSelector: SegmentedControlNode!
    private var predatorsIntensitySelector: SegmentedControlNode!

    // Local state to coordinate UI actions
    private var currentMode: SimulationMode = .normal
    
    // Day/Night timeline UI
    private var timelineBar: SKShapeNode!
    private var sunNode: SKShapeNode!
    private var moonNode: SKShapeNode!
    private var starsNode: SKNode!
    private var timelineFrame: CGRect = .zero
    private var currentDayProgress: CGFloat = 0
    
    // Actions
    let onTapRestartButton: () -> Void
    let onTapIncreaseSpeed: () -> Void
    let onTapDecreaseSpeed: () -> Void
    let onTapPause: () -> Void
    let onTapReport: () -> Void
    let onTapToggleMode: () -> Void
    let onSelectPredatorIntensity: (PredatorsIntensity) -> Void
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    init(
        daysCount: AnyPublisher<Int, Never>,
        organismsCount: AnyPublisher<Int, Never>,
        speed: AnyPublisher<TimeInterval, Never>,
        lightLevel: AnyPublisher<Double, Never>,
        dayProgress: AnyPublisher<Double, Never>,
        gameState: AnyPublisher<GameState, Never>,
        simulationMode: AnyPublisher<SimulationMode, Never>,
        predatorsIntensity: AnyPublisher<PredatorsIntensity, Never>,
        onTapRestartButton: @escaping () -> Void,
        onTapIncreaseSpeed: @escaping () -> Void,
        onTapDecreaseSpeed: @escaping () -> Void,
        onTapPause: @escaping () -> Void,
        onTapReport: @escaping () -> Void,
        onTapToggleMode: @escaping () -> Void,
        onSelectPredatorIntensity: @escaping (PredatorsIntensity) -> Void
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
        self.onTapReport = onTapReport
        self.onTapToggleMode = onTapToggleMode
        self.onSelectPredatorIntensity = onSelectPredatorIntensity
        
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
        addReportButton()
        addTimeline()
        addModeControls()
        modeSelector.onSelectIndex = { [weak self] idx in
            guard let self else { return }
            let desired: SimulationMode = (idx == 0) ? .normal : .learning
            if self.currentMode != desired {
                self.onTapToggleMode()
            }
        }
        addPredatorsIntensityControl()

        organismsCount
            .map { "Org: \($0)" }
            .assign(to: \.text, on: organismCountLabel)
            .store(in: &cancellables)
        
        daysCount
            .map { "Day: \($0)" }
            .assign(to: \.text, on: dayCountLabel)
            .store(in: &cancellables)
        
        speed
            .map { String(format: "Spd: x%.1f", $0) }
            .assign(to: \.text, on: speedLabel)
            .store(in: &cancellables)
        
        lightLevel
            .map { String(format: "Light: %.1f", $0) }
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
                
                return "T: \(String(format: "%02d", correctedHours)):\(String(format: "%02d", minutes))"
            }
            .assign(to: \.text, on: timeLabel)
            .store(in: &cancellables)
        
        dayProgress
            .sink { [weak self] progress in
                guard let self else { return }
                let p = CGFloat(progress)
                self.currentDayProgress = p
                self.updateTimeline(progress: p)
            }
            .store(in: &cancellables)
        
        gameState
            .sink { [weak self] state in
                guard let self else { return }
                self.pauseButton?.fontColor = state == .stopped ? .gray : Constants.textColor
                self.pauseButton?.text = state == .active ? "Pause" : "Resume"
            }
            .store(in: &cancellables)
        
        simulationMode
            .sink { [weak self] mode in
                guard let self else { return }
                self.currentMode = mode
                let idx = (mode == .normal) ? 0 : 1
                self.modeSelector?.setSelectedIndex(idx, animated: true)
            }
            .store(in: &cancellables)
        
        predatorsIntensity
            .sink { [weak self] intensity in
                let idx = intensity.rawValue
                self?.predatorsIntensitySelector?.setSelectedIndex(idx, animated: true)
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
        
        // Right-aligned vertical stack for controls
        let rightMargin: CGFloat = 16
        let rightX = size.width - rightMargin
        var y = Constants.panelHeight - 30

        // Restart (top)
        restartButton.position = CGPoint(x: rightX, y: y)
        y -= 24

        // Pause under Restart
        pauseButton.position = CGPoint(x: rightX, y: y)
        y -= 28

        reportButton.position = CGPoint(x: rightX, y: y)
        y -= 28

        // Mode (segmented control) — width 110, align right edge to panel
        modeSelector.position = CGPoint(x: rightX - 110, y: y - 13)
        y -= 30

        // Predator intensity selector (fits 160 width)
        predatorsIntensitySelector.position = CGPoint(x: rightX - 160, y: y - 12)
        y -= 30

        // Speed label (right-aligned)
        speedLabel.position = CGPoint(x: rightX, y: y)
        y -= 22
        // Arrows on a separate row under the label
        increaseSpeedButton.position = CGPoint(x: rightX, y: y)
        decreaseSpeedButton.position = CGPoint(x: rightX - 40, y: y)
        y -= 24

        updateTimelineLayout(size: size)
        updateTimeline(progress: currentDayProgress)
    }
    
    // Left
    
    private func addDayCountLabel() {
        dayCountLabel = SKLabelNode(fontNamed: "Helvetica")
        dayCountLabel.fontSize = 18
        dayCountLabel.fontColor = Constants.textColor
        dayCountLabel.horizontalAlignmentMode = .left
        dayCountLabel.verticalAlignmentMode = .bottom
        dayCountLabel.zPosition = 100
        dayCountLabel.text = "Day: 0"
        addChild(dayCountLabel)
    }
    
    func addOrganismCountLabel() {
        organismCountLabel = SKLabelNode(fontNamed: "Helvetica")
        organismCountLabel.fontSize = 18
        organismCountLabel.horizontalAlignmentMode = .left
        organismCountLabel.verticalAlignmentMode = .bottom
        organismCountLabel.fontColor = Constants.textColor
        organismCountLabel.zPosition = 100
        organismCountLabel.text = "Org: 0"
        addChild(organismCountLabel)
    }
    
    // Center

    private func addLightLevelLabel() {
        lightLevelLabel = SKLabelNode(fontNamed: "Helvetica")
        lightLevelLabel.fontSize = 18
        lightLevelLabel.fontColor = Constants.textColor
        lightLevelLabel.zPosition = 100
        lightLevelLabel.text = "Light: 0.0"
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
        restartButton.horizontalAlignmentMode = .right
        addChild(restartButton)
    }

    private func addSpeedLabel() {
        speedLabel = SKLabelNode(fontNamed: "Helvetica")
        speedLabel.fontSize = 18
        speedLabel.fontColor = Constants.textColor
        speedLabel.horizontalAlignmentMode = .right
        speedLabel.zPosition = 100
        speedLabel.text = "Spd: x1.0"
        addChild(speedLabel)
        
        increaseSpeedButton = SKLabelNode(fontNamed: "Helvetica")
        increaseSpeedButton.fontSize = 18
        increaseSpeedButton.fontColor = Constants.textColor
        increaseSpeedButton.horizontalAlignmentMode = .right
        increaseSpeedButton.zPosition = 100
        increaseSpeedButton.text = "=>"
        addChild(increaseSpeedButton)
        
        decreaseSpeedButton = SKLabelNode(fontNamed: "Helvetica")
        decreaseSpeedButton.fontSize = 18
        decreaseSpeedButton.fontColor = Constants.textColor
        decreaseSpeedButton.horizontalAlignmentMode = .right
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
        pauseButton.horizontalAlignmentMode = .right
        addChild(pauseButton)
    }
    
    private func addReportButton() {
        reportButton = SKLabelNode(fontNamed: "Helvetica")
        reportButton.fontSize = 18
        reportButton.fontColor = Constants.textColor
        reportButton.zPosition = 100
        reportButton.text = "Report"
        reportButton.horizontalAlignmentMode = .right
        addChild(reportButton)
    }
    
    private func addModeControls() {
        modeSelector = SegmentedControlNode(
            size: CGSize(width: 110, height: 26),
            segments: [
                .init(title: "Normal"),
                .init(title: "Learning")
            ],
            selectedIndex: 0
        )
        modeSelector.zPosition = 100
        addChild(modeSelector)
    }
    
    private func addPredatorsIntensityControl() {
        predatorsIntensitySelector = SegmentedControlNode(
            size: CGSize(width: 160, height: 26),
            segments: [
                .init(title: "Off"),
                .init(title: "Low"),
                .init(title: "Med"),
                .init(title: "High")
            ],
            selectedIndex: 0
        )
        predatorsIntensitySelector.zPosition = 100
        addChild(predatorsIntensitySelector)

        predatorsIntensitySelector.onSelectIndex = { [weak self] idx in
            guard let self else { return }
            let all = PredatorsIntensity.allCases
            guard idx >= 0, idx < all.count else { return }
            self.onSelectPredatorIntensity(all[idx])
        }
    }
    
    private func addTimeline() {
        // Timeline bar
        timelineBar = SKShapeNode()
        timelineBar.fillColor = .clear
        timelineBar.strokeColor = Constants.textColor.withAlphaComponent(0.6)
        timelineBar.lineWidth = Constants.timelineHeight
        timelineBar.zPosition = 100
        addChild(timelineBar)

        // Sun node
        sunNode = SKShapeNode(circleOfRadius: 8)
        sunNode.fillColor = SKColor(hue: 0.13, saturation: 0.9, brightness: 1.0, alpha: 1)
        sunNode.strokeColor = .clear
        sunNode.glowWidth = 4
        sunNode.zPosition = 101
        addChild(sunNode)

        // Moon node
        moonNode = SKShapeNode(circleOfRadius: 7)
        moonNode.fillColor = SKColor(hue: 0.6, saturation: 0.1, brightness: 0.95, alpha: 1)
        moonNode.strokeColor = .clear
        moonNode.glowWidth = 2
        moonNode.alpha = 0
        moonNode.zPosition = 101
        addChild(moonNode)

        // Stars container
        starsNode = SKNode()
        starsNode.zPosition = 100
        starsNode.alpha = 0
        addChild(starsNode)
    }
    
    private func updateTimelineLayout(size: CGSize) {
        // Center the timeline horizontally in the panel, near the bottom
        let width = min(Constants.timelineWidth, size.width * 0.8)
        let centerX = size.width / 2
        let centerY: CGFloat = 30 // 30pt from bottom of panel
        let start = CGPoint(x: centerX - width / 2, y: centerY)
        let end =   CGPoint(x: centerX + width / 2, y: centerY)

        // Store frame for later mapping
        timelineFrame = CGRect(x: start.x, y: centerY - Constants.timelineHeight / 2, width: width, height: Constants.timelineHeight)

        // Update timeline bar path
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        timelineBar.path = path

        // (Re)generate stars if empty, and position within an area above the bar
        if starsNode.children.isEmpty {
            let starCount = 24
            for _ in 0..<starCount {
                let star = SKShapeNode(circleOfRadius: 1.5)
                star.fillColor = SKColor(white: 1.0, alpha: 0.9)
                star.strokeColor = .clear
                star.zPosition = 100
                starsNode.addChild(star)
            }
        }
        // Position stars randomly within a band above the timeline
        let starBand = CGRect(x: timelineFrame.minX, y: timelineFrame.minY + 10, width: timelineFrame.width, height: 30)
        for star in starsNode.children {
            let rx = CGFloat.random(in: starBand.minX...starBand.maxX)
            let ry = CGFloat.random(in: starBand.minY...starBand.maxY)
            star.position = CGPoint(x: rx, y: ry)
        }
    }

    private func updateTimeline(progress p: CGFloat) {
        guard timelineFrame.width > 0 else { return }

        let startX = timelineFrame.minX
        let endX = timelineFrame.maxX
        let y = timelineFrame.midY

        // Night factor: 0 at sunset (0.5), 1 at midnight (0.75), remains 1 until sunrise then fades
        let nightFactor = max(0, min((p - 0.5) * 2, 1))
        starsNode.alpha = nightFactor

        if p <= 0.5 {
            // Sun travels left -> right during day
            let t = p / 0.5 // 0..1
            let x = startX + (endX - startX) * t
            sunNode.alpha = 1
            sunNode.position = CGPoint(x: x, y: y)

            moonNode.alpha = 0
        } else {
            // Moon travels left -> right during night
            let t = (p - 0.5) / 0.5 // 0..1
            let x = startX + (endX - startX) * t
            moonNode.alpha = 1
            moonNode.position = CGPoint(x: x, y: y)

            sunNode.alpha = 0
        }
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
        } else if nodesAtPoint.contains(reportButton) {
            onTapReport()
        }
        // modeSelector handles its own mouseDown, so no need to handle here
    }
}

