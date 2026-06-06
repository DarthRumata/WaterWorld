//
//  DiagnosticsView.swift
//  WaterWorld Shared
//

import SwiftUI
import Charts

private let diagDeathLimit = 10_000

struct DiagnosticsView: View {
    private let store = QLearningStore.shared
    @State private var deathExperiences: [QLearningExperience] = []
    @State private var predationDeaths: [QLearningExperience] = []
    @State private var starvationDeaths: [QLearningExperience] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Death Analysis").font(.title2).bold()

                rewardComponentsSection
                updateRatioSection
                causeSection
                energySection
                depthSection
                timeSection
            }
            .padding(20)
        }
        .frame(minWidth: 620, minHeight: 540)
        .task(id: store.steps.count) { await rebuildDeaths() }
    }

    private func rebuildDeaths() async {
        let steps = store.steps
        let threshold = GlobalConstants.rewardCriticalEnergyThreshold
        let deaths = await Task.detached(priority: .userInitiated) {
            Array(steps.suffix(diagDeathLimit).filter { $0.nextState == nil })
        }.value
        let predation = deaths.filter { $0.state.energy >= threshold }
        let starvation = deaths.filter { $0.state.energy < threshold }
        deathExperiences = deaths
        predationDeaths = predation
        starvationDeaths = starvation
    }

    // MARK: - Reward Components

    private var rewardComponentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reward components (avg per batch)")
                .font(.headline)
            Text("Tick = survival bonus (const). Delta = energy change reward. State = energy level reward.")
                .font(.caption).foregroundStyle(.secondary)

            if store.batchTickRewards.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 160)
            } else {
                Chart {
                    ForEach(Array(store.batchTickRewards.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("Step", i), y: .value("Reward", v),
                                 series: .value("S", "Tick"))
                        .foregroundStyle(by: .value("S", "Tick"))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(Array(store.batchDeltaRewards.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("Step", i), y: .value("Reward", v),
                                 series: .value("S", "Delta E"))
                        .foregroundStyle(by: .value("S", "Delta E"))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(Array(store.batchStateRewards.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("Step", i), y: .value("Reward", v),
                                 series: .value("S", "State E"))
                        .foregroundStyle(by: .value("S", "State E"))
                        .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartForegroundStyleScale(domain: ["Tick", "Delta E", "State E"],
                                           range: [Color.yellow, Color.blue, Color.orange])
                .chartXAxisLabel("Training step")
                .chartYAxisLabel("Avg component")
                .frame(height: 160)
            }
        }
    }

    // MARK: - Update/Weight ratio

    private var updateRatioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Update / Weight ratio  (mean|Δw| / mean|w|)")
                .font(.headline)
            HStack(spacing: 16) {
                Text("< 0.001").foregroundStyle(.green) + Text(" stable")
                Text("0.001–0.01").foregroundStyle(.yellow) + Text(" caution")
                Text("> 0.01").foregroundStyle(.red) + Text(" destructive")
            }
            .font(.caption)

            if store.batchUpdateRatios.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 160)
            } else {
                Chart {
                    ForEach(Array(store.batchUpdateRatios.enumerated()), id: \.offset) { i, val in
                        LineMark(x: .value("Step", i), y: .value("Ratio", val))
                            .foregroundStyle(ratioColor(val))
                            .interpolationMethod(.catmullRom)
                    }
                    RuleMark(y: .value("Caution", 0.001))
                        .foregroundStyle(.yellow.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    RuleMark(y: .value("Danger", 0.01))
                        .foregroundStyle(.red.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartYAxisLabel("Δw/w")
                .chartXAxisLabel("Training step")
                .frame(height: 160)
            }
        }
    }

    private func ratioColor(_ val: Double) -> Color {
        if val > 0.01 { return .red }
        if val > 0.001 { return .yellow }
        return .green
    }

    // MARK: - Cause

    private var causeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cause of death").font(.headline)
            let total = deathExperiences.count
            if total == 0 {
                Text("No death data yet").foregroundStyle(.secondary)
            } else {
                let predPct = Double(predationDeaths.count) / Double(total) * 100
                let starvPct = Double(starvationDeaths.count) / Double(total) * 100
                HStack(spacing: 24) {
                    statBox(label: "Predation", value: predPct, unit: "%", color: .red)
                    statBox(label: "Starvation", value: starvPct, unit: "%", color: .orange)
                    statBox(label: "Total deaths", value: Double(total), unit: "", color: .secondary)
                }
            }
        }
    }

    // MARK: - Energy at death

    private var energySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Energy at death").font(.headline)
            Text("Predation ≥ \(Int(GlobalConstants.rewardCriticalEnergyThreshold)) energy. Starvation < \(Int(GlobalConstants.rewardCriticalEnergyThreshold)).")
                .font(.caption).foregroundStyle(.secondary)

            if deathExperiences.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "chart.bar")
                    .frame(height: 140)
            } else {
                let buckets = energyBuckets()
                Chart(buckets, id: \.label) { b in
                    BarMark(x: .value("Energy", b.label), y: .value("Deaths", b.count), width: .ratio(0.8))
                        .foregroundStyle(b.isPredation ? Color.red : Color.orange)
                }
                .chartXAxisLabel("Energy range")
                .chartYAxisLabel("Deaths")
                .frame(height: 140)
            }
        }
    }

    // MARK: - Depth at death

    private var depthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Depth at death").font(.headline)
            Text("Predators reach top \(Int(GlobalConstants.predationDodgeMaxDepthFraction * 100))% (depth < \(String(format: "%.0f", GlobalConstants.predationDodgeMaxDepthFraction * 100))). Deaths in safe zone → starvation.")
                .font(.caption).foregroundStyle(.secondary)

            if deathExperiences.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "chart.bar")
                    .frame(height: 120)
            } else {
                let avgPred = predationDeaths.isEmpty ? 0.0 :
                    predationDeaths.map { Double($0.state.depth) }.reduce(0, +) / Double(predationDeaths.count)
                let avgStarv = starvationDeaths.isEmpty ? 0.0 :
                    starvationDeaths.map { Double($0.state.depth) }.reduce(0, +) / Double(starvationDeaths.count)
                HStack(spacing: 24) {
                    statBox(label: "Avg depth (predation)", value: avgPred, unit: "", color: .red)
                    statBox(label: "Avg depth (starvation)", value: avgStarv, unit: "", color: .orange)
                }
            }
        }
    }

    // MARK: - Time of death

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time of death (day progress)").font(.headline)
            Text("0 = dawn (7:00), 0.25 = midday (13:00), 0.5 = dusk (19:00), 0.75 = midnight (1:00). Peak deaths at 0.8–1.0 = late night → starvation.")
                .font(.caption).foregroundStyle(.secondary)

            if deathExperiences.isEmpty {
                ContentUnavailableView("No data yet", systemImage: "clock")
                    .frame(height: 120)
            } else {
                let buckets = timeBuckets()
                Chart(buckets, id: \.label) { b in
                    BarMark(x: .value("Time", b.label), y: .value("Deaths", b.count), width: .ratio(0.8))
                        .foregroundStyle(Color.indigo)
                }
                .chartXAxisLabel("Day progress")
                .chartYAxisLabel("Deaths")
                .frame(height: 120)
            }
        }
    }

    // MARK: - Helpers

    private func statBox(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%.1f%@", value, unit)).font(.title3.bold()).foregroundStyle(color)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private struct EnergyBucket { let label: String; let count: Int; let isPredation: Bool }
    private func energyBuckets() -> [EnergyBucket] {
        let ranges: [(String, ClosedRange<Double>, Bool)] = [
            ("0–50",   0...50,    false),
            ("50–100", 50...100,  false),
            ("100–150",100...150, true),
            ("150–200",150...200, true),
        ]
        return ranges.map { label, range, isPred in
            EnergyBucket(label: label,
                         count: deathExperiences.filter { range.contains($0.state.energy) }.count,
                         isPredation: isPred)
        }
    }

    private struct TimeBucket { let label: String; let count: Int }
    private func timeBuckets() -> [TimeBucket] {
        let labels = ["0–0.2","0.2–0.4","0.4–0.6","0.6–0.8","0.8–1.0"]
        let edges: [Double] = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
        return zip(labels, zip(edges, edges.dropFirst())).map { label, range in
            TimeBucket(label: label,
                       count: deathExperiences.filter {
                           Double($0.state.dayProgress) >= range.0 &&
                           Double($0.state.dayProgress) < range.1
                       }.count)
        }
    }
}
