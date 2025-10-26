import SpriteKit

final class SegmentedControlNode: SKNode {
    struct Segment { let title: String }

    private let background: SKShapeNode
    private var highlight: SKShapeNode?
    private var labelNodes: [SKLabelNode] = []
    private let segments: [Segment]
    private let sizeValue: CGSize
    private(set) var selectedIndex: Int

    var onSelectIndex: ((Int) -> Void)?

    init(size: CGSize, segments: [Segment], selectedIndex: Int = 0) {
        self.sizeValue = size
        self.segments = segments
        self.selectedIndex = max(0, min(selectedIndex, max(0, segments.count - 1)))

        background = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2)
        background.fillColor = SKColor(white: 0.85, alpha: 1)
        background.strokeColor = .clear

        super.init()
        isUserInteractionEnabled = true

        addChild(background)
        buildSegments()
        layoutSegments(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index != selectedIndex, index >= 0, index < segments.count else { return }
        selectedIndex = index
        layoutSegments(animated: animated)
    }

    private func buildSegments() {
        let segmentWidth = sizeValue.width / CGFloat(max(1, segments.count))
        for i in 0..<segments.count {
            let label = SKLabelNode(fontNamed: "Helvetica")
            label.fontSize = 13
            label.fontColor = SKColor(white: 0.1, alpha: 1)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.text = segments[i].title
            label.position = CGPoint(x: (CGFloat(i) + 0.5) * segmentWidth, y: sizeValue.height / 2)
            label.zPosition = 2
            addChild(label)
            labelNodes.append(label)
        }
    }

    private func layoutSegments(animated: Bool) {
        let segmentWidth = sizeValue.width / CGFloat(max(1, segments.count))
        let x = CGFloat(selectedIndex) * segmentWidth
        let rect = CGRect(x: x + 2, y: 2, width: segmentWidth - 4, height: sizeValue.height - 4)

        highlight?.removeFromParent()
        let hl = SKShapeNode(rect: rect, cornerRadius: rect.height / 2)
        hl.fillColor = SKColor(hue: 0.6, saturation: 0.15, brightness: 1.0, alpha: 1)
        hl.strokeColor = .clear
        hl.zPosition = 1
        addChild(hl)
        highlight = hl
    }

    #if os(OSX)
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        let segmentWidth = sizeValue.width / CGFloat(max(1, segments.count))
        guard location.x >= 0, location.x <= sizeValue.width else { return }
        let index = Int(location.x / segmentWidth)
        setSelectedIndex(index, animated: true)
        onSelectIndex?(index)
    }
    #endif
}
