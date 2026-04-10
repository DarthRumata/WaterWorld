//
//  MetricsOverlayView.swift
//  WaterWorld Shared
//

import SwiftUI

struct MetricsOverlayView: View {
    private let store = QLearningStore.shared

    var body: some View {
        HStack(spacing: 16) {
            MetricItem(label: "Surv", value: String(format: "%.0f%%", store.lastSurvivalRate * 100))
            MetricItem(label: "Rwd", value: String(format: "%.2f", store.lastAvgReward))
            MetricItem(label: "MaxQ", value: String(format: "%.2f", store.lastAvgMaxQ))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .padding(.bottom, 210)
    }
}

private struct MetricItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}
