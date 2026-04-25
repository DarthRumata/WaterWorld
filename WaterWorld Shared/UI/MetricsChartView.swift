//
//  MetricsChartView.swift
//  WaterWorld Shared
//

import SwiftUI
import Charts

enum MetricTab: String, CaseIterable {
    case loss = "Loss"
    case reward = "Avg Reward"
    case maxQ = "Avg Max Q"
    case mortality = "Mortality"
    case nightEnergy = "Night Energy"
    case targetDrift = "Target Drift"
    case trainDuration = "Train ms"
    case qLandscape = "Q-Landscape"
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
            MortalityChart(
                hunger: store.dailyHungerDeaths,
                predation: store.dailyPredatorDeaths,
                lifespan: store.dailyMedianLifespans,
                episodeBoundaries: store.episodeBoundaries
            )
        case .nightEnergy:
            MetricLineChart(
                data: store.dailyNightEntryEnergy,
                label: "Avg Energy",
                color: .orange,
                xLabel: "Night",
                yFormat: "%.1f"
            )
        case .targetDrift:
            MetricLineChart(
                data: store.batchTargetDivergences,
                label: "Target Drift %",
                color: .indigo,
                xLabel: "Training step",
                yFormat: "%.2f"
            )
        case .trainDuration:
            MetricLineChart(
                data: store.batchTrainDurations,
                label: "Train ms",
                color: .cyan,
                xLabel: "Training step",
                yFormat: "%.1f"
            )
        case .qLandscape:
            QHeatmapView()
        }
    }
}

private struct MortalityChart: View {
    let hunger: [Int]
    let predation: [Int]
    let lifespan: [Double]
    let episodeBoundaries: [Int: Int]

    private struct Bar: Identifiable {
        let id: String
        let day: Int
        let count: Int
        let cause: String
    }

    private struct LifespanPoint: Identifiable {
        let id: Int
        let value: Double // scaled to deaths domain
    }

    private var bars: [Bar] {
        zip(hunger, predation).enumerated().flatMap { i, pair in [
            Bar(id: "h\(i)", day: i, count: pair.0, cause: "Hunger"),
            Bar(id: "p\(i)", day: i, count: pair.1, cause: "Predation")
        ]}
    }

    private var lifespanPoints: [LifespanPoint] {
        lifespan.enumerated().map { LifespanPoint(id: $0.offset, value: $0.element) }
    }

    private var xDomain: ClosedRange<Int> {
        0...(max(bars.map(\.day).max() ?? 0, lifespanPoints.map(\.id).max() ?? 0))
    }

    var body: some View {
        if hunger.isEmpty {
            VStack { Spacer(); ContentUnavailableView("No data yet", systemImage: "chart.bar.fill"); Spacer() }
        } else {
            VStack(spacing: 0) {
                // Deaths bars
                Chart {
                    ForEach(bars) { bar in
                        BarMark(
                            x: .value("Day", bar.day),
                            y: .value("Deaths", bar.count)
                        )
                        .foregroundStyle(by: .value("Cause", bar.cause))
                    }
                    ForEach(episodeBoundaries.sorted(by: { $0.key < $1.key }), id: \.key) { episode, day in
                        RuleMark(x: .value("Day", day))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Ep \(episode)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXScale(domain: xDomain)
                .chartXAxis(.hidden)
                .chartYAxisLabel("Deaths")
                .chartForegroundStyleScale(["Hunger": Color.orange, "Predation": Color.red])
                .frame(maxWidth: .infinity)

                // Median lifespan bars — shared X axis
                Chart {
                    ForEach(lifespanPoints) { point in
                        BarMark(
                            x: .value("Day", point.id),
                            y: .value("Lifespan (days)", point.value)
                        )
                        .foregroundStyle(Color.teal)
                    }
                }
                .chartXScale(domain: xDomain)
                .chartXAxisLabel("Day")
                .chartYAxisLabel("Lifespan (d)")
                .frame(maxWidth: .infinity, maxHeight: 120)
            }
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
