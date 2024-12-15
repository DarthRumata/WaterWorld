//
//  CustomPopoverNode.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/12/24.
//


import SpriteKit

class CustomPopoverNode: SKNode {
    private let backgroundNode: SKShapeNode
    private let titleLabel: SKLabelNode
    private let detailLabel: SKLabelNode

    init(title: String, details: String, size: CGSize = CGSize(width: 200, height: 100)) {
        // Background shape
        let rect = CGRect(origin: .zero, size: size)
        backgroundNode = SKShapeNode(rect: rect, cornerRadius: 10)
        backgroundNode.fillColor = .darkGray
        backgroundNode.strokeColor = .black
        backgroundNode.lineWidth = 2

        // Title label
        titleLabel = SKLabelNode(text: title)
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 16
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 30)
        titleLabel.horizontalAlignmentMode = .center

        // Detail label
        detailLabel = SKLabelNode(text: details)
        detailLabel.fontName = "Helvetica"
        detailLabel.fontSize = 14
        detailLabel.fontColor = .white
        detailLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 10)
        detailLabel.horizontalAlignmentMode = .center

        super.init()

        // Add background and labels as children
        addChild(backgroundNode)
        addChild(titleLabel)
        addChild(detailLabel)

        // Set initial visibility to hidden
        isHidden = true
        zPosition = 100 // Ensure it appears above other nodes
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Show the popover at a specific position
    func show(at position: CGPoint, in parent: SKNode, title: String, details: String) {
        var position = position
        if position.x >= parent.frame.width - backgroundNode.frame.width {
            position = CGPoint(x: position.x - backgroundNode.frame.width, y: position.y)
        }
        if position.y >= parent.frame.height - backgroundNode.frame.height {
            position = CGPoint(x: position.x, y: position.y - backgroundNode.frame.height)
        }
        self.position = position
        titleLabel.text = title
        detailLabel.text = details
        isHidden = false

        // Add the popover to the parent node
        if parent != self.parent {
            parent.addChild(self)
        }
    }

    // Hide the popover
    func hide() {
        isHidden = true
        removeFromParent()
    }
}
