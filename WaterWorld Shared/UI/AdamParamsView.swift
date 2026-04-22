import SwiftUI

struct AdamParamsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Adam Optimizer")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { hud.isAdamEnabled },
                    set: { hud.onToggleAdam($0) }
                ))
                .labelsHidden()
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 10) {
                ParamRowView(
                    symbol: "β1",
                    value: hud.adamBeta1,
                    format: "%.3f",
                    step: 0.01,
                    minValue: 0.8,
                    labelWidth: 24,
                    onSet: hud.onSetAdamBeta1,
                    hint: "First moment decay (momentum). 0.9 = standard."
                )
                ParamRowView(
                    symbol: "β2",
                    value: hud.adamBeta2,
                    format: "%.4f",
                    step: 0.01,
                    minValue: 0.9,
                    labelWidth: 24,
                    onSet: hud.onSetAdamBeta2,
                    hint: "Second moment decay. 0.999 = stable, 0.99 = faster adaptation (better for RL)."
                )
                ParamRowView(
                    symbol: "ε",
                    value: hud.adamEps,
                    format: "%.2e",
                    step: 1e-8,
                    minValue: 1e-10,
                    labelWidth: 24,
                    onSet: hud.onSetAdamEps,
                    hint: "Numerical stability constant. Usually 1e-8."
                )
            }
            .opacity(hud.isAdamEnabled ? 1 : 0.35)
            .disabled(!hud.isAdamEnabled)
        }
        .padding()
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 300)
    }
}
