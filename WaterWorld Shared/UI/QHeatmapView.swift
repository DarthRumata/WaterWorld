import SwiftUI
import Charts

// MARK: - Model

private struct HeatmapCell: Identifiable {
    let id: Int
    let dayProgress: Double    // 0…1
    let invertedDepth: Double  // maxDepth - depth, so surface(0) plots at top
    let maxQ: Double
    let bestActionIndex: Int   // 0=moveUp, 1=moveDown, 2=wait
}

// MARK: - View

struct QHeatmapView: View {
    private enum DisplayMode: String, CaseIterable {
        case maxQ = "Max Q"
        case bestAction = "Best Action"
    }

    private enum EnergyLevel: String, CaseIterable {
        case low    = "25%"
        case medium = "50%"
        case high   = "75%"

        var value: Double {
            switch self {
            case .low:    return GlobalConstants.maxEnergy * 0.25
            case .medium: return GlobalConstants.maxEnergy * 0.50
            case .high:   return GlobalConstants.maxEnergy * 0.75
            }
        }
    }

    @State private var cells: [HeatmapCell] = []
    @State private var displayMode: DisplayMode = .maxQ
    @State private var energyLevel: EnergyLevel = .medium
    @State private var qMin: Double = 0
    @State private var qMax: Double = 1

    private let store = QLearningStore.shared
    private let environment = EnvironmentService()

    // Grid resolution
    private let stepsX = 50  // dayProgress
    private let stepsY = 50  // depth

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Picker("Mode", selection: $displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Picker("Energy", selection: $energyLevel) {
                    ForEach(EnergyLevel.allCases, id: \.self) {
                        Text($0.rawValue).lineLimit(1).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize(horizontal: true, vertical: false)
            }

            if cells.isEmpty {
                Spacer()
                if store.currentNetwork == nil {
                    ContentUnavailableView("Нет данных", systemImage: "network",
                        description: Text("Дождитесь первого шага обучения"))
                } else {
                    ProgressView("Генерация карты…")
                }
                Spacer()
            } else {
                chart
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding([.horizontal, .bottom])

                legend
                    .padding(.bottom, 8)
            }
        }
        // task(id:) cancels and restarts on network update or energy level change.
        .task(id: store.networkUpdateCount) { await regenerate() }
        .task(id: energyLevel) { await regenerate() }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        let dx = 1.0 / Double(stepsX)
        let dy = GlobalConstants.maxDepth / Double(stepsY)

        Chart(cells) { cell in
            RectangleMark(
                xStart: .value("t", cell.dayProgress),
                xEnd:   .value("t", cell.dayProgress + dx),
                yStart: .value("d", cell.invertedDepth - dy),
                yEnd:   .value("d", cell.invertedDepth)
            )
            .foregroundStyle(color(for: cell))
        }
        // invertedDepth = maxDepth - depth, so high values = surface (top of chart)
        .chartYScale(domain: 0...GlobalConstants.maxDepth)
        .chartXAxis {
            AxisMarks(values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let t = value.as(Double.self) {
                        Text(timeLabel(for: t))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            // Values are invertedDepth — labels show actual depth (maxDepth - invertedDepth)
            AxisMarks(values: stride(from: 0.0, through: GlobalConstants.maxDepth, by: GlobalConstants.maxDepth / 4).map { $0 }) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(GlobalConstants.maxDepth - v))")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxisLabel("Время суток")
        .chartYAxisLabel("Глубина")
    }

    // MARK: - Legend

    @ViewBuilder
    private var legend: some View {
        switch displayMode {
        case .maxQ:
            HStack(spacing: 4) {
                Text(String(format: "%.2f", qMin)).font(.caption2)
                LinearGradient(
                    colors: [.blue, .cyan, .green, .yellow, .red],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 120, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(String(format: "%.2f", qMax)).font(.caption2)
            }
        case .bestAction:
            HStack(spacing: 12) {
                legendItem(color: .green, label: "Вверх")
                legendItem(color: .gray, label: "Ждать")
                legendItem(color: .blue, label: "Вниз")
            }
            .font(.caption2)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label)
        }
    }

    // MARK: - Color mapping

    private func color(for cell: HeatmapCell) -> Color {
        switch displayMode {
        case .maxQ:
            let t = qMax > qMin ? (cell.maxQ - qMin) / (qMax - qMin) : 0.5
            return heatColor(t: t)
        case .bestAction:
            switch cell.bestActionIndex {
            case 0: return .green   // moveUp
            case 1: return .blue    // moveDown
            default: return .gray   // wait
            }
        }
    }

    /// Blue → Cyan → Green → Yellow → Red
    private func heatColor(t: Double) -> Color {
        let t = max(0, min(1, t))
        switch t {
        case 0.0..<0.25: return Color(hue: 0.67, saturation: 1, brightness: 0.5 + t * 2)
        case 0.25..<0.5: return Color(hue: 0.67 - (t - 0.25) * 1.6, saturation: 1, brightness: 1)
        case 0.5..<0.75: return Color(hue: 0.33 - (t - 0.5) * 1.32, saturation: 1, brightness: 1)
        default:          return Color(hue: max(0, 0.0 - (t - 0.75) * 0.4), saturation: 1, brightness: 1)
        }
    }

    // MARK: - Generation

    private func regenerate() async {
        guard let network = store.currentNetwork else {
            cells = []
            qMin = 0
            qMax = 1
            return
        }
        // nonisolated static func runs on the cooperative thread pool without Task.detached.
        let generated = await Self.generate(
            network: network, environment: environment,
            stepsX: stepsX, stepsY: stepsY, fixedEnergy: energyLevel.value
        )
        // Discard results if this task was cancelled while generate() was running.
        guard !Task.isCancelled else { return }
        cells = generated.cells
        qMin = generated.qMin
        qMax = generated.qMax
    }

    private nonisolated static func generate(
        network: NeuralNetwork,
        environment: EnvironmentService,
        stepsX: Int, stepsY: Int,
        fixedEnergy: Double
    ) -> (cells: [HeatmapCell], qMin: Double, qMax: Double) {
        let dx = 1.0 / Double(stepsX)
        let dy = GlobalConstants.maxDepth / Double(stepsY)
        var cells: [HeatmapCell] = []
        cells.reserveCapacity(stepsX * stepsY)
        var qMin = Double.infinity
        var qMax = -Double.infinity

        // Precompute per-row constants (depth-dependent, dayProgress-independent):
        // attenuation factor — 50 exp() calls instead of 2500.
        let rowData: [(attenuationFactor: Double, depth: Double, invertedDepth: Double)] =
            (0..<stepsY).map { yi in
                let depth = Double(yi) * dy
                let factor = Double(environment.attenuatedLight(surfaceLight: 1.0, depth: CGFloat(depth)))
                return (factor, depth, GlobalConstants.maxDepth - depth)
            }

        for xi in 0..<stepsX {
            let dayProgress = Double(xi) * dx
            let surfaceLight = environment.baseLightLevel(
                maxLight: GlobalConstants.maxLightLevel,
                dayProgress: dayProgress
            )

            for yi in 0..<stepsY {
                let row = rowData[yi]
                let lightLevel = surfaceLight * row.attenuationFactor
                let state = OrganismState(
                    lightLevel: lightLevel,
                    depth: row.depth,
                    dayProgress: dayProgress,
                    energy: fixedEnergy,
                    wasAttacked: false
                )
                let qValues = network.predict(inputs: state.normalized)
                let maxQ = qValues.max() ?? 0
                let bestAction = qValues.indices.max(by: { qValues[$0] < qValues[$1] }) ?? 0
                qMin = min(qMin, maxQ)
                qMax = max(qMax, maxQ)
                cells.append(HeatmapCell(
                    id: xi * stepsY + yi,
                    dayProgress: dayProgress,
                    invertedDepth: row.invertedDepth,
                    maxQ: maxQ,
                    bestActionIndex: bestAction
                ))
            }
        }
        return (cells, qMin, qMax)
    }

    // MARK: - Helpers

    /// dayProgress 0 = 07:00 (sunrise), 0.5 = 19:00 (sunset)
    private func timeLabel(for dayProgress: Double) -> String {
        let hours = Int((dayProgress * 24 + 7).truncatingRemainder(dividingBy: 24))
        return String(format: "%02d:00", hours)
    }
}
