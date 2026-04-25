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
            HStack(spacing: 12) {
                hudText("Day: \(hud.dayCount)").fixedSize()
                if hud.simulationMode == .learning {
                    hudText("Ep: \(hud.episodeNumber)").fixedSize()
                    hudText("Ep.D: \(hud.episodeDayCount)").fixedSize()
                }
            }
            hudText("Org: \(hud.organismsCount)")
            Spacer()
            let store = QLearningStore.shared
            metricText("Deaths", tab: .mortality)
            metricText(String(format: "Rwd: %.2f", store.lastAvgReward), tab: .reward)
            metricText(String(format: "MaxQ: %.2f", store.lastAvgMaxQ), tab: .maxQ)
            metricText(String(format: "Loss: %.4f", store.lastLoss), tab: .loss)
        }
        .frame(width: 140, alignment: .leading)
    }

    // MARK: - Center

    private var centerPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 24) {
                    hudText(String(format: "Light: %.1f", hud.lightLevel)).monospacedDigit()
                    hudText(formattedTime).monospacedDigit()
                }
                DayNightTimelineView(dayProgress: hud.dayProgress)
                    .frame(width: 80, height: 80)
                    .animation(.linear(duration: HUD.tickDuration / hud.simulationSpeed), value: hud.dayProgress)
                SegmentedButtons(
                    options: ["Normal", "Learning"],
                    selectedIndex: hud.simulationMode == .normal ? 0 : 1,
                    onSelect: { _ in hud.onToggleMode() }
                ).frame(width: 160)
                if hud.simulationMode == .learning {
                    SegmentedButtons(
                        options: CostFunctionType.allCases.map(\.rawValue),
                        selectedIndex: CostFunctionType.allCases.firstIndex(of: hud.costFunctionType) ?? 0,
                        onSelect: { hud.onSelectCostFunction(CostFunctionType.allCases[$0]) }
                    ).frame(width: 160)
                }
            }

            if hud.simulationMode == .learning {
                LearningParamsView(hud: hud)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hud.simulationMode)
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
            HStack(spacing: 12) {
                hudButton("Restart", action: hud.onRestart)
                pauseButton
                hudButton("Report", action: hud.onReport)
            }
            Divider()
            HStack(spacing: 8) {
                hudButton("Save NN", action: hud.onSaveNetwork)
                hudButton("Load NN", action: hud.onLoadNetwork)
            }
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
        let isStopped = hud.gameState == .stopped
        let label = hud.gameState == .active ? "Pause" : "Resume"
        return hudButton(label, action: hud.onPause)
            .disabled(isStopped)
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
        Button(title, action: action).buttonStyle(HUDButtonStyle())
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

// MARK: - HUD Button Style

struct HUDButtonStyle: ButtonStyle {
    private let bg = Color(white: 0.78)
    private let borderColor = Color(white: 0.6)
    private let pressedBg = Color(white: 0.65)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: HUD.secondaryFont))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(configuration.isPressed ? pressedBg : bg)
            .foregroundStyle(HUD.textColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
    }
}

// MARK: - Timeline

private struct DayNightTimelineView: View {
    let dayProgress: Double

    private var angle: Double { 2 * .pi * dayProgress - .pi }
    private var isDay: Bool { dayProgress <= 0.5 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let size = min(w, h)
            let cx = w / 2
            let cy = h / 2
            let radius = size / 2 - HUD.celestialSize / 2
            let x = cx + radius * cos(angle)
            let y = cy + radius * sin(angle)

            ZStack {
                // Ring centered on body path
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.orange.opacity(0.5), .blue.opacity(0.2), .black.opacity(0.5), .blue.opacity(0.2), .orange.opacity(0.5)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        lineWidth: 3
                    )
                    .padding(HUD.celestialSize / 2)

                // Horizon line
                Path { path in
                    path.move(to: CGPoint(x: cx - radius, y: cy))
                    path.addLine(to: CGPoint(x: cx + radius, y: cy))
                }
                .stroke(Color(white: 0.3).opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Sun or moon
                Circle()
                    .frame(width: HUD.celestialSize, height: HUD.celestialSize)
                    .foregroundStyle(isDay ? Color.yellow : Color.white)
                    .shadow(color: isDay ? .yellow : .gray, radius: isDay ? 6 : 3)
                    .position(x: x, y: y)
            }
        }
    }
}

