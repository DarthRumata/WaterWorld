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
    case mortality = "Mortality"
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
        case .mortality:
            MortalityChart(hunger: store.dailyHungerDeaths, predation: store.dailyPredatorDeaths)
        }
    }
}

private struct MortalityChart: View {
    let hunger: [Int]
    let predation: [Int]

    private struct Bar: Identifiable {
        let id: String
        let day: Int
        let count: Int
        let cause: String
    }

    private var bars: [Bar] {
        zip(hunger, predation).enumerated().flatMap { i, pair in [
            Bar(id: "h\(i)", day: i, count: pair.0, cause: "Hunger"),
            Bar(id: "p\(i)", day: i, count: pair.1, cause: "Predation")
        ]}
    }

    var body: some View {
        if hunger.isEmpty {
            VStack { Spacer(); ContentUnavailableView("No data yet", systemImage: "chart.bar.fill"); Spacer() }
        } else {
            Chart(bars) { bar in
                BarMark(
                    x: .value("Day", bar.day),
                    y: .value("Deaths", bar.count)
                )
                .foregroundStyle(by: .value("Cause", bar.cause))
            }
            .chartXAxisLabel("Day")
            .chartYAxisLabel("Deaths")
            .chartForegroundStyleScale(["Hunger": Color.orange, "Predation": Color.red])
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
                        let store = QLearningStore.shared
                        if step < store.batchDays.count {
                            Text("Day \(store.batchDays[step])").foregroundStyle(.secondary)
                        }
                        Text("Step \(step)").foregroundStyle(.secondary)
                        Text("\(label): \(String(format: yFormat, points[step].value))").foregroundStyle(color)
                        if let (cData, cLabel, cColor) = companion, step < cData.count {
                            Text("\(cLabel): \(String(format: "%.3f", cData[step]))").foregroundStyle(cColor)
                        }
                    } else {
                        Text(" ")
                    }
                }
                .font(.caption)
                .frame(height: 16)
            }
        }
    }
}
