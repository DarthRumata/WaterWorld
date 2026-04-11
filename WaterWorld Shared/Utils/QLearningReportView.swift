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
}

struct QLearningReportView: View {
    private let store = QLearningStore.shared

    private var rows: [IndexedExperience] {
        store.steps.enumerated().map { IndexedExperience(index: $0.offset, experience: $0.element) }
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

            Table(rows) {
                TableColumn("#") { item in
                    Text(String(item.index))
                }.width(ideal: 40)
                TableColumn("State (E,L,D,P)") { item in
                    let s = item.experience.state
                    Text(String(format: "%.2f, %.2f, %.2f, %.2f", s.energy, Double(s.lightLevel), Double(s.depth), Double(s.dayProgress)))
                }
                TableColumn("Action") { item in
                    Text(String(item.experience.actionIndex))
                }.width(ideal: 60)
                TableColumn("Reward") { item in
                    Text(String(format: "%.2f", item.experience.reward))
                }.width(ideal: 80)
                TableColumn("Next Energy") { item in
                    Text(item.experience.nextState.map { String(format: "%.2f", $0.energy) } ?? "—")
                        .foregroundColor(.primary)
                }.width(ideal: 100)
            }
            .frame(minHeight: 300)
        }
        .padding(12)
    }

    private func copyToClipboard() {
        let header = "#\tState (E,L,D,P)\tAction\tReward\tNext Energy"
        let lines = store.steps.enumerated().map { i, exp -> String in
            let s = exp.state
            let state = String(format: "%.2f, %.2f, %.2f, %.2f", s.energy, Double(s.lightLevel), Double(s.depth), Double(s.dayProgress))
            let nextEnergy = exp.nextState.map { String(format: "%.2f", $0.energy) } ?? "—"
            return "\(i)\t\(state)\t\(exp.actionIndex)\t\(String(format: "%.2f", exp.reward))\t\(nextEnergy)"
        }
        let text = ([header] + lines).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    QLearningReportView()
}
