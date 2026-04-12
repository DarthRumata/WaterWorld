import SwiftUI

struct LearningParamsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            paramRow(
                symbol: "γ", label: "Gamma",
                value: hud.gamma,
                format: "%.3f",
                step: 0.01,
                onDecrement: { hud.onSetGamma(hud.gamma - 0.01) },
                onIncrement: { hud.onSetGamma(hud.gamma + 0.01) }
            )
            paramRow(
                symbol: "τ", label: "Tau",
                value: hud.tau,
                format: "%.3f",
                step: 0.001,
                onDecrement: { hud.onSetTau(hud.tau - 0.001) },
                onIncrement: { hud.onSetTau(hud.tau + 0.001) }
            )
            paramRow(
                symbol: "Δw", label: "Delta",
                value: hud.deltaWeight,
                format: "%.2f",
                step: 0.05,
                onDecrement: { hud.onSetDeltaWeight(hud.deltaWeight - 0.05) },
                onIncrement: { hud.onSetDeltaWeight(hud.deltaWeight + 0.05) }
            )
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(white: 0.15))
    }

    private func paramRow(
        symbol: String,
        label: String,
        value: Double,
        format: String,
        step: Double,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
                .frame(width: 20, alignment: .leading)
                .foregroundStyle(Color(white: 0.4))
            Button("-", action: onDecrement).buttonStyle(HUDButtonStyle())
            Text(String(format: format, value))
                .frame(width: 40, alignment: .center)
            Button("+", action: onIncrement).buttonStyle(HUDButtonStyle())
        }
    }
}
