//
//  MetricsChartView.swift
//  WaterWorld Shared
//

import SwiftUI
import Charts

enum MetricTab: String, CaseIterable {
    case loss = "Loss (MSE)"
    case reward = "Avg Reward"
    case maxQ = "Avg Max Q"
    case survival = "Survival Rate"
}

struct MetricsChartView: View {
    @State var selectedTab: MetricTab
    private let store = QLearningStore.shared

    var body: some View {
        VStack(spacing: 0) {
            Picker("Metric", selection: $selectedTab) {
                ForEach(MetricTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            chartView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    private var chartView: some View {
        switch selectedTab {
        case .loss:
            MetricLineChart(
                data: store.batchLosses,
                label: "Loss",
                color: .red,
                xLabel: "Training step"
            )
        case .reward:
            MetricLineChart(
                data: store.batchRewards,
                label: "Avg Reward",
                color: .blue,
                xLabel: "Training step"
            )
        case .maxQ:
            MetricLineChart(
                data: store.batchMaxQs,
                label: "Avg Max Q",
                color: .green,
                xLabel: "Training step"
            )
        case .survival:
            MetricLineChart(
                data: store.episodeSurvivalRates.map { $0 * 100 },
                label: "Survival %",
                color: .orange,
                xLabel: "Episode",
                yFormat: "%.0f%%"
            )
        }
    }
}

private struct MetricLineChart: View {
    let data: [Double]
    let label: String
    let color: Color
    let xLabel: String
    var yFormat: String = "%.2f"

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private var points: [Point] {
        data.enumerated().map { Point(id: $0.offset, value: $0.element) }
    }

    var body: some View {
        if points.isEmpty {
            VStack {
                Spacer()
                ContentUnavailableView("No data yet", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
            }
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value(xLabel, point.id),
                    y: .value(label, point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxisLabel(xLabel)
            .chartYAxisLabel(label)
        }
    }
}
