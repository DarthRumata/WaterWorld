//
//  MetricsChartView.swift
//  WaterWorld Shared
//

import SwiftUI
import Charts

enum MetricTab: String, CaseIterable {
    case loss = "Loss"
    case reward = "Reward / Q"
    case mortality = "Mortality"
    case nightEnergy = "Night Energy"
    case targetDrift = "Target Drift"
    case trainDuration = "Train ms"
    case adamLR = "Step Size"
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
                xLabel: "Training step",
                companion: (store.batchMaxQs, "Avg Max Q", .green),
                companionAsLine: true,
                references: [
                    (value: store.rewardRefMax, label: "R_max", color: .blue),
                    (value: store.rewardRefMin, label: "R_min", color: .blue)
                ],
                textReferences: [
                    (label: "Q_max", value: store.qRefMax, color: .green),
                    (label: "Q_min", value: store.qRefMin, color: .green)
                ]
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
        case .adamLR:
            MetricLineChart(
                data: store.batchAdamLRs,
                label: "Step Size",
                color: .mint,
                xLabel: "Training step",
                yFormat: "%.2e"
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
    var companionAsLine: Bool = false
    var references: [(value: Double, label: String, color: Color)] = []
    var textReferences: [(label: String, value: Double, color: Color)] = []

    @State private var selectedStep: Int?

    private static let maxRenderPoints = 1000

    private struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    private func downsample(_ source: [Double]) -> [Double] {
        guard source.count > Self.maxRenderPoints else { return source }
        let factor = (source.count + Self.maxRenderPoints - 1) / Self.maxRenderPoints
        return stride(from: 0, to: source.count, by: factor).map { start in
            let end = min(start + factor, source.count)
            return source[start..<end].reduce(0, +) / Double(end - start)
        }
    }

    private var points: [Point] {
        downsample(data).enumerated().map { Point(id: $0.offset, value: $0.element) }
    }

    private var downsampledCompanion: ([Double], String, Color)? {
        guard let (cData, cLabel, cColor) = companion else { return nil }
        return (downsample(cData), cLabel, cColor)
    }

    @ViewBuilder
    private var lineChart: some View {
        let base = Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value(xLabel, point.id),
                    y: .value("Value", point.value),
                    series: .value("Series", label)
                )
                .foregroundStyle(by: .value("Series", label))
                .interpolationMethod(.catmullRom)
            }
            if companionAsLine, let (cData, cLabel, _) = downsampledCompanion {
                ForEach(Array(cData.enumerated()), id: \.offset) { i, val in
                    LineMark(
                        x: .value(xLabel, i),
                        y: .value("Value", val),
                        series: .value("Series", cLabel)
                    )
                    .foregroundStyle(by: .value("Series", cLabel))
                    .interpolationMethod(.catmullRom)
                }
            }
            if let step = selectedStep, step < points.count {
                RuleMark(x: .value(xLabel, step))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            ForEach(references, id: \.label) { ref in
                RuleMark(y: .value(ref.label, ref.value))
                    .foregroundStyle(ref.color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(String(format: "\(ref.label) %.1f", ref.value))
                            .font(.system(size: 9))
                            .foregroundStyle(ref.color)
                    }
            }
        }
        if companionAsLine, let (_, cLabel, cColor) = downsampledCompanion {
            base.chartForegroundStyleScale(domain: [label, cLabel], range: [color, cColor])
        } else {
            base.chartForegroundStyleScale(domain: [label], range: [color])
        }
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
                lineChart
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

                if !textReferences.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(textReferences, id: \.label) { ref in
                            Text("\(ref.label): \(String(format: "%.1f", ref.value))")
                                .foregroundStyle(ref.color)
                        }
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}
