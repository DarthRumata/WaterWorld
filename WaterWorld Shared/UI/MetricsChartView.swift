//
//  MetricsChartView.swift
//  WaterWorld Shared
//

import SwiftUI
import Charts

private extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

enum MetricTab: String, CaseIterable {
    case relativeLoss = "Loss %"
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
        case .relativeLoss:
            MetricLineChart(
                data: store.batchRelativeLosses,
                label: "Loss %",
                color: .orange,
                xLabel: "Training step",
                yFormat: "%.1f%%"
            )
        case .reward:
            MetricLineChart(
                data: store.batchRewards, label: "Avg Reward", color: .blue,
                xLabel: "Training step",
                companion: (store.batchMaxQs, "Avg Max Q", .green),
                companionAsLine: true,
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
                    let sortedBoundaries = episodeBoundaries.sorted(by: { $0.key < $1.key })
                    let labelStride = max(1, sortedBoundaries.count / 10)
                    ForEach(sortedBoundaries, id: \.key) { episode, day in
                        RuleMark(x: .value("Day", day))
                            .foregroundStyle(.gray.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                if episode % labelStride == 0 || episode == sortedBoundaries.last?.key {
                                    Text("Ep \(episode)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
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
    @State private var forceGlobalScale = false

    private static let maxRenderPoints = 1000

    private struct Point: Identifiable {
        let id: Int      // downsampled index
        let step: Int    // original training step number
        let value: Double
    }

    private func downsampleCore(_ source: [Double]) -> [(step: Int, value: Double)] {
        if source.count <= Self.maxRenderPoints {
            return source.enumerated().map { (step: $0.offset, value: $0.element) }
        }
        let factor = (source.count + Self.maxRenderPoints - 1) / Self.maxRenderPoints
        return stride(from: 0, to: source.count, by: factor).map { start in
            let end = min(start + factor, source.count)
            return (step: start + (end - start) / 2,
                    value: source[start..<end].reduce(0, +) / Double(end - start))
        }
    }

    private func downsamplePoints(_ source: [Double]) -> [Point] {
        downsampleCore(source).enumerated().map { Point(id: $0.offset, step: $0.element.step, value: $0.element.value) }
    }

    private func downsampleValues(_ source: [Double]) -> [(step: Int, value: Double)] {
        downsampleCore(source)
    }

    // Computed once per body evaluation via computeSlice().
    private func computeSlice() -> (data: [Double], domain: ClosedRange<Double>?) {
        guard !forceGlobalScale, data.count > 50 else { return (data, nil) }
        let recentCount = max(50, data.count / 5)
        let recent = data.suffix(recentCount)
        guard let recentMin = recent.min(), let recentMax = recent.max(),
              let globalMax = data.max(), let globalMin = data.min() else { return (data, nil) }
        let recentRange = recentMax - recentMin
        let globalRange = globalMax - globalMin
        guard globalRange > 0, recentRange / globalRange < 0.15 else { return (data, nil) }
        let pad = max(recentRange * 0.15, globalRange * 0.005)
        return (Array(recent), (recentMin - pad)...(recentMax + pad))
    }

    @ViewBuilder
    private func lineChart(points: [Point], companionData: ([(step: Int, value: Double)], String, Color)?) -> some View {
        let base = Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value(xLabel, point.step),
                    y: .value("Value", point.value),
                    series: .value("Series", label)
                )
                .foregroundStyle(by: .value("Series", label))
                .interpolationMethod(.catmullRom)
            }
            if companionAsLine, let (cData, cLabel, _) = companionData {
                ForEach(Array(cData.enumerated()), id: \.offset) { i, sv in
                    LineMark(
                        x: .value(xLabel, sv.step),
                        y: .value("Value", sv.value),
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
        if companionAsLine, let (_, cLabel, cColor) = companionData {
            base.chartForegroundStyleScale(domain: [label, cLabel], range: [color, cColor])
        } else {
            base.chartForegroundStyleScale(domain: [label], range: [color])
        }
    }

    var body: some View {
        if data.isEmpty {
            VStack {
                Spacer()
                ContentUnavailableView("No data yet", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
            }
        } else {
            let slice = computeSlice()
            let pts = downsamplePoints(slice.data)
            let compData: ([(step: Int, value: Double)], String, Color)? = companion.map { (cData, cLabel, cColor) in
                let cSlice = slice.domain != nil ? Array(cData.suffix(max(50, cData.count / 5))) : cData
                return (downsampleValues(cSlice), cLabel, cColor)
            }
            VStack(spacing: 4) {
                lineChart(points: pts, companionData: compData)
                    .chartXAxisLabel(xLabel)
                    .chartYAxisLabel(label)
                    .chartXSelection(value: $selectedStep)
                    .if(slice.domain != nil) { $0.chartYScale(domain: slice.domain!) }
                    .overlay(alignment: Alignment.topLeading) {
                        if slice.domain != nil {
                            Button(forceGlobalScale ? "Auto" : "Global") {
                                forceGlobalScale.toggle()
                            }
                            .font(.system(size: 10))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(4)
                        }
                    }

                // Fixed-height tooltip zone — no layout shift
                HStack(spacing: 16) {
                    if let step = selectedStep,
                       let nearest = pts.min(by: { abs($0.step - step) < abs($1.step - step) }) {
                        let store = QLearningStore.shared
                        if nearest.step < store.batchDays.count {
                            Text("Day \(store.batchDays[nearest.step])").foregroundStyle(.secondary)
                        }
                        Text("Step \(nearest.step)").foregroundStyle(.secondary)
                        Text("\(label): \(String(format: yFormat, nearest.value))").foregroundStyle(color)
                        if let (cData, cLabel, cColor) = companion, nearest.step < cData.count {
                            Text("\(cLabel): \(String(format: "%.3f", cData[nearest.step]))").foregroundStyle(cColor)
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
