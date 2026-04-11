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
                data: store.batchLosses, label: "Loss", color: .red,
                xLabel: "Training step", companion: (store.batchEpsilons, "ε", .purple)
            )
        case .reward:
            MetricLineChart(
                data: store.batchRewards, label: "Avg Reward", color: .blue,
                xLabel: "Training step", companion: (store.batchEpsilons, "ε", .purple)
            )
        case .maxQ:
            MetricLineChart(
                data: store.batchMaxQs, label: "Avg Max Q", color: .green,
                xLabel: "Training step", companion: (store.batchEpsilons, "ε", .purple)
            )
        case .survival:
            MetricLineChart(
                data: store.episodeSurvivalRates.map { $0 * 100 },
                label: "Survival %", color: .orange, xLabel: "Episode", yFormat: "%.0f%%"
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
    var companion: ([Double], String, Color)? = nil

    @State private var selectedStep: Int?

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
            VStack(spacing: 4) {
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value(xLabel, point.id), y: .value(label, point.value))
                            .foregroundStyle(color)
                            .interpolationMethod(.catmullRom)
                    }
                    if let step = selectedStep, step < points.count {
                        RuleMark(x: .value(xLabel, step))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .chartXAxisLabel(xLabel)
                .chartYAxisLabel(label)
                .chartXSelection(value: $selectedStep)

                // Fixed-height tooltip zone — no layout shift
                HStack(spacing: 16) {
                    if let step = selectedStep, step < points.count {
                        Text("Step \(step)")
                            .foregroundStyle(.secondary)
                        Text("\(label): \(String(format: yFormat, points[step].value))")
                            .foregroundStyle(color)
                        if let (cData, cLabel, cColor) = companion, step < cData.count {
                            Text("\(cLabel): \(String(format: "%.3f", cData[step]))")
                                .foregroundStyle(cColor)
                        }
                    } else {
                        Text(" ")  // keeps height stable
                    }
                }
                .font(.caption)
                .frame(height: 16)
            }
        }
    }
}
