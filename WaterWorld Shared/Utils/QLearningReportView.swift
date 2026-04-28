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

struct QLearningReportView: View {
    private let store = QLearningStore.shared
    @State private var sortOrder: [KeyPathComparator<IndexedExperience>] = []

    private var rows: [IndexedExperience] {
        store.steps.enumerated().map { IndexedExperience(index: $0.offset, experience: $0.element) }
    }

    private var sortedRows: [IndexedExperience] {
        rows.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Q-Learning Report").font(.title2).bold()
                Spacer()
                Button("Copy") { copyToClipboard() }
                Button("Clear") { store.clear() }
            }
            .padding(.bottom, 8)

            Table(sortedRows, sortOrder: $sortOrder) {
                TableColumn("#", value: \.index) { item in
                    Text(String(item.index))
                }.width(ideal: 40)
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
