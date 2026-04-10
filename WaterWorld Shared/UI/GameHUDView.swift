//
//  GameHUDView.swift
//  WaterWorld Shared
//

import SwiftUI

// MARK: - Constants

private enum HUD {
    static let height: CGFloat = 200
    static let primaryFont: CGFloat = 18
    static let secondaryFont: CGFloat = 14
    static let spacing: CGFloat = 6
    static let textColor = Color(white: 0.1)
    static let background = Color(white: 0.85)
    static let celestialSize: CGFloat = 16
    static let tickDuration: Double = 0.25
}

// MARK: - GameHUDView

struct GameHUDView: View {
    let hud: GameHUDModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftPanel
            Spacer()
            centerPanel
            Spacer()
            rightPanel
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: HUD.height)
        .foregroundStyle(HUD.textColor)
        .background(HUD.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Left

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: HUD.spacing) {
            hudText("Day: \(hud.dayCount)")
            hudText("Org: \(hud.organismsCount)")
            Spacer()
            let store = QLearningStore.shared
            metricText(String(format: "Surv: %.0f%%", store.lastSurvivalRate * 100), tab: .survival)
            metricText(String(format: "Rwd: %.2f", store.lastAvgReward), tab: .reward)
            metricText(String(format: "MaxQ: %.2f", store.lastAvgMaxQ), tab: .maxQ)
            metricText(String(format: "Loss: %.4f", store.lastLoss), tab: .loss)
        }
        .frame(width: 140, alignment: .leading)
    }

    // MARK: - Center

    private var centerPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                hudText(String(format: "Light: %.1f", hud.lightLevel))
                hudText(formattedTime)
            }
            DayNightTimelineView(dayProgress: hud.dayProgress)
                .frame(width: 360, height: 40)
                .animation(.linear(duration: HUD.tickDuration / hud.simulationSpeed), value: hud.dayProgress)
            Spacer()
        }
    }

    private var formattedTime: String {
        let hours = 24 * hud.dayProgress
        let correctedHours = Int((floor(hours) + 7).truncatingRemainder(dividingBy: 24))
        let minutes = Int((hours - floor(hours)) * 60)
        return String(format: "T: %02d:%02d", correctedHours, minutes)
    }

    // MARK: - Right

    private var rightPanel: some View {
        VStack(alignment: .trailing, spacing: HUD.spacing) {
            hudButton("Restart", action: hud.onRestart)
            pauseButton
            hudButton("Report", action: hud.onReport)
            SegmentedButtons(
                options: ["Normal", "Learning"],
                selectedIndex: hud.simulationMode == .normal ? 0 : 1,
                onSelect: { _ in hud.onToggleMode() }
            ).frame(width: 160)
            SegmentedButtons(
                options: ["Off", "Low", "Med", "High"],
                selectedIndex: PredatorsIntensity.allCases.firstIndex(of: hud.predatorsIntensity) ?? 0,
                onSelect: { hud.onSelectPredatorsIntensity(PredatorsIntensity.allCases[$0]) }
            ).frame(width: 200)
            HStack {
                hudButton("<=", action: hud.onDecreaseSpeed)
                hudText(String(format: "x%.1f", hud.simulationSpeed))
                hudButton("=>", action: hud.onIncreaseSpeed)
            }
        }
        .frame(width: 220, alignment: .trailing)
    }

    private var pauseButton: some View {
        let isTraining = hud.gameState == .training
        let isStopped = hud.gameState == .stopped
        let label = hud.gameState == .active ? "Pause" : "Resume"
        return hudButton(label, action: hud.onPause)
            .disabled(isTraining || isStopped)
            .opacity(isTraining ? 0.4 : 1.0)
    }

    // MARK: - Helpers

    private func hudText(_ text: String, secondary: Bool = false) -> some View {
        Text(text).font(.system(size: secondary ? HUD.secondaryFont : HUD.primaryFont))
    }

    private func metricText(_ text: String, tab: MetricTab) -> some View {
        Text(text)
            .font(.system(size: HUD.secondaryFont))
            .underline()
            .onTapGesture { hud.onTapMetric(tab) }
    }

    private func hudButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).fixedSize().buttonStyle(.plain)
    }
}

// MARK: - Segmented Buttons

private struct SegmentedButtons: View {
    let options: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    private let selectedBg = Color(white: 0.6)
    private let unselectedBg = Color.clear
    private let containerBg = Color(white: 0.78)
    private let borderColor = Color(white: 0.6)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i]) { onSelect(i) }
                    .buttonStyle(.plain)
                    .font(.system(size: HUD.secondaryFont))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(i == selectedIndex ? selectedBg : unselectedBg)
                    .foregroundStyle(HUD.textColor)
                if i < options.count - 1 {
                    Divider().frame(height: 20)
                }
            }
        }
        .background(containerBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
    }
}

// MARK: - Timeline

private struct DayNightTimelineView: View {
    let dayProgress: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let midY = geo.size.height / 2
            let sunX = (dayProgress / 0.5).clamped(to: 0...1) * w
            let moonX = ((dayProgress - 0.5) / 0.5).clamped(to: 0...1) * w

            ZStack(alignment: .leading) {
                Capsule()
                    .frame(height: 4)
                    .foregroundStyle(.secondary.opacity(0.6))
                celestialBody(color: .yellow, shadowColor: .yellow, shadowRadius: 6, x: sunX, y: midY)
                    .opacity(dayProgress <= 0.5 ? 1 : 0)
                celestialBody(color: .white, shadowColor: .gray, shadowRadius: 3, x: moonX, y: midY)
                    .opacity(dayProgress > 0.5 ? 1 : 0)
            }
        }
    }

    private func celestialBody(color: Color, shadowColor: Color, shadowRadius: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .frame(width: HUD.celestialSize, height: HUD.celestialSize)
            .foregroundStyle(color)
            .shadow(color: shadowColor, radius: shadowRadius)
            .position(x: x, y: y)
    }
}

// MARK: - Extensions

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
