import Foundation
import SpriteKit

/// A simple graphical toggle switch for SpriteKit (macOS) with an optional title.
final class ToggleSwitchNode: SKNode {
    enum TitlePlacement { case left, top }

    private let background: SKShapeNode
    private let knob: SKShapeNode
    private let sizeValue: CGSize

    private var titleNode: SKLabelNode?
    private var titlePlacement: TitlePlacement

    private(set) var isOn: Bool = false
    var onToggle: (() -> Void)?

    init(size: CGSize, title: String? = nil, titlePlacement: TitlePlacement = .left) {
        self.sizeValue = size
        self.titlePlacement = titlePlacement
        let rect = CGRect(origin: .zero, size: size)
        let cornerRadius = size.height / 2

        background = SKShapeNode(rect: rect, cornerRadius: cornerRadius)
        background.fillColor = SKColor(white: 0.75, alpha: 1)
        background.strokeColor = .clear
        background.zPosition = 1

        knob = SKShapeNode(circleOfRadius: size.height / 2 - 2)
        knob.fillColor = .white
        knob.strokeColor = .clear
        knob.zPosition = 2

        super.init()
        isUserInteractionEnabled = true

        addChild(background)
        addChild(knob)

        if let title = title {
            let label = SKLabelNode(fontNamed: "Helvetica")
            label.fontSize = 14
            label.fontColor = SKColor(white: 0.1, alpha: 1)
            label.zPosition = 3
            label.text = title
            label.verticalAlignmentMode = .center
            addChild(label)
            self.titleNode = label
        }

        // Start in OFF position
        layout(animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setOn(_ on: Bool, animated: Bool) {
        guard isOn != on else { return }
        isOn = on
        layout(animated: animated)
    }

    func setTitle(_ title: String?) {
        if let t = title {
            if let titleNode {
                titleNode.text = t
            } else {
                let label = SKLabelNode(fontNamed: "Helvetica")
                label.fontSize = 14
                label.fontColor = SKColor(white: 0.1, alpha: 1)
                label.zPosition = 3
                label.text = t
                label.verticalAlignmentMode = .center
                addChild(label)
                self.titleNode = label
            }
        } else {
            titleNode?.removeFromParent()
            titleNode = nil
        }
        layout(animated: false)
    }

    func setTitlePlacement(_ placement: TitlePlacement) {
        self.titlePlacement = placement
        layout(animated: false)
    }

    private func layout(animated: Bool) {
        // Layout knob position and background color
        let knobY = sizeValue.height / 2
        let padding: CGFloat = 2
        let knobRadius = knob.frame.width / 2
        let offX = padding + knobRadius
        let onX = sizeValue.width - padding - knobRadius

        let targetX = isOn ? onX : offX
        let bgColor = isOn ? SKColor(hue: 0.33, saturation: 0.7, brightness: 0.8, alpha: 1) : SKColor(white: 0.75, alpha: 1)

        let move = SKAction.move(to: CGPoint(x: targetX, y: knobY), duration: animated ? 0.12 : 0)
        let colorize = SKAction.customAction(withDuration: animated ? 0.12 : 0) { [weak self] _, _ in
            self?.background.fillColor = bgColor
        }
        knob.run(move)
        background.run(colorize)

        // Layout title relative to the switch
        if let titleNode {
            switch titlePlacement {
            case .left:
                titleNode.horizontalAlignmentMode = .right
                titleNode.verticalAlignmentMode = .center
                // Place title 8pt to the left of the switch background
                titleNode.position = CGPoint(x: -8, y: sizeValue.height / 2)
            case .top:
                titleNode.horizontalAlignmentMode = .center
                titleNode.verticalAlignmentMode = .bottom
                // Place title 4pt above the switch background
                titleNode.position = CGPoint(x: sizeValue.width / 2, y: sizeValue.height + 4)
            }
        }
    }

    #if os(OSX)
    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        layout(animated: true)
        onToggle?()
    }
    #endif
}
