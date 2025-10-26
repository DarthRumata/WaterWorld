//
//  QLearningReportView.swift
//  WaterWorld macOS
//
//  A simple macOS SpriteKit-free view to present QLearningStep data in a table.
//

import SwiftUI

struct QLearningReportView: View {
    @State private var steps: [QLearningStep] = []

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Q-Learning Report").font(.title2).bold()
                Spacer()
                Button("Clear") { QLearningStore.shared.clear(); reload() }
            }
            .padding(.bottom, 8)

            Table(steps) {
                TableColumn("#") { step in
                    Text(String(steps.firstIndex(where: { $0.id == step.id }) ?? 0))
                }.width(ideal: 40)
                TableColumn("State (E,L,D,P)") { step in
                    Text(String(format: "%.2f, %.2f, %.2f, %.2f", step.state.energy, Double(step.state.lightLevel), Double(step.state.depth), Double(step.state.dayProgress)))
                }
                TableColumn("Action") { step in
                    Text(String(step.actionIndex))
                }.width(ideal: 60)
                TableColumn("Reward") { step in
                    Text(String(format: "%.2f", step.reward))
                }.width(ideal: 80)
                TableColumn("Next Energy") { step in
                    Text(step.nextState.map { String(format: "%.2f", $0.energy) } ?? "—")
                        .foregroundColor(.primary)
                }.width(ideal: 100)
            }
            .frame(minHeight: 300)
        }
        .padding(12)
        .onAppear { reload() }
    }

    private func reload() {
        steps = QLearningStore.shared.steps
    }
}

#Preview {
    QLearningReportView()
}
