//
//  QLearningReportView.swift
//  WaterWorld macOS
//
//  A simple macOS SpriteKit-free view to present QLearningStep data in a table.
//

import SwiftUI

private struct IndexedExperience: Identifiable {
    let index: Int
    let experience: QLearningExperience
    var id: UUID { experience.id }

    var energy: Double { experience.state.energy }
    var reward: Double { experience.reward }
    var actionIndex: Int { experience.actionIndex }
    var nextEnergy: Double { experience.nextState?.energy ?? -1 }
    var brainPrefix: String { String(experience.brainId.uuidString.prefix(8).lowercased()) }
}

private let pageSize = 5000

struct QLearningReportView: View {
    private let store = QLearningStore.shared
    @State private var sortOrder: [KeyPathComparator<IndexedExperience>] = []
    @State private var cachedRows: [IndexedExperience] = []
    @State private var displayedCount = pageSize
    @State private var isSorting = false

    private var hasOlder: Bool { displayedCount < store.steps.count }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Q-Learning Report").font(.title2).bold()
                Spacer()
                if isSorting { ProgressView().scaleEffect(0.7) }
                Text("Showing \(cachedRows.count) of \(store.steps.count)")
                    .font(.caption).foregroundStyle(.secondary)
                if hasOlder {
                    Button("↓ Load \(pageSize) older") {
                        displayedCount = min(displayedCount + pageSize, store.steps.count)
                    }
                    .font(.caption)
                }
                Button("Copy") { copyToClipboard() }
                Button("Clear") { store.clear() }
            }
            .padding(.bottom, 8)

            Table(cachedRows, sortOrder: $sortOrder) {
                TableColumn("#", value: \.index) { item in
                    Text(String(item.index))
                }.width(ideal: 55)
                TableColumn("Brain", value: \.brainPrefix) { item in
                    Text(item.brainPrefix)
                        .foregroundStyle(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }.width(ideal: 70)
                TableColumn("Energy", value: \.energy) { item in
                    let s = item.experience.state
                    Text(String(format: "%.2f, %.2f, %.2f, %.2f", s.energy, Double(s.lightLevel), Double(s.depth), Double(s.dayProgress)))
                }
                TableColumn("Action", value: \.actionIndex) { item in
                    Text(String(item.actionIndex))
                }.width(ideal: 60)
                TableColumn("Reward", value: \.reward) { item in
                    Text(String(format: "%.2f", item.reward))
                }.width(ideal: 80)
                TableColumn("Next E", value: \.nextEnergy) { item in
                    Text(item.experience.nextState.map { String(format: "%.2f", $0.energy) } ?? "—")
                }.width(ideal: 80)
            }
            .frame(minHeight: 300)
        }
        .padding(12)
        .task(id: store.steps.count) { await rebuildRows() }
        .task(id: displayedCount) { await rebuildRows() }
        .onChange(of: sortOrder) { _, _ in Task { await rebuildRows() } }
    }

    @MainActor
    private func rebuildRows() async {
        isSorting = true
        let steps = store.steps
        let count = displayedCount
        let order = sortOrder
        let rows = await Task.detached(priority: .userInitiated) {
            // Take the last `count` entries, reverse so newest is first
            let slice = steps.suffix(count)
            let offset = steps.count - slice.count
            var built = slice.enumerated().map { i, exp in
                IndexedExperience(index: offset + i, experience: exp)
            }.reversed() as [IndexedExperience]
            if !order.isEmpty { built.sort(using: order) }
            return built
        }.value
        cachedRows = rows
        isSorting = false
    }

    private func copyToClipboard() {
        let header = "#\tBrain\tState (E,L,D,P)\tAction\tReward\tNext Energy"
        let lines = store.steps.enumerated().map { i, exp -> String in
            let s = exp.state
            let brain = exp.brainId.uuidString.prefix(8).lowercased()
            let state = String(format: "%.2f, %.2f, %.2f, %.2f", s.energy, Double(s.lightLevel), Double(s.depth), Double(s.dayProgress))
            let nextEnergy = exp.nextState.map { String(format: "%.2f", $0.energy) } ?? "—"
            return "\(i)\t\(brain)\t\(state)\t\(exp.actionIndex)\t\(String(format: "%.2f", exp.reward))\t\(nextEnergy)"
        }
        let text = ([header] + lines).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    QLearningReportView()
}
